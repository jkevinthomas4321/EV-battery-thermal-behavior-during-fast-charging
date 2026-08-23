%% 1. Build charge power profile P(t) - Option A (plateau shape)
charge_ramp_up   = linspace(0, 150000, 120);   % W, 0 -> 150kW over 120s
charge_sustain   = ones(1,600) * 150000;       % W, flat 150kW for 600s
charge_ramp_down = linspace(150000, 0, 300);   % W, 150kW -> 0 over 300s

P = [charge_ramp_up, charge_sustain, charge_ramp_down];  % W
t = (0:length(P)-1)';                                     % s, 1 Hz resolution
P = P';                                                    % column vector
simTime = length(P);
fprintf('Option A profile: %d points, %.1f min duration\n', ...
    length(P), length(P)/60);

%% 2. Convert power -> current -> ohmic heat generation
% ASSUMPTION (flagged, not yet confirmed): fixed nominal pack voltage.
% Real Model 3 pack voltage rises roughly 320V (low SOC) -> 396V (high SOC).
% Using a fixed value here is a simplification - note it in your README.
V_nominal = 350;      % V, fixed nominal pack voltage assumption

% R_pack derived from teardown data: 21700 cell DCIR (~25 mOhm at 30C)
% combined via 96-series / 46-parallel pack topology:
%   R_pack = R_cell * (Nseries / Nparallel) = 0.025 * (96/46)
R_pack = 0.025 * (96/46);   % ohm, ~0.0522

I = P / V_nominal;          % A, charge current
q = I.^2 * R_pack;          % W, ohmic heat generation Qgen = I^2 * R

fprintf('Peak current: %.1f A\n', max(I));
fprintf('Peak heat generation: %.1f W\n', max(q));

%% 3. Hand-calc sanity check (do this before trusting the numbers above)
% At P=150kW, V=350V:  I = 150000/350 = 428.6 A
% Qgen_peak = I^2 * R_pack = 428.6^2 * 0.0522 ~= 9590 W
% Compare this to the "Peak heat generation" printed above - should match
% within rounding. If not, check units on R_pack or V_nominal.

%% 4. Build simin for the From Workspace block
simin = [t, q];

disp('simin size:'); disp(size(simin));
disp('First 5 rows:'); disp(simin(1:5,:));
disp('Last row:'); disp(simin(end,:));
% Checkpoint: size should be [N,2]; last row's time should equal
% length(q)-1; first row's heat value should equal q(1) above.

%% 5. Run the Simscape model
% Update model_name to match your actual .slx filename.
model_name = 'battery_cooling.slx';
simout = sim(model_name);
% Because the model's To Workspace blocks are named T_pack and tout
% (format: Array), running sim() here pushes them directly into this
% script's workspace - no simOut/logsout extraction needed.
T_pack = simout.T_pack.Data;
tout = simout.T_pack.Time;
disp(T_pack);
%% 6. Plot results
figure;
plot(tout, T_pack, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Pack Temperature (\circC)');
title('Option A: Plateau Charge Profile - Battery Pack Temperature');
grid on;

[T_peak, idx_peak] = max(T_pack);
fprintf('Peak pack temperature: %.2f degC at t = %.1f s\n', ...
    T_peak, tout(idx_peak));
