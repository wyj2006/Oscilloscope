#ifndef __SCOPE_H
#define __SCOPE_H

#include "adc.h"
#include "tim.h"

#define SAMPLE_BUFFER_SIZE 1024

extern int show_fft[];
extern int analyze_enabled[];
extern ADC_HandleTypeDef *adc[];
extern uint16_t
    __attribute__((section(".ram_d1"))) adc_buffer[2][SAMPLE_BUFFER_SIZE];

void Scope_Init();
void Scope_Analyze();

#endif