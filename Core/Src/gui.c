#include "gui.h"
#include "scope.h"
#include "signal_generator.h"
#include "tjc_usart_hmi.h"

void Gui_Check()
{
    if (usize < 1) return;

    uint8_t h = u(0);
    uint8_t a = h >> 4;
    uint8_t b = h & 0xf;
    if (((a == 0xf || a == 0xa || a == 0xd || a == 0xb || a == 0xe || a == 0x9
          || a == 0x5)
         && (b == 1 || b == 2))
        || ((a == 0xc)
            && (b == 1 || b == 2 || b == 3 || b == 4 || b == 5 || b == 6)))
    {
        if (usize < 3) return;
        uint16_t v = (uint16_t)u(1) + ((uint16_t)u(2) << 8);
        switch (a)
        {
        case 0xf: frequent[b - 1] = v; break;
        case 0xa: peak[b - 1] = v; break;
        case 0xd:
            switch (v)
            {
            case 0: wave_kind[b - 1] = Sine; break;
            case 1: wave_kind[b - 1] = Square; break;
            case 2: wave_kind[b - 1] = Triangle; break;
            }
            break;
        case 0xb: show_fft[b - 1] = v; goto notgen;
        case 0xc:
            if (b == 1 || b == 2)
                use_pregen_table[b - 1] = v;
            else if (b == 3 || b == 4)
                table_len[b - 3] = v;
            else if (b == 5 || b == 6)
                dyn_table_len[b - 5] = v;
            break;
        case 0xe: y_offset[b - 1] = v; break;
        case 0x9: analyze_enabled[b - 1] = v; goto notgen;
        case 0x5:
            if (v == 0)
                HAL_DAC_Stop_DMA(&hdac1, dac_channel[b - 1]);
            else
                HAL_DAC_Start_DMA(&hdac1, dac_channel[b - 1],
                                  (uint32_t *)table[b - 1], MAX_TABLE_LEN,
                                  DAC_ALIGN_12B_R);
            goto notgen;
        }
        Generate_Wave();
    notgen:
        udelete(3);
    }
    else
        udelete(1);
}

void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == TJC_UART_INS) // 判断是由哪个串口触发的中断
    {
        write1ByteToRingBuffer(RxBuffer[0]);
        Gui_Check();
        HAL_UART_Receive_IT(&TJC_UART, RxBuffer, 1);
    }
}