# EV Battery Thermal Management (BTMS) Optimizer

> Models a real EV battery pack under a real fast-charging event to find how close today's charging aggressiveness sits to a passive-cooling thermal safety limit and how much that answer depends on unverified assumptions.

![Peak temperature vs charge-rate scale factor](models/fig_charge_rate_sweep.png)

---

## Overview

- **Problem:** Battery thermal safety limits are governed by *peak* temperature during a charging event, not average or steady-state temperature — a distinction that steady-state thermal models miss entirely. Public EV specs don't tell you how close a real charge curve runs to that limit.
- **Approach:** Built a validated lumped-thermal-capacitance Simscape model of a Tesla Model 3 pack (topology and resistance sourced from a published teardown), drove it with a digitized real 250kW V3 Supercharger curve, and swept charge-rate aggressiveness and key physical assumptions to locate the safety margin and quantify its uncertainty.
- **Result:** Baseline peak temperature of 42.10°C, with the safety threshold (45°C) crossed at just 1.08× today's real charge curve — a thin margin. Sensitivity testing found the specific-heat assumption (unsourced in public data) moves this result by ~13°C, more than double the swing from a 20% resistance error.

---

## Tools & Environment

| Tool | Version | Purpose |
|---|---|---|
| MATLAB | R2023b or later (requires local function support in scripts, R2016b+) | Charge-profile construction, heat-generation calculation, sweep/sensitivity automation |
| Simulink | Bundled with MATLAB | Model execution environment |
| Simscape (Foundation Library Thermal) | Bundled with Simulink | Lumped thermal-mass network: Thermal Mass, Convective Heat Transfer, thermal sources/reference |

No external Python bridge was used in the final pipeline — this project runs end-to-end in native MATLAB/Simscape.

---

## System Architecture

The model is a single-node lumped thermal-capacitance network. Heat generation is computed *outside* Simscape (in MATLAB, from real charge-power data) and injected as a time-varying source; Simscape handles only the thermal dynamics — mass, storage, and convective loss to ambient.

```
[Real Tesla V3 charge curve P(t)]
              │
              ▼  (MATLAB: I = P/V,  Q_gen = I²·R_pack)
      [Heat profile q(t)]
              │
              ▼  (From Workspace block)
      [Simscape: Thermal Mass]  ──▶  [Convective Heat Transfer]  ──▶  [Ambient Temp Source]
              │
              ▼  (To Workspace)
      [T_pack(t) — logged pack temperature]
```

Heat generation is deliberately modeled as ohmic loss ($\dot Q = I^2 R$), not a flat charging-efficiency factor — this preserves the physically correct *quadratic* relationship between charge current and heat, which matters specifically because the project's core question is about peak-power risk.

---

## Methodology

1. **Modeling assumptions**
   - Passive air convection only (UA = 600 W/K), reflecting that fast-charging occurs while the vehicle is parked — forced convection cannot be assumed.
   - Fixed nominal pack voltage (350 V), rather than modeling voltage rise with SOC.
   - Charge-rate aggressiveness represented as a uniform scale factor on the real power curve (0.5×–2.0×), not a re-derived charge-controller curve.
   - Pack specific heat tested at two literature-bounded values (320 and 1000 J/kg·K) rather than a single unsourced number, since no authoritative figure exists publicly for this pack.

2. **Validation**
   - Zero heat input → pack temperature held flat at ambient (25°C) for the full run, confirming no spurious heat leak in the thermal network wiring.
   - Constant 1000 W step input → simulated steady-state temperature and time constant matched hand-calculated values ($\Delta T = Q/UA$, $\tau = C/UA$).
   - Peak heat generation from the real charge curve cross-checked by hand ($I^2R$) before trusting the simulated baseline result.
   - A Kelvin/Celsius unit bug (initially producing a nonsensical 315°C result) was caught specifically because a hand-calculated plausible range (~20–45°C) didn't match — direct evidence the validation process works, not just the final numbers.

3. **Test scenarios**
   - Baseline: real, unscaled Tesla V3 charge curve.
   - Charge-rate sweep: 0.5× to 2.0× the real curve, in 0.1 increments, to locate the safety-limit crossing point.
   - Resistance sensitivity: R_pack ±20%, to bound the impact of pack-to-pack manufacturing variation.
   - Specific-heat sensitivity: both literature-plausible c_p values, to quantify the model's largest known uncertainty.

---

## Results

**Key plot:** peak pack temperature vs. charge-rate scale factor (above) — rises smoothly and monotonically, crossing the 45°C safety line at ≈1.08×.

**Quantified comparison:**

| Test | Range tested | Peak temperature result |
|---|---|---|
| Baseline (real curve) | 1.0× | 42.10°C |
| Charge-rate sweep | 0.5×–2.0× | 29.28°C – 92.98°C |
| Resistance sensitivity | ±20% | 38.71°C – 45.52°C |
| Specific-heat sensitivity | 320 vs 1000 J/kg·K | 42.10°C – 55.00°C |

**Honest limitations:**
- No liquid-cooling loop was modeled — a parked-charging scenario doesn't support the forced-airflow assumption a coolant-flow-rate optimization would need, so this was scoped out deliberately rather than forced to fit.
- Specific heat is the single largest source of uncertainty in the model (a 13°C swing) and was never independently sourced for this specific pack.
- Charge-rate scaling is a uniform multiplier on the real curve, not a physically re-derived higher-power charge-controller profile.
- Fixed nominal voltage ignores real voltage rise with SOC, which would tighten the current (and therefore heat) calculation, particularly at low SOC.

---

## Repository Structure

```
├── btms_full_pipeline.m       # Full pipeline: charge profile -> heat calc -> sweep -> sensitivity -> plots
├── battery_cooling.slx        # Simscape thermal model
├── fig_charge_rate_sweep.png  # Charge-rate vs peak-temperature trade-off plot
└── README.md
```

---

## How to Run

1. Open `battery_cooling.slx` and confirm the Thermal Mass block's value field is set to the workspace variable `C_pack` (required for the specific-heat sensitivity sweep in Section 6 of the script).
2. Open `btms_full_pipeline.m` in MATLAB with the model file on the path.
3. Run the script top to bottom. Section 3 reproduces the validated baseline (42.10°C) — confirm this before trusting later sections.
4. Sections 4–6 run the charge-rate sweep, resistance sensitivity, and specific-heat sensitivity in sequence, printing results and saving `fig_charge_rate_sweep.png`.

---

## What I'd Do With More Time

- Source or derive a properly justified pack specific-heat value (e.g., a rule-of-mixtures estimate from cell material + enclosure + coolant-plate mass fractions) to close the model's largest uncertainty.
- Model pack voltage as a function of SOC rather than a fixed nominal value.
- Replace the uniform charge-rate scaling with an actual charge-controller simulation (power↔SOC feedback), so "more aggressive charging" reflects a physically real curve rather than a scaled proxy.
- Extend the validated pipeline to a second vehicle (e.g., Tesla Model Y) to test how much the safety margin generalizes across different pack masses and capacities.
- Add a liquid-cooling variant as a comparison case, specifically for scenarios where forced circulation is a valid assumption (e.g., preconditioning while driving toward a charger).

---

## References

- Ricardo Engineering — teardown report on the 2018 Tesla Model 3 battery module, cell internal resistance and module topology.
- Public V3 Supercharger charging-curve test data (digitized power-vs-SOC breakpoints).
- Independent Tesla pack DC internal resistance measurement, used as a cross-validation check on the derived pack resistance.
- Manufacturer-published Tesla Model 3 specifications (pack capacity, nominal voltage).
