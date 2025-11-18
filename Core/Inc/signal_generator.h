#ifndef __SIGNAL_GENERATOR_H
#define __SIGNAL_GENERATOR_H

#include "dac.h"
#include "pregen_wave_table.h"
#include "tim.h"

#define MAX_TABLE_LEN 25000

typedef enum { Sine, Square, Triangle } WaveKind;

extern int frequent[]; // kHz*100
extern int peak[];     // V*100
extern __attribute__((section("ram_d1"))) WaveKind wave_kind[];
extern TIM_HandleTypeDef *output_tim[];
extern int dac_channel[];
extern uint16_t __attribute__((section(".ram_d1"))) table[][MAX_TABLE_LEN];
extern int table_len[];
extern int use_pregen_table[];
extern int dyn_table_len[];
extern int y_offset[];

void Signal_Generator_Init();
void Generate_Wave();

#endif