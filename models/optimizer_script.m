%% ========================================================================
% EV Battery Thermal Management (BTMS) Analysis
%
% Workflow:
% Charging profile -> Heat generation -> Simscape simulation
% -> Charge-rate sweep -> Resistance sensitivity
% -> Specific-heat sensitivity -> Summary
%
% Simscape Thermal Mass block:
%   Mass         = pack_mass
%   Specific heat = cp_pack
% ========================================================================

clear;
clc;
close all;

%% 1. General settings

model_name = 'battery_cooling.slx';

T_limit_C = 45;        % Maximum allowed temperature [degC]
save_figs = true;      % Save figures

% Battery thermal properties
pack_mass = 480;       % Battery mass [kg]
cp_base   = 1000;      % Baseline specific heat [J/(kg*K)]


%% 2. Tesla V3 charging profile

soc_points = [2, 5, 20, 60, 80]; % SOC breakpoints [%]

power_kw = [126, 250, 250, 108, 56]; % Charging power at each breakpoint [kW]

pack_capacity_kwh = 75; % Battery capacity [kWh]

soc_energy = diff(soc_points) / 100 * pack_capacity_kwh; % Energy added in each SOC interval [kWh]

avg_power = (power_kw(1:end-1) + power_kw(2:end)) / 2; % Average power in each interval [kW]

durations_s = soc_energy ./ avg_power * 3600; % Duration of each interval [s]

segments = cell(1, length(power_kw) - 1); % Create smooth charging-power segments

for i = 1:length(power_kw)-1

    n_pts = max(round(durations_s(i)), 2);
    segments{i} = linspace( ...
        power_kw(i), ...
        power_kw(i+1), ...
        n_pts) * 1000;       % kW -> W

end


% Initial ramp from 0 to first charging power
initial_ramp = linspace(0, power_kw(1) * 1000, 5);

P_base = [initial_ramp, segments{:}]'; % Complete charging-power profile [W]

t = (0:length(P_base)-1)'; % Time vector [s]

simTime = t(end); % Simulation stop time

fprintf('Baseline charging profile:\n');
fprintf('  Points    : %d\n', length(P_base));
fprintf('  Duration  : %.1f min\n\n', simTime/60);

%% 3. Battery electrical parameters
V_nominal = 350;                   % Nominal voltage [V]

R_pack_base = 0.025 * (96 / 46); % Estimated pack resistance [ohm] - 96 cells in series and 46 cells in parallel

fprintf('Battery parameters:\n');
fprintf('  Voltage   : %.1f V\n', V_nominal);
fprintf('  Resistance: %.4f ohm\n', R_pack_base);
fprintf('  Mass      : %.1f kg\n', pack_mass);
fprintf('  Cp        : %.0f J/(kg*K)\n\n', cp_base);

%% 4. Baseline validation
% Baseline case:
%   Charge rate = 1.0x
%   Resistance  = nominal
%   Specific heat = cp_base

T_peak_check = run_btms_scale( ...
    P_base, ...
    t, ...
    V_nominal, ...
    R_pack_base, ...
    model_name, ...
    1.0, ...
    cp_base, ...
    pack_mass);


fprintf('========================================\n');
fprintf('BASELINE VALIDATION\n');
fprintf('Peak temperature = %.2f degC\n', T_peak_check);
fprintf('Expected value   = approximately 42.10 degC\n');
fprintf('========================================\n\n');

%% 5. Charge-rate sensitivity

% Test 50% to 200% of the baseline charging power
scale_factors = 0.5:0.1:2.0;

T_peaks_scale = zeros(size(scale_factors));

fprintf('--- Charge-rate sensitivity ---\n');

for i = 1:length(scale_factors)

    T_peaks_scale(i) = run_btms_scale( ...
        P_base, ...
        t, ...
        V_nominal, ...
        R_pack_base, ...
        model_name, ...
        scale_factors(i), ...
        cp_base, ...
        pack_mass);

    fprintf('Scale = %.1fx  ->  Peak T = %.2f degC\n', ...
        scale_factors(i), ...
        T_peaks_scale(i));

end

fprintf('\n');

%% 6. Find charging rate at 45 degC

if max(T_peaks_scale) >= T_limit_C && ...
   min(T_peaks_scale) <= T_limit_C

    % Estimate charge-rate scale corresponding to 45 degC
    scale_at_limit = interp1( ...
        T_peaks_scale, ...
        scale_factors, ...
        T_limit_C);

    fprintf('45 degC reached at approximately %.2fx charge rate.\n\n', ...
        scale_at_limit);

else
    scale_at_limit = NaN;
    fprintf('45 degC limit was not reached in tested range.\n\n');
end

%% 7. Charge-rate plot

figure;

plot(scale_factors, T_peaks_scale, ...
    'o-', ...
    'LineWidth', 1.5);

hold on;

% Safety temperature
yline(T_limit_C, ...
    'r--', ...
    'Safety limit', ...
    'LineWidth', 1.2);


% Estimated crossing point
if ~isnan(scale_at_limit)

    xline(scale_at_limit, ...
        'k:', ...
        sprintf('%.2fx', scale_at_limit));
end


xlabel('Charge-rate scale factor');
ylabel('Peak Pack Temperature (degC)');
title('Peak Battery Temperature vs Charge Rate');
grid on;

if save_figs
    saveas(gcf, 'fig_charge_rate_sweep.png');
end

%% 8. Resistance sensitivity

% Test -20%, nominal, and +20% resistance
R_variants = R_pack_base * [0.8, 1.0, 1.2];

T_peaks_R = zeros(size(R_variants));

fprintf('--- Resistance sensitivity ---\n');

for i = 1:length(R_variants)

    T_peaks_R(i) = run_btms_scale( ...
        P_base, ...
        t, ...
        V_nominal, ...
        R_variants(i), ...
        model_name, ...
        1.0, ...
        cp_base, ...
        pack_mass);

    R_change = ...
        (R_variants(i) / R_pack_base - 1) * 100;

    fprintf( ...
        'R = %.4f ohm (%+.0f%%) -> Peak T = %.2f degC\n', ...
        R_variants(i), ...
        R_change, ...
        T_peaks_R(i));
end
fprintf('\n');

%% 9. Specific-heat sensitivity

% Test two specific-heat assumptions:
% 320 J/(kg*K)  = 0.32 kJ/(kg*K)
% 1000 J/(kg*K) = 1.00 kJ/(kg*K)

cp_variants = [320, 1000];

T_peaks_cp = zeros(size(cp_variants));

fprintf('--- Specific-heat sensitivity ---\n');

for i = 1:length(cp_variants)

    T_peaks_cp(i) = run_btms_scale( ...
        P_base, ...
        t, ...
        V_nominal, ...
        R_pack_base, ...
        model_name, ...
        1.0, ...
        cp_variants(i), ...
        pack_mass);

    fprintf( ...
        'Cp = %.0f J/(kg*K) -> Peak T = %.2f degC\n', ...
        cp_variants(i), ...
        T_peaks_cp(i));
end

fprintf('\n');

%% 10. Calculate thermal masses

% Thermal mass = mass * specific heat
C_variants = pack_mass * cp_variants;

fprintf('Equivalent thermal masses:\n');

for i = 1:length(C_variants)

    fprintf( ...
        'Cp = %.0f J/(kg*K) -> C = %.0f J/K\n', ...
        cp_variants(i), ...
        C_variants(i));
end

fprintf('\n');

%% 11. Final summary

fprintf('========================================\n');
fprintf('FINAL SUMMARY\n');
fprintf('========================================\n');

fprintf( ...
    'Baseline peak temperature : %.2f degC\n', ...
    T_peak_check);

if isnan(scale_at_limit)

    fprintf( ...
        '45 degC limit             : Not reached\n');
else
    fprintf( ...
        '45 degC reached at        : %.2fx charge rate\n', ...
        scale_at_limit);
end
fprintf( ...
    'R-pack sensitivity        : %.2f - %.2f degC\n', ...
    min(T_peaks_R), ...
    max(T_peaks_R));
fprintf( ...
    'Cp sensitivity            : %.2f - %.2f degC\n', ...
    min(T_peaks_cp), ...
    max(T_peaks_cp));
fprintf('========================================\n');


%% ========================================================================
% LOCAL FUNCTION
% Runs one BTMS simulation and returns peak pack temperature.
% ========================================================================

function T_peak = run_btms_scale( ...
    P_base, ...
    t, ...
    V_nominal, ...
    R_pack, ...
    model_name, ...
    scale_factor, ...
    cp_pack, ...
    pack_mass)

    P = P_base * scale_factor; % Scale charging power

    I = P / V_nominal;  % Calculate battery current

    q = I.^2 * R_pack; % Calculate resistive heat generation

    simin = [t, q];  % Send variables to Simulink base workspace

    assignin('base', 'simin', simin);
    assignin('base', 'cp_pack', cp_pack);
    assignin('base', 'pack_mass', pack_mass);
    assignin('base', 'simTime', t(end));

    fprintf('\nDEBUG:\n');
    fprintf('  pack_mass = %.4f kg\n', pack_mass);
    fprintf('  cp_pack   = %.4f J/(kg*K)\n', cp_pack);
    fprintf('  simTime   = %.4f s\n', t(end));
    fprintf('  Heat max  = %.2f W\n\n', max(q));

    % Run Simscape model

    out = sim(model_name); %Get the output
    my_data = out.T_pack;  % Read temperature from To Workspace block

    T_values = my_data.Data;

    % Temp Unit check
    if mean(T_values) > 200
        T_values = T_values - 273.15;
    end
    
    T_peak = max(T_values); % Find peak temperature
end