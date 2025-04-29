#include <stdint.h>
#include <string.h>
#include "FreeRTOS.h"
#include "rpi-SmartStart.h"
#include "task.h"

static char taskInfo[1024];
void cmd_dispatch(char *cmd) {
	if (!strcmp("tasks", cmd)) {
		vTaskList(taskInfo);
		console_uart_puts(taskInfo);
	}
}

void task5 (void *pParam) {
	char cmd[64];
	int cnt;
	char ch;
	console_uart_init(115200);
	miniuart_settings_dump();
	while(1) {
_next:
		console_uart_puts("\r\ncmd> ");
		cnt = 0;
		while (1) {
			ch = console_uart_getc();
			switch(ch) {
			case '\b':
				if (cnt) {
					console_uart_putc(ch);
					console_uart_putc(' ');
					console_uart_putc(ch);
					cnt--;
				}
				break;
			case '\n':
			case '\r':
				cmd[cnt] = '\0';
				console_uart_puts("\r\n");
				cmd_dispatch(cmd);
				goto _next;
			default:
				if (cnt < 63) {
					cmd[cnt++] = ch;
					console_uart_putc(ch);
				}
				break;
			}
		}
	}
}


void main (void)
{
	xTaskCreate(task5, "cmd", 2048, NULL, 2, NULL);
	vTaskStartScheduler();
	while (1) {
	}
}

