#include <time.h>
#include "arch/sys_arch.h"
#include "lwip/sys.h"

u32_t sys_now(void) {
    clock_t i = clock() / (CLOCKS_PER_SEC / 1000);
    
    return (u32_t)i;
}

void
sys_init(void)
{
}