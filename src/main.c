#include <stddef.h>
#include <stdint.h>

#include "irq.h"
#include "mini_uart.h"
#include "printf.h"
#include "sched.h"
#include "task.h"
#include "timer.h"
#include "utils.h"
#include "mm.h"
#include "sd.h"
#include "debug.h"
#include "loader.h"

void mini_uart_puts(char *str) {
  if (!str) return;
  while(*str) {
    uart_send(*str++);
  }
}

static void mini_uart_hex_dump(unsigned int value) {
	char buf[9];
	char hex[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
	unsigned int mask = 0xf0000000;
	for (int i = 0; i < 8; i++) {
		buf[i] = hex[(value & mask) >> (28-i*4)];
		mask >>= 4;
	}
	buf[8] = '\0';
	mini_uart_puts(buf);
}


void hypervisor_main() {
  uart_init();
#if 1
  init_printf(NULL, putc);
  printf("=== raspvisor ===\n");
  unsigned int sctlr_el2;
  unsigned int hcr_el2;
  __asm__ volatile ("mrs %0, sctlr_el2" : "=r"(sctlr_el2) : :);
  __asm__ volatile ("mrs %0, hcr_el2" : "=r"(hcr_el2) : :);
  printf("\nsctlr_el2: ");
  mini_uart_hex_dump(sctlr_el2);
  printf("\nhcr_el2: ");
  mini_uart_hex_dump(hcr_el2);
  printf("\nsctlr_el2: %x\n", sctlr_el2);
  printf("hcr_el2: %x\n", hcr_el2);
#else
  mini_uart_puts("=== raspvisor ===\n\r");
#endif
#if 1
  init_task_console(current);
  init_initial_task();
  irq_vector_init();
  timer_init();
  disable_irq();
  enable_interrupt_controller();

  if (sd_init() < 0)
    PANIC("sd_init() failed.");

  struct raw_binary_loader_args bl_args1 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "MINI-OS.BIN",
  };
  if (create_task(raw_binary_loader, &bl_args1) < 0) {
    printf("error while starting task");
    return;
  }

  struct raw_binary_loader_args bl_args2 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "ECHO.BIN",
  };
  if (create_task(raw_binary_loader, &bl_args2) < 0) {
    printf("error while starting task");
    return;
  }

  struct raw_binary_loader_args bl_args3 = {
    .load_addr = 0x0000,
    .entry_point = 0x0000,
    .sp = 0x100000,
    .filename = "FreeRTOS.bin",
  };
  if (create_task(raw_binary_loader, &bl_args3) < 0) {
    printf("error while starting task #2");
    return;
  }

#if 0
  struct raw_binary_loader_args bl_args4 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "ECHO.BIN",
  };
  if (create_task(raw_binary_loader, &bl_args4) < 0) {
    printf("error while starting task");
    return;
  }

  struct raw_binary_loader_args bl_args5 = {
    .load_addr = 0x0,
    .entry_point = 0x0,
    .sp = 0x100000,
    .filename = "MINI-OS.BIN",
  };
  if (create_task(raw_binary_loader, &bl_args5) < 0) {
    printf("error while starting task");
    return;
  }
#endif

  while (1) {
    disable_irq();
    schedule();
    enable_irq();
  }
#endif
}
