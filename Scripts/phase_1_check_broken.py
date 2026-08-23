import matplotlib.pyplot as m
import numpy as np

C = 480000 #J/K
UA = 600 #W/K - heat permitted
T_coolant = 25 #degC
T_initial = 25 #degC
Power_Charge = 150000 #W
charge_ramp_up = np.linspace(0,150000,120)
charge_ramp_down = np.linspace(150000, 0, 300)

def heat_t(power_t):
    Effi_Charge = 0.9 #90%
    q_t = (1-Effi_Charge)*power_t
    return q_t

#Using simple euler step to calculate max temp

temp = [] #degC
k = 0
T_k = T_initial
del_t = 1

def temp_t(q_k):
    T_k1 = T_k + del_t *(1/C * (q_k - UA * (T_k - T_coolant)))
    temp.append(T_k1 + 25)
    T_k = T_k1
    return temp

for n in charge_ramp_up:
    q_k = heat_t(n)
    temp_up = temp_t(q_k)

q_k = heat_t(Power_Charge)
while k<600:
    temp_charge = temp_t(q_k)
    k+=1

for n in charge_ramp_down:
    q_k = heat_t(n)
    temp_down = temp_t(q_k)

temp = temp_up + temp_charge + temp_down

m.plot(temp)
m.show()