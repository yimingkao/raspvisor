SECTIONS
{
  . = 0x0000000000080000;
  .text.boot : { *(.text.boot) }
  . = ALIGN(0x00001000);
  el1_test_begin = .;
  .text.user : { build/el1_* (.text) }
  .rodata.user : { build/el1_* (.rodata) }
  .data.user : { build/el1_* (.data) }
  .bss.user : { build/el1_* (.bss) }
  el1_test_end = .;
  .text :  { *(.text) }
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  . = ALIGN(0x8);
  bss_begin = .;
  .bss : { *(.bss*) }
  bss_end = .;
  . = ALIGN(0x00001000);
	.stack_core0 : {
        . = ALIGN(16);				/* Stack must always be aligned to 16 byte boundary AAPCS64 call standard */
        __stack_start_core0__ = .;
        . = . + 16384;				/* EL0 stack size */
        __EL0_stack_core0 = .;
        . = . + 16384;				/* EL1 stack size */
        __EL1_stack_core0 = .;
        . = . + 512;				/* EL2 stack size (start-up) */
        __EL2_stack_core0 = .;
        __stack_end_core0__ = .;    
    }
  . = ALIGN(0x00001000);
  pg_dir = .;
  .data.pgd : { . += (3 * (1 << 12)); }
}

