#include <unistd.h>
#include "py/mpconfig.h"

#include <debug_console_vf6xx.h>

/*
 * Core UART functions to implement for a port
 */

/* Receive single character */
int mp_hal_stdin_rx_chr(void)
{
    return debug_getchar();
}

/* Send string of given length */
void mp_hal_stdout_tx_strn(const char *str, mp_uint_t len)
{
    while (len--) {
	debug_putchar(*str++);
    }
}
