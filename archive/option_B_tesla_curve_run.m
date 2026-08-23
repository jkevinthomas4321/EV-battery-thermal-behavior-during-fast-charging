%% Project 2 - BTMS Transient Thermal Model
% Option B: Real Tesla Model 3 V3 Supercharger curve

%% 1. Real Tesla V3 charge curve breakpoints
soc_points = [2, 5, 20, 60, 80];
power_kw   = [126, 250, 250, 108, 56];
pack_capacity_kwh = 75;

%% 2. Approximate segment durations
soc_energy  = diff(soc_points) / 100 * pack_capacity_kwh; 
avg_power   = (power_kw(1:end-1) + power_kw(2:end)) / 2;
durations_s = (soc_energy ./ avg_power) * 3600;

%% 3. Build time-domain power curve
segments = {};
for i = 1:length(power_kw)-1
    n_pts = max(round(durations_s(i)), 2);
    seg = linspace(power_kw(i), power_kw(i+1), n_pts) * 1000;
    segments{end+1} = seg;
end

initial_ramp = linspace(0, power_kw(1)*1000, 5);

P = [initial_ramp, segments{:}]';
t = (0:length(P)-1)';

fprintf('Option B profile: %d points, %.1f min duration\n', ...
    length(P), length(P)/60);

%% 4. Convert power -> current -> heat
V_nominal = 350;
R_pack = 0.025 * (96/46);

I = P / V_nominal;
q = I.^2 * R_pack;

fprintf('Peak current: %.1f A\n', max(I));
fprintf('Peak heat generation: %.1f W\n', max(q));

%% 5. Build simin for From Workspace
simin = [t, q];

disp('simin size:'); disp(size(simin));
disp('First 5 rows:'); disp(simin(1:5,:));
disp('Last row:'); disp(simin(end,:));

%% 6. Run Simscape model
model_name = 'battery_cooling.slx';
simout = sim(model_name);

%% 7. Extract TimeSeries safely
T_raw = simout.T_pack;

if isa(T_raw, 'timeseries')
    T_pack = T_raw.Data;
    tout   = T_raw.Time;
else
    T_pack = T_raw;
    tout   = simout.tout;
end
T_pack = T_pack-273.15;
%% 8. Plot results
figure;
plot(tout, T_pack, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Pack Temperature (°C)');
title('Option B: Real Tesla V3 Curve - Battery Pack Temperature');
grid on;

[T_peak, idx_peak] = max(T_pack);
fprintf('Peak pack temperature: %.2f °C at t = %.1f s\n', ...
    T_peak, tout(idx_peak));

%% 9. Compare power vs temperature
figure;
subplot(2,1,1);
plot(t, P/1000, 'LineWidth', 1.5);
ylabel('Charge Power (kW)');
title('Input Power Profile');
grid on;

subplot(2,1,2);
plot(tout, T_pack, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Pack Temp (°C)');
title('Pack Temperature Response');
grid on;
