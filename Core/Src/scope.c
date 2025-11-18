#include <stdlib.h>
#include <string.h>

#include "arm_const_structs.h"
#include "arm_math.h"
#include "gui.h"
#include "scope.h"
#include "tjc_usart_hmi.h"

#define ABS(x) ((x) >= 0 ? (x) : -(x))
#define CLK_FREQ 275000000
#define MAX_SAMPLE_FREQ 3600000
#define MIN_SAMPLE_FREQ 45000
#define V_MAX 65536
// 透传数据长度
#define TT_NUM 274
#define HISTORY_NUM 20

TIM_HandleTypeDef *sample_tim[] = {&htim3, &htim8};
ADC_HandleTypeDef *adc[] = {&hadc1, &hadc2};
uint16_t adc_buffer[2][SAMPLE_BUFFER_SIZE];
uint32_t sample_frequent[] = {MAX_SAMPLE_FREQ, MAX_SAMPLE_FREQ};
uint8_t sample_completed[] = {0, 0};
float32_t fft_output[2][SAMPLE_BUFFER_SIZE];
int show_fft[] = {0, 0};
int analyze_enabled[] = {0, 0};

float32_t rms_buffer[SAMPLE_BUFFER_SIZE];
float32_t wave[SAMPLE_BUFFER_SIZE];
float32_t fft_buffer[SAMPLE_BUFFER_SIZE * 2];
uint32_t history_frequent[2][HISTORY_NUM][2] = {0};
uint32_t ratio[] = {50, 48, 45, 40, 36, 32, 30, 25, 24, 20, 18,
                    16, 15, 12, 10, 9,  8,  6,  5,  4,  3};

void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef *hadc)
{
    for (int i = 0; i < 2; i++)
        if (hadc == adc[i]) sample_completed[i] = 1;
}

void Scope_Init()
{
    for (int k = 0; k < 2; k++)
    {
        HAL_ADCEx_Calibration_Start(adc[k], ADC_CALIB_OFFSET, ADC_SINGLE_ENDED);
        HAL_TIM_Base_Start(sample_tim[k]);
        HAL_ADC_Start_DMA(adc[k], (uint32_t *)adc_buffer[k],
                          SAMPLE_BUFFER_SIZE);
        __HAL_TIM_SET_COUNTER(sample_tim[k], 0);
        __HAL_TIM_SET_AUTORELOAD(sample_tim[k], CLK_FREQ / sample_frequent[k]);
    }
}

int Is_Stable(int k, int frequent, int length)
{
    for (int i = 0; i < length; i++)
    {
        if (history_frequent[k][i][0] == 0
            || ABS((float)frequent - history_frequent[k][i][0]) / frequent
                   >= 0.05)
            return 0;
    }
    return 1;
}

void Scope_Analyze()
{
    char command[100];

    for (int k = 0; k < 2; k++)
    {
        if (sample_completed[k] == 0) continue;
        if (analyze_enabled[k] == 0) goto restart;

        for (int i = 0; i < SAMPLE_BUFFER_SIZE; i++)
            wave[i] = adc_buffer[k][i] * 3.3 / V_MAX;

        // 计算最大最小值
        float32_t vmax, vmin;
        uint32_t vmaxi, vmini;
        float32_t vpp;
        arm_max_f32(wave, SAMPLE_BUFFER_SIZE, &vmax, &vmaxi);
        arm_min_f32(wave, SAMPLE_BUFFER_SIZE, &vmin, &vmini);
        // 显示峰峰值
        vpp = vmax - vmin;
        sprintf(command, "main.a%d.val=%d", k + 1, (int)(vpp * 100));
        tjc_send_string(command);

        for (int i = 0; i < SAMPLE_BUFFER_SIZE; i++)
        {
            fft_buffer[2 * i] = adc_buffer[k][i];
            fft_buffer[2 * i + 1] = 0;
        }

        // 傅里叶变换
        arm_cfft_f32(&arm_cfft_sR_f32_len1024, fft_buffer, 0, 1);
        arm_cmplx_mag_f32(fft_buffer, fft_output[k], SAMPLE_BUFFER_SIZE);

        fft_output[k][0] /= SAMPLE_BUFFER_SIZE;
        for (int i = 1; i < SAMPLE_BUFFER_SIZE; i++)
            fft_output[k][i] /= SAMPLE_BUFFER_SIZE / 2.0;

        // 计算频率
        uint32_t fmaxi;
        float32_t fmax;
        fft_output[k][0] = 0;
        arm_max_f32(fft_output[k], SAMPLE_BUFFER_SIZE / 2, &fmax, &fmaxi);
        uint32_t frequent = fmaxi * sample_frequent[k] / SAMPLE_BUFFER_SIZE;
        sprintf(command, "main.f%d.val=%d", k + 1, frequent / 10);
        tjc_send_string(command);

        // 确定波类型
        int num_points = sample_frequent[k] / frequent * 4;
        for (int i = 0; i < num_points; i++)
            rms_buffer[i] = wave[i] - vmin - vpp / 2.0;

        float32_t rms;
        arm_rms_f32(rms_buffer, num_points, &rms);
        rms = rms / (vpp / 2.0);

        char *kind = "???";
        if (rms > 0.64 && rms < 0.8)
            kind = "正弦波";
        else if (rms > 0.8)
            kind = "方波";
        else if (rms < 0.63)
            kind = "三角波";

        sprintf(command, "main.k%d.txt=\"%s\"", k + 1, kind);
        tjc_send_string(command);

        if (Is_Stable(k, frequent, HISTORY_NUM) == 1)
        {
            int sum[2] = {0, 0};
            for (int i = 0; i < HISTORY_NUM; i++)
            {
                sum[0] += history_frequent[k][i][0];
                sum[1] += history_frequent[k][i][1];
            }
            int d = sum[0] / HISTORY_NUM - frequent;
            sample_frequent[k] = sum[1] / HISTORY_NUM + d;
        }
        else if (Is_Stable(k, frequent, HISTORY_NUM - 1) == 1)
            sample_frequent[k] = MAX_SAMPLE_FREQ;
        else
        {
            int f = 50;
            for (int i = 0; i < sizeof(ratio) / sizeof(uint32_t); i++)
            {
                if (frequent < MAX_SAMPLE_FREQ / ratio[i])
                {
                    f = ratio[i];
                    break;
                }
            }
            sample_frequent[k] = frequent * f;
        }
        if (sample_frequent[k] < MIN_SAMPLE_FREQ)
            sample_frequent[k] = MIN_SAMPLE_FREQ;
        if (sample_frequent[k] > MAX_SAMPLE_FREQ)
            sample_frequent[k] = MAX_SAMPLE_FREQ;
        for (int i = 0; i < HISTORY_NUM; i++)
        {
            history_frequent[k][i][0] =
                i < HISTORY_NUM - 1 ? history_frequent[k][i + 1][0] : frequent;
            history_frequent[k][i][1] = i < HISTORY_NUM - 1 ?
                                            history_frequent[k][i + 1][1] :
                                            sample_frequent[k];
        }

        sprintf(command, "main.n%d.val=%d", k, sample_frequent[k]);
        tjc_send_string(command);

        // 显示波形
        int offset = MIN(vmaxi, vmini);
        for (int i = 1; i < SAMPLE_BUFFER_SIZE - 1; i++)
        {
            if (adc_buffer[k][i] <= adc_buffer[k][i - 1]
                && adc_buffer[k][i] <= adc_buffer[k][i + 1]
                && (wave[i] - vmin) < vpp * 0.1)
            {
                offset = i;
                break;
            }
        }

        sprintf(command, "addt main.s0.id,%d,%d", k, TT_NUM);
        tjc_send_string(command);
        HAL_Delay(100);
        for (int i = offset; i < offset + TT_NUM; i++)
            uart_send_char((int)(adc_buffer[k][i] * 255ull / V_MAX));

        if (show_fft[k] == 1)
        {
            HAL_Delay(1);
            sprintf(command, "addt main.s0.id,%d,%d", k + 2, TT_NUM);
            tjc_send_string(command);
            HAL_Delay(100);
            for (int i = 0; i < TT_NUM; i++)
                uart_send_char((char)(fft_output[k][i] * 255 / fmax));
        }
        else
        {
            HAL_Delay(1);
            sprintf(command, "cle main.s0.id,%d", k + 2);
            tjc_send_string(command);
        }

        sample_completed[k] = 0;
    restart:
        __HAL_TIM_SET_COUNTER(sample_tim[k], 0);
        __HAL_TIM_SET_AUTORELOAD(sample_tim[k], CLK_FREQ / sample_frequent[k]);
        HAL_ADC_Start_DMA(adc[k], (uint32_t *)adc_buffer[k],
                          SAMPLE_BUFFER_SIZE);
    }
}