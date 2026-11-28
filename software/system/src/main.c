#include "stdio.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"

/*
 * display_controller 验证程序（PS 端）
 *
 * PL 端 video_generator.sv 通过 AXI 主口从 DDR 读一帧 1920x1080 图像：
 *   - 起始地址 = C_M_AXI_TARGET_SLAVE_BASE_ADDR = 0x10000000
 *   - 每像素 32bit: [31:30]=保留/切帧标记, [23:16]=R, [15:8]=G, [7:0]=B
 *
 * 本程序写两帧：
 *   帧0 @ 0x10000000                : 8 竖彩条（白黄青绿品红蓝黑）
 *   帧1 @ 0x10000000 + 1920*1080*4  : 水平亮度渐变
 * 打开 ENABLE_SWITCH 后，两帧末像素打 2'b11 标记，PL 读到末像素会自动切帧，
 * 屏上会彩条/渐变交替，说明 DDR->BRAM->HDMI 全链路和切帧逻辑都正常。
 */

#define FRAME_BASE 0x10000000u
#define H_DISP 1920
#define V_DISP 1080
#define FRAME_PIXELS (H_DISP * V_DISP)
#define FRAME_BYTES ((unsigned int)FRAME_PIXELS * 4u)

/* 32bit 像素拼装: R<<16 | G<<8 | B */
#define PIX(r, g, b)                                                           \
    (0x00000000u | (((unsigned int)(r)) << 16) | (((unsigned int)(g)) << 8)    \
     | ((unsigned int)(b)))
/* 末像素 [31:30]=2'b11，触发 PL 切到另一帧 */
#define TAG_SWITCH 0xC0000000u

/* 1 = 两帧交替；0 = 只显示帧0（彩条） */
#define ENABLE_SWITCH 1

int main()
{
    int x, y;

    static const unsigned int bars[8] = {
        PIX(255, 255, 255), /* 白 */
        PIX(255, 255, 0),   /* 黄 */
        PIX(0, 255, 255),   /* 青 */
        PIX(0, 255, 0),     /* 绿 */
        PIX(255, 0, 255),   /* 品红 */
        PIX(255, 0, 0),     /* 红 */
        PIX(0, 0, 255),     /* 蓝 */
        PIX(0, 0, 0)        /* 黑 */
    };

    Xil_DCacheDisable();
    xil_printf("display_controller test: writing DDR frames\r\n");

    /* ---- 帧0：8 竖彩条 ---- */
    for (y = 0; y < V_DISP; y++)
    {
        for (x = 0; x < H_DISP; x++)
        {
            unsigned int off = (unsigned int)(y * H_DISP + x);
            unsigned int pix = bars[(x * 8) / H_DISP];
            if (ENABLE_SWITCH && off == (unsigned int)FRAME_PIXELS - 1)
                pix |= TAG_SWITCH;
            Xil_Out32(FRAME_BASE + off * 4u, pix);
        }
    }
    xil_printf("frame0 (color bars) @0x%08x\r\n", FRAME_BASE);

    /* ---- 帧1：水平亮度渐变（逐行变亮，用于验证整帧/切帧） ---- */
    for (y = 0; y < V_DISP; y++)
    {
        unsigned int gray = (unsigned int)(y * 255 / (V_DISP - 1));
        for (x = 0; x < H_DISP; x++)
        {
            unsigned int off = (unsigned int)(y * H_DISP + x);
            unsigned int pix = PIX(gray, gray, gray);
            if (ENABLE_SWITCH && off == (unsigned int)FRAME_PIXELS - 1)
                pix |= TAG_SWITCH;
            Xil_Out32(FRAME_BASE + FRAME_BYTES + off * 4u, pix);
        }
    }
    xil_printf("frame1 (gradient)  @0x%08x\r\n", FRAME_BASE + FRAME_BYTES);

    while (1)
    {
    }
    return 0;
}
