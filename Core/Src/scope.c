#include "scope.h"
#include "adc.h"
#include "stm32h7xx_hal.h"
#include "tim.h"
#include "usart.h"

#define TIM_FREQ 275000000
#define SAMPLE_LENGTH (1 << 10)
#define CHANNEL_NUM 2
#define ESCAPE_CHAR '\\'

typedef struct {
    ADC_HandleTypeDef *adc;
    TIM_HandleTypeDef *tim;
    uint16_t data[SAMPLE_LENGTH];
    uint8_t completed;
} ScopeChannel;

ScopeChannel scope_channel[CHANNEL_NUM] = {
    {
        .adc = &hadc1,
        .tim = &htim3,
    },
    {
        .adc = &hadc2,
        .tim = &htim4,
    },
};
uint32_t command;

void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef *hadc)
{
    for (uint8_t i = 0; i < CHANNEL_NUM; i++)
        scope_channel[i].completed = scope_channel[i].adc == hadc;
}

void scope_init()
{
    for (uint8_t i = 0; i < CHANNEL_NUM; i++)
    {
        HAL_ADCEx_Calibration_Start(scope_channel[i].adc, ADC_CALIB_OFFSET,
                                    ADC_DIFFERENTIAL_ENDED);
        HAL_TIM_Base_Start(scope_channel[i].tim);
        HAL_ADC_Start_DMA(scope_channel[i].adc,
                          (uint32_t *)scope_channel[i].data, SAMPLE_LENGTH);
    }
    HAL_UART_Receive_IT(&huart2, (uint8_t *)&command, sizeof(command));
}

void scope_update()
{
    for (uint8_t k = 0; k < CHANNEL_NUM; k++)
    {
        if (!scope_channel[k].completed) continue;

        uint8_t frame[SAMPLE_LENGTH * 4 + 4];
        uint32_t l = 0;
        frame[l++] = k;
        frame[l++] = k;
        for (uint32_t i = 0; i < SAMPLE_LENGTH; i++)
        {
            uint8_t a = scope_channel[k].data[i] >> 8;
            uint8_t b = scope_channel[k].data[i] & 0xff;
            if (a == k || a == ESCAPE_CHAR || a == 0xff)
                frame[l++] = ESCAPE_CHAR;
            frame[l++] = a;
            if (b == k || b == ESCAPE_CHAR || b == 0xff)
                frame[l++] = ESCAPE_CHAR;
            frame[l++] = b;
        }
        frame[l++] = k;
        frame[l++] = 0xff;
        HAL_UART_Transmit(&huart2, frame, l, HAL_MAX_DELAY);

        scope_channel[k].completed = 0;
        HAL_ADC_Start_DMA(scope_channel[k].adc,
                          (uint32_t *)scope_channel[k].data, SAMPLE_LENGTH);
    }
}

void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart != &huart2) return;
    // 高四位通道号, 其余位为频率
    uint8_t channel = command >> 28;
    uint32_t frequent = command & 0xfffffff;
    __HAL_TIM_SET_COUNTER(scope_channel[channel].tim, 0);
    __HAL_TIM_SET_AUTORELOAD(scope_channel[channel].tim, TIM_FREQ / frequent);
    HAL_UART_Receive_IT(&huart2, (uint8_t *)&command, sizeof(command));
}