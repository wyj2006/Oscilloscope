#include "signal_generator.h"
#include "arm_math.h"
#include "math.h"
#include "tjc_usart_hmi.h"

#define CLK_FREQ 137500000

int frequent[] = {100, 100}; // Hz/10
int peak[] = {0, 0};         // V*100
WaveKind wave_kind[] = {Sine, Sine};
TIM_HandleTypeDef *output_tim[] = {&htim2, &htim4};
int dac_channel[] = {DAC_CHANNEL_1, DAC_CHANNEL_2};
uint16_t table[2][MAX_TABLE_LEN];
int table_len[] = {TABLE_LEN, TABLE_LEN};
int use_pregen_table[] = {1, 1};
int dyn_table_len[] = {0, 0};
int y_offset[] = {50, 50};

float __attribute__((section(".ram_d1"))) wave_table[2][MAX_TABLE_LEN];

void Signal_Generator_Init()
{
    Generate_Wave();

    for (int i = 0; i < 2; i++) HAL_TIM_Base_Start(output_tim[i]);
}

void Generate_Wave()
{
    for (int k = 0; k < 2; k++)
    {
        if (dyn_table_len[k] == 1)
            table_len[k] = MAX_TABLE_LEN * 100 / frequent[k];

        float offset = (float)y_offset[k] * V_MAX / 330;

        if (use_pregen_table[k] == 1)
        {
            for (int i = 0; i < MAX_TABLE_LEN; i++)
                table[k][i] =
                    (float)pregen_wave_table[wave_kind[k]][i % TABLE_LEN]
                        * peak[k] / 330
                    + offset;
            __HAL_TIM_SET_PRESCALER(output_tim[k],
                                    CLK_FREQ / frequent[k] / 10 / TABLE_LEN);
        }
        else
        {
            switch (wave_kind[k])
            {
            case Sine:
                for (int i = 0; i < table_len[k]; i++)
                {
                    wave_table[k][i] =
                        (sin(2 * M_PI * i / table_len[k])) * V_MAX_HALF
                        + V_MAX_HALF;
                }
                break;
            case Square:
                for (int i = 0; i < table_len[k]; i++)
                {
                    if (i < table_len[k] / 2)
                        wave_table[k][i] = 0;
                    else
                        wave_table[k][i] = V_MAX;
                }
                break;
            case Triangle: {
                float one = (float)table_len[k] / 4;
                float third = (float)table_len[k] * 3 / 4;
                for (int i = 0; i < table_len[k]; i++)
                {
                    if (i <= one)
                        wave_table[k][i] =
                            V_MAX_HALF + (float)i * V_MAX_HALF / one;
                    else if (one < i && i < third)
                        wave_table[k][i] =
                            V_MAX - (float)(i - one) * V_MAX / (third - one);
                    else
                        wave_table[k][i] =
                            (float)(i - third) * V_MAX_HALF / one;
                }
                break;
            }
            }
            for (int i = 0; i < MAX_TABLE_LEN; i++)
                table[k][i] =
                    wave_table[k][i % table_len[k]] * peak[k] / 330 + offset;
            if (dyn_table_len[k] == 0)
                __HAL_TIM_SET_PRESCALER(output_tim[k], CLK_FREQ / frequent[k]
                                                           / 10 / table_len[k]);
            else
                __HAL_TIM_SET_PRESCALER(output_tim[k],
                                        CLK_FREQ / MAX_TABLE_LEN);
        }
    }
}
