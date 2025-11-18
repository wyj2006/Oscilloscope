from math import *

n = 50

v_max = 0xFFF
v_max_half = v_max >> 1


sin_table = []
for t in range(n):
    sin_table.append(round((sin(2 * pi * t / n)) * v_max_half+v_max_half))

square_table = [0] * (n // 2) + [v_max] * (n // 2)

triangle_table = []
one = n / 4
third = n * 3 / 4
for t in range(n):
    if t <= one:
        k = v_max_half + t * v_max_half / one
    elif one < t < third:
        k = v_max - (t - one) * v_max / (third - one)
    else:
        k = (t - third) * v_max_half / one
    triangle_table.append(int(k))

with open("pregen_wave_table.h", mode="w", encoding="utf-8") as file:
    file.write(f"#define TABLE_LEN {n}\n")
    file.write(f"#define V_MAX {v_max}u\n")
    file.write(f"#define V_MAX_HALF {v_max_half}u\n")
    file.write(
        f"static uint64_t pregen_wave_table[][TABLE_LEN]={{{{{str(sin_table)[1:-1]}}},{{{str(square_table)[1:-1]}}},{{{str(triangle_table)[1:-1]}}}}};\n"
    )
