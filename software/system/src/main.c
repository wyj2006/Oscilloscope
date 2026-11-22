#include <stdio.h>

#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"

int main()
{
    Xil_DCacheDisable();

    while (1)
    {
        printf("Hello,World");
    }
}