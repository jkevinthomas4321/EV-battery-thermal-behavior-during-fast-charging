import matplotlib.pyplot as m
import numpy as np

# Parameters
C = 480000  # J/K
UA = 600    # W/K
T_coolant = 25
T_k = 25    # initial temperature
Power_Charge = 150000
del_t = 1

# Charging profile
charge_ramp_up = np.linspace(0, 150000, 120)
charge_sustain = np.ones(600) * 150000
charge_ramp_down = np.linspace(150000, 0, 300)

power_profile = np.concatenate([charge_ramp_up, charge_sustain, charge_ramp_down])
print(len(power_profile))
print(power_profile)
# Heat function
def heat_t(power_t):
    Effi_Charge = 0.9
    return (1 - Effi_Charge) * power_t

# Temperature list
temp = []

# Euler step
for P in power_profile:
    q_k = heat_t(P)
    dTdt = (q_k - UA * (T_k - T_coolant)) / C
    T_k = T_k + del_t * dTdt
    temp.append(T_k)

# Plot
m.plot(temp)
m.xlabel("Time (s)")
m.ylabel("Temperature (°C)")
m.show()

print("Peak temperature:", max(temp))
