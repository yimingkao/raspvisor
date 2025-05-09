//"+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
//"																			"			
//"      Filename: smartstart64.s											"
//"      Copyright(c): Leon de Boer(LdB) 2017, 2018							"
//"      Version: 2.12														"
//"																			"		
//"***************[ THIS CODE IS FREEWARE UNDER CC Attribution]*************"
//"																			"
//"    This sourcecode is released for the purpose to promote programming   "
//"  on the Raspberry Pi. You may redistribute it and/or modify with the    "
//"  following disclaimer and condition.									"
//"																			"
//"      The SOURCE CODE is distributed "AS IS" WITHOUT WARRANTIES AS TO	"
//"   PERFORMANCE OF MERCHANTABILITY WHETHER EXPRESSED OR IMPLIED.			"
//"   Redistributions of source code must retain the copyright notices to	"
//"   maintain the author credit (attribution) .							"
//"																			"
//"*************************************************************************"
//"                                                                         "
//"      This code expands on my earlier SmartStart bootstub assembler for  "
//" the Pi3. It directly supports multicore operation in C/C++. To do that  "
//" it provides stack space to each core and provides modified bootloader   " 
//" spinlock that protects against registers X0-X7 trashed. As any C/C++    "
//" 64 bit compiler will trash those registers, to use C/C++ in multicore   "
//" programming this protection must be done.								"
//"       This is a matching paired AARCH64 stub for the 64bit linker file  "
//" and carries the same arrangement as AARCH32 pairs to ease porting.	    "
//"																			"
//"+++++++++++++++++++++++[ REVISIONS ]+++++++++++++++++++++++++++++++++++++"
//"  1.01 Initial release .. Pi autodetection main aim                      "
//"  1.02 Many functions moved out C to aide 32/64 bit compatability        "
//"  2.01 Futher reductions to bare minmum assembeler code                  "
//"  2.02 Multicore functionality added                                     "
//"  2.03 Timer Irq support added  											"
//"  2.04 David Welch routines GET32/PUT32 compability added                "
//"  2.05 Irq stub made weak linked so it can be easily overridden          "
//"  2.06 Added SmartStartVer											    "
//"  2.07 Fiq stub made weak linked so it can be easily overridden          "
//"  2.08 Added setIrqFuncAddress & setFiqFuncAddress                       "
//"  2.09 Added Hard/Soft float compiler support							"
//"  2.10 Context_switch support added										"
//"  2.11 MiniUart, PL011 Uart and console uart support added				"
//"  2.12 New FIQ, DAIF flag support added									"
//"+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

.section ".init", "ax", %progbits
.balign	8
.globl _start
_start:	
//"================================================================"
//  This simply hold startup data for SmartStart its trivial 
//"================================================================"
	adr x12, _start							// Hold boot address in high register R12
	ldr x1, =RPi_BootAddr					// Address of RPi_BootAddr
	str w12, [x1]							// Store the boot address

	ldr	x0, =0x3F000000						// No need to detect address in 64bit mode it has to be 0x3F000000 on Pi3
	ldr x1, =RPi_IO_Base_Addr				// Address of RPi_IO_Base_Addr
	str w0, [x1]							// Store the IO base address

	ldr	x0, =0xC0000000						// No need to detect address in 64bit mode it has to be 0xC0000000 on Pi3
	ldr x1, =RPi_ARM_TO_GPU_Alias			// Address of RPi_IO_Base_Addr
	str w0, [x1]							// Store the IO base address

	mov x0, #1								// Multicore support starts as 1 core
	ldr x1, =RPi_CoresReady					// Address of RPi_CoresReady
	str w0, [x1]							// Store the CoresReady count as 1

	mov x0, #0x98							// Compiled for ARM8 CPU in AARCH64 and supports 4 cores
.if (__ARM_FP == 14)
	orr x0, x0, #0x80000000				    // Set the hard float flag
.endif	
	ldr x1, =RPi_CompileMode				// Address of RPi_CompileMode
	str w0, [x1]							// Store the compiler mode  

	mrs	x0, midr_el1						// Read CPU Id register
	ldr x1, =RPi_CpuId						// Address of RPi_CpuId
	str w0, [x1]							// Store the CPU id 

//"================================================================"
//  Setup stack pointers for each core and each CPU operation mode
//"================================================================"
multicore_start:
    ldr x2, = __EL2_stack_core0				// Address of EL2_stack_core0 stack pointer value
    ldr x3, = __EL1_stack_core0				// Address of EL1_stack_core0 stack pointer value
    ldr x4, = __EL0_stack_core0				// Address of EL0_stack_core0 stack pointer value
	mrs x6, mpidr_el1						// Read core id on ARM8
	ands x6, x6, #0x3						// Make cpu id bitmask
	beq set_stacks							// Ready to set core 0 stacks
    ldr x2, = __EL2_stack_core1				// Address of EL2_stack_core1 stack pointer value
    ldr x3, = __EL1_stack_core1				// Address of EL1_stack_core1 stack pointer value
    ldr x4, = __EL0_stack_core1				// Address of EL0_stack_core1 stack pointer value
	cmp x6, #1								// Check cpu id for core 1
	beq set_stacks							// Ready to set core 1 stacks
    ldr x2, = __EL2_stack_core2				// Address of EL2_stack_core2 stack pointer value
    ldr x3, = __EL1_stack_core2				// Address of EL1_stack_core2 stack pointer value
    ldr x4, = __EL0_stack_core2				// Address of EL0_stack_core2 stack pointer value
	cmp x6, #2								// Check cpu id for core 2
	beq set_stacks							// Ready to set core 1 stacks
    ldr x2, = __EL2_stack_core3				// Address of EL2_stack_core3 stack pointer value
    ldr x3, = __EL1_stack_core3				// Address of EL1_stack_core3 stack pointer value
    ldr x4, = __EL0_stack_core3				// Address of EL0_stack_core3 stack pointer value
set_stacks:
#if EL1_BUILD
	mov	sp, x2								/* EL2 stack set */
	msr	sp_el1, x3							/* EL1 stack set */
	msr	sp_el0, x4							/* EL0 stack set */
#else
	mov	sp, x2								/* EL2 stack set */
	msr	sp_el1, x3							/* EL1 stack set */
	msr	sp_el0, x4							/* EL0 stack set */
#endif

//"================================================================"
//  Initilize MPID/MPIDR registers for all Cores
//"================================================================"
#ifndef EL1_BUILD
	mrs	x0, midr_el1
	mrs	x1, mpidr_el1
	msr	vpidr_el2, x0
	msr	vmpidr_el2, x1
#endif

//"================================================================"
//  Initialize Generic Timers for Core0
//"================================================================"
#ifndef EL1_BUILD
	mrs	x0, cnthctl_el2
	orr	x0, x0, #0x3						/* Enable EL1 access to timers */
	msr	cnthctl_el2, x0
	msr	cntvoff_el2, xzr
#endif	

//"================================================================"
//  Disable coprocessor traps for all Cores
//"================================================================"
.if (__ARM_FP == 14)		//# If hard float compiling selected
#ifndef EL1_BUILD
	mov	x0, #0x33ff
	msr	cptr_el2, x0						// Disable coprocessor traps to EL2
	msr	hstr_el2, xzr						// Disable coprocessor traps to EL2
#endif
	mov	x0, #3 << 20
	msr	cpacr_el1, x0						// Enable FP/SIMD at EL1
.endif						//# __ARM_FP == 14 hard float on for compiling

#ifndef EL1_BUILD
//"================================================================"
//  Initialize HCR_EL2 so EL1 is 64 bits for all Cores
//"================================================================"
	mov	x0, #(1 << 31)						// 64bit EL1
	msr	hcr_el2, x0
#endif

//"================================================================"
//  Initialize SCTLR_EL1 for all Cores
//"================================================================"
    /*  RES1 bits (29,28,23,22,20,11) to 1
	 *  RES0 bits (31,30,27,21,17,13,10,6) +
	 *  UCI,EE,EOE,WXN,nTWE,nTWI,UCT,DZE,I,UMA,SED,ITD,
	 *  CP15BEN,SA0,SA,C,A,M to 0 */
	mov	x0, #0x0800
	movk	x0, #0x30d0, lsl #16
	orr    x0, x0, #(0x1 << 2)            // The C bit on (data cache). 
	orr    x0, x0, #(0x1 << 12)           // The I bit on (instruction cache)
	msr	sctlr_el1, x0

#ifndef EL1_BUILD
//"================================================================"
//  Return to the EL1_SP1 mode from EL2 for all Cores
//"================================================================"
	mov	x0, #0x3c5							// EL1_SP1 | D | A | I | F
	msr	spsr_el2, x0						// Set spsr_el2 with settings
	adr	x0, exit_el1						// Address to exit EL2
	msr	elr_el2, x0							// Set elevated return register
	eret									// Call elevated return
exit_el1:
#endif

//"================================================================"
//  Set vector table for EL1 for Cores (Yep all use same vectors)
//"================================================================"
    ldr x0, =VectorTable						
    msr vbar_el1,x0

	mrs x6, mpidr_el1						// Read core id on ARM8
	and x6, x6, #0x3						// Make cpu id bitmask
	cbz x6, cpu0_exit_multicore_park		// Core0 continues on

//"================================================================"
//      Now park Core 1,2,3 into secondary spinloop on BCM2837
//"================================================================"
	ldr x1, =RPi_CoresReady					// Address of CoreReady count
	ldr w0, [x1]							// Load current core count 
	add w0, w0, #1							// Add one as core about to go ready
	str w0, [x1]							// Update CoreReady count
	b  StartSecondarySpin					// Jump to setup secondary spin
cpu0_exit_multicore_park:

//"================================================================"
//  About to go to into C kernel clear BSS (Core0 only)
//"================================================================"
	ldr x3, =__bss_end__
	ldr x0, =__bss_start__
	cmp	x0, x3
	bcs	.bss_cleared
.bss_zero_loop:
	str	wzr, [x0], 4
	cmp	x3, x0
	bhi	.bss_zero_loop
.bss_cleared:

#ifndef EL1_BUILD
//"================================================================"
//			Core0 will bring Core 1,2,3 to secondary spin 
//"================================================================"
.equ spin_cpu1, 0xe0
	mov x1, #spin_cpu1						// Spin core1 jump address
	ldr x2, =multicore_start				// Function we are going to call
	str	x2, [x1]							// Store the function address to core1
	sev										// Wake core1 up
 	ldr x3, =RPi_CoresReady					// Set CoresReady count address
.WaitCore1ACK:
	ldr	w1, [x3]							// Read CoresReady count
	cmp	w1, #2								// Wait for setting of second core ready
	bne	.WaitCore1ACK						// Core1 not ready so read again
.equ spin_cpu2, 0xe8
	mov x1, #spin_cpu2						// Spin core2 jump address
	ldr x2, =multicore_start				// Function we are going to call
	str	x2, [x1]							// Store the function address to core2
	sev										// Wake core2 up
 	ldr x3, =RPi_CoresReady					// Set CoresReady count address
.WaitCore2ACK:
	ldr	w1, [x3]							// Read CoresReady count
	cmp	w1, #3								// Wait for setting of third core ready
	bne	.WaitCore2ACK						// Core2 not ready so read again
.equ spin_cpu3, 0xf0
	mov x1, #spin_cpu3						// Spin core3 jump address
	ldr x2, =multicore_start				// Function we are going to call
	str	x2, [x1]							// Store the function address to core3
	sev										// Wake core3 up
 	ldr x3, =RPi_CoresReady					// Set CoresReady count address
.WaitCore3ACK:
	ldr	w1, [x3]							// Read CoresReady count
	cmp	w1, #4								// Wait for setting of third core ready
	bne	.WaitCore3ACK						// Core3 not ready so read again
#endif

//"================================================================"
// Finally that all done Core0 jumps to the C compiler entry point
//"================================================================"
	b main									// Jump out to C kernel 

/*================================================================"
      Just safety incase C code ever returns back
"================================================================*/
hang:
	b hang

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{    Modified bootloader Spin loop but tolerant on registers X0-X7 for C    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
.balign	8
StartSecondarySpin:
	wfe										// This is all I really want processor to sleep
	mov	x2, 204
	movk x2, 0x4000, lsl 16					// Load mailbox0 read address = 0x400000CC
	mrs x0, MPIDR_EL1						// Fetch core Id
	ubfiz x0, x0, 4, 4						// Multiply core ID x 16
	ldr	w1, [x0, x2]						// Read the mailbox	
	cbz w1, StartSecondarySpin				// If zero spin again
	str	w1, [x0, x2]						// Clear the read address
	uxtw x1, w1								// Expand 32bit addr to 64bit addr
	dmb sy
	blr x1									// Call the function set
	dmb sy
	b StartSecondarySpin					// Loop back to spinlock
.balign	8
.ltorg										/* Tell assembler ltorg data for code above can go here */

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{							Save Context MACRO								}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
.macro portSAVE_CONTEXT
	/* Save the entire context. */
	STP 	X0, X1, [SP, #-0x10]!
	STP 	X2, X3, [SP, #-0x10]!
	STP 	X4, X5, [SP, #-0x10]!
	STP 	X6, X7, [SP, #-0x10]!
	STP 	X8, X9, [SP, #-0x10]!
	STP 	X10, X11, [SP, #-0x10]!
	STP 	X12, X13, [SP, #-0x10]!
	STP 	X14, X15, [SP, #-0x10]!
	STP 	X16, X17, [SP, #-0x10]!
	STP 	X18, X19, [SP, #-0x10]!
	STP 	X20, X21, [SP, #-0x10]!
	STP 	X22, X23, [SP, #-0x10]!
	STP 	X24, X25, [SP, #-0x10]!
	STP 	X26, X27, [SP, #-0x10]!
	STP 	X28, X29, [SP, #-0x10]!
	STP 	X30, XZR, [SP, #-0x10]!

	/* Save the SPSR. */
	MRS		X3, SPSR_EL1
	MRS		X2, ELR_EL1
	STP 	X2, X3, [SP, #-0x10]!

	/* Save the critical section nesting depth. */
	LDR		X0, =ulCriticalNesting
	LDR		X3, [X0]
	//ADD		X2, X3, #1
	//STR		X2, [X0]

	/* Save the FPU context indicator. */
	LDR		X0, =ulTaskHasFPUContext
	LDR		X2, [X0]

	/* Save the FPU context, if any (32 128-bit registers). */
	CMP		X2, #0
	B.EQ	1f
	STP		Q0, Q1, [SP,#-0x20]!
	STP		Q2, Q3, [SP,#-0x20]!
	STP		Q4, Q5, [SP,#-0x20]!
	STP		Q6, Q7, [SP,#-0x20]!
	STP		Q8, Q9, [SP,#-0x20]!
	STP		Q10, Q11, [SP,#-0x20]!
	STP		Q12, Q13, [SP,#-0x20]!
	STP		Q14, Q15, [SP,#-0x20]!
	STP		Q16, Q17, [SP,#-0x20]!
	STP		Q18, Q19, [SP,#-0x20]!
	STP		Q20, Q21, [SP,#-0x20]!
	STP		Q22, Q23, [SP,#-0x20]!
	STP		Q24, Q25, [SP,#-0x20]!
	STP		Q26, Q27, [SP,#-0x20]!
	STP		Q28, Q29, [SP,#-0x20]!
	STP		Q30, Q31, [SP,#-0x20]!

1:
	/* Store the critical nesting count and FPU context indicator. */
	STP 	X2, X3, [SP, #-0x10]!

	LDR 	X0, =pxCurrentTCB
	LDR 	X1, [X0]
	MOV 	X0, SP   /* Move SP into X0 for saving. */
	STR 	X0, [X1]
.endm

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{							restore Context MACRO							}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
.macro portRESTORE_CONTEXT

	/* Set the SP to point to the stack of the task being restored. */
	LDR		X0, =pxCurrentTCB
	LDR		X1, [X0]
	LDR		X0, [X1]
	MOV		SP, X0

	LDP 	X2, X3, [SP], #0x10  /* Critical nesting and FPU context. */

	/* Set the PMR register to be correct for the current critical nesting	depth. */
	LDR		X0, =ulCriticalNesting /* X0 holds the address of ullCriticalNesting. */
	STR		X3, [X0]					/* Restore the task critical nesting count. */

	/* Restore the FPU context indicator. */
	LDR		X0, =ulTaskHasFPUContext
	STR		X2, [X0]

	/* Restore the FPU context, if any. */
	CMP		X2, #0
	B.EQ	1f
	LDP		Q30, Q31, [SP], #0x20
	LDP		Q28, Q29, [SP], #0x20
	LDP		Q26, Q27, [SP], #0x20
	LDP		Q24, Q25, [SP], #0x20
	LDP		Q22, Q23, [SP], #0x20
	LDP		Q20, Q21, [SP], #0x20
	LDP		Q18, Q19, [SP], #0x20
	LDP		Q16, Q17, [SP], #0x20
	LDP		Q14, Q15, [SP], #0x20
	LDP		Q12, Q13, [SP], #0x20
	LDP		Q10, Q11, [SP], #0x20
	LDP		Q8, Q9, [SP], #0x20
	LDP		Q6, Q7, [SP], #0x20
	LDP		Q4, Q5, [SP], #0x20
	LDP		Q2, Q3, [SP], #0x20
	LDP		Q0, Q1, [SP], #0x20
1:
	LDP 	X2, X3, [SP], #0x10  /* SPSR and ELR. */

	/* Restore the SPSR. */
	MSR		SPSR_EL1, X3
	/* Restore the ELR. */
	MSR		ELR_EL1, X2

	LDP 	X30, XZR, [SP], #0x10
	LDP 	X28, X29, [SP], #0x10
	LDP 	X26, X27, [SP], #0x10
	LDP 	X24, X25, [SP], #0x10
	LDP 	X22, X23, [SP], #0x10
	LDP 	X20, X21, [SP], #0x10
	LDP 	X18, X19, [SP], #0x10
	LDP 	X16, X17, [SP], #0x10
	LDP 	X14, X15, [SP], #0x10
	LDP 	X12, X13, [SP], #0x10
	LDP 	X10, X11, [SP], #0x10
	LDP 	X8, X9, [SP], #0x10
	LDP 	X6, X7, [SP], #0x10
	LDP 	X4, X5, [SP], #0x10
	LDP 	X2, X3, [SP], #0x10
	LDP 	X0, X1, [SP], #0x10

	ERET
.endm

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{ DEFAULT IRQ HANDLERS STUB ON WEAK REFERENCE PROVIDE BY RPi-SmartStart API	}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
.weak swi_handler_stub
swi_handler_stub:
	
	portSAVE_CONTEXT

	MOV X1, SP
    AND X1, X1, #0xF									// Ensure 16-byte stack alignment
    SUB SP, SP, X1										// adjust stack as necessary
    STP	X1, XZR, [SP, #-16]!							// Store adjustment 

	BL 	vTaskSwitchContext

	LDP	X1, XZR,  [SP], #16								// Reload adjustment
    ADD SP, SP, X1										// Un-adjust stack

	/* restore context which includes a return from interrupt */
	portRESTORE_CONTEXT

	/* code should never reach this deadloop */
	B		.

.weak irq_handler_stub
irq_handler_stub:
	/* Save the context of the current task and select a new task to run. */
	portSAVE_CONTEXT


	MOV X1, SP
    AND X1, X1, #0xF									// Ensure 16-byte stack alignment
    SUB SP, SP, X1										// adjust stack as necessary
    STP	X1, XZR, [SP, #-16]!							// Store adjustment

	BL irqHandler										// Call irqhandler

	LDP	X1, XZR,  [SP], #16								// Reload adjustment
    ADD SP, SP, X1										// Un-adjust stack

	/* restore context which includes a return from interrupt */
	portRESTORE_CONTEXT

	/* code should never reach this deadloop */
	B		.


/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{  DEFAULT FIQ HANDLER STUB ON WEAK REFERENCE PROVIDE BY RPi-SmartStart API	}
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* Non re-entrant fiq interrupt handler stub */
/* http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.den0024a/ch10s05.html */
/* We assume interrupt code has no FPU use, if it does user must save FPU registers  */
/* So we will need to save registers x0-x7, x8-x15, x16-x18, x29, x30, 				 */
.weak fiq_handler_stub
fiq_handler_stub:	
	stp	x29, x30, [sp, #-16]!							// Store frame pointer and Link register
	stp	x18, x19,  [sp, #-16]!							// Save register x18, as C will trash it.. 19 just there as a pair
	stp	x16, x17,  [sp, #-16]!							// Save register x16, x17 as C will trash them
	stp	x14, x15,  [sp, #-16]!							// Save register x14, x15 as C will trash them
	stp	x12, x13,  [sp, #-16]!							// Save register x12, x13 as C will trash them
	stp	x10, x11,  [sp, #-16]!							// Save register x10, x11 as C will trash them
	stp	x8, x9,  [sp, #-16]!							// Save register x8, x9 as C will trash them
	stp	x6, x7,  [sp, #-16]!							// Save register x6, x7 as C will trash them
	stp	x4, x5,  [sp, #-16]!							// Save register x4, x5 as C will trash them
	stp	x2, x3,  [sp, #-16]!							// Save register x2, x3 as C will trash them
	stp	x0, x1,  [sp, #-16]!							// Save register x0, x1 as C will trash them

	mov x1, sp
    and x1, x1, #0xF									// Ensure 16-byte stack alignment
    sub sp, sp, x1										// adjust stack as necessary
    stp	x1, xzr, [sp, #-16]!							// Store adjustment

	ldr x0, =RPi_FiqFuncAddr							// Address to FiqFuncAddr
	ldr x0, [x0]										// Load FiqFuncAddr value
	cbz x0, no_fiqset									// If zero no fiq function set so ignore 
	blr x0												// Call Irqhandler that has been set
no_fiqset:

	ldp	x1, xzr,  [sp], #16								// Reload adjustment
    add sp, sp, x1										// Un-adjust stack

	ldp	x0, x1,  [sp], #16								// Restore register x0, x1
	ldp	x2, x3,  [sp], #16								// Restore register x2, x3
	ldp	x4, x5,  [sp], #16								// Restore register x4, x5
	ldp	x6, x7,  [sp], #16								// Restore register x6, x7
	ldp	x8, x9,  [sp], #16								// Restore register x8, x9
	ldp	x10, x11,  [sp], #16							// Restore register x10, x11
	ldp	x12, x13,  [sp], #16							// Restore register x12, x13
	ldp	x14, x15,  [sp], #16							// Restore register x14, x15
	ldp	x16, x17,  [sp], #16							// Restore register x16, x17
	ldp	x18, x19,  [sp], #16							// Restore register x18, x19 
    ldp x29, x30, [sp], #16								// Restore frame pointer and Link register
	eret

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{				  VECTOR TABLE IN USE BY RPi-SmartStart API					}	
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/* macro to align handlers every 0x80 bytes */
.macro	vector handler
.balign 0x80
b	\handler
.endm


.balign 0x800
.globl	VectorTable
VectorTable:
	/* from current EL with sp_el0 */
	vector	hang			/* Synchronous */
	vector  hang			/* IRQ */
	vector	hang			/* FIQ */
	vector	hang			/* SErrorStub */

	/* from current EL with sp_elx, x != 0 */
	vector	swi_handler_stub /* Synchronous */
	vector	irq_handler_stub /* IRQ */
	vector	fiq_handler_stub /* FIQ */
	vector	hang			 /* SErrorStub */

	/* from lower EL, target EL minus 1 is AArch64 */
	vector	hang			/* Synchronous */
	vector  hang			/* IRQ */
	vector	hang			/* FIQ */
	vector	hang			/* SErrorStub */

	/* from lower EL, target EL minus 1 is AArch32 */
	vector	hang			/* Synchronous */
	vector  hang			/* IRQ */
	vector	hang			/* FIQ */
	vector	hang			/* SErrorStub */

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			GLOBAL INTERRUPT CONTROL PROVIDE BY RPi-SmartStart API		    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: void EnableInterrupts (void);" */
.section .text.EnableInterrupts, "ax", %progbits
.balign	8
.globl EnableInterrupts
.type EnableInterrupts, %function
EnableInterrupts:
	msr daifclr,#2
	ret
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	EnableInterrupts, .-EnableInterrupts

/* "PROVIDE C FUNCTION: void DisableInterrupts (void);" */
.section .text.DisableInterrupts, "ax", %progbits
.balign	8
.globl DisableInterrupts
.type DisableInterrupts, %function
DisableInterrupts:
	msr daifset,#2
	ret
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	DisableInterrupts, .-DisableInterrupts

/* "PROVIDE C FUNCTION: void EnableFIQ (void);" */
.section .text.EnableFIQ, "ax", %progbits
.balign	8
.globl EnableFIQ
.type EnableFIQ, %function
EnableFIQ:
	msr daifclr, #1
	ret
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	EnableFIQ, .-EnableFIQ

/* "PROVIDE C FUNCTION: void DisableFIQ (void);" */
.section .text.DisableFIQ, "ax", %progbits
.balign	8
.globl DisableFIQ
.type DisableFIQ, %function
DisableFIQ:
	msr daifset, #1
	ret
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	DisableFIQ, .-DisableFIQ

/* "PROVIDE C FUNCTION: unsigned long getDAIF (void);" */
.section .text.getDAIF, "ax", %progbits
.balign	8
.globl getDAIF
.type getDAIF, %function
getDAIF:
	mrs x0, daif
	ret
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	getDAIF, .-getDAIF

/* "PROVIDE C FUNCTION: void setDAIF (unsigned long flags);" */
.section .text.setDAIF, "ax", %progbits
.balign	8
.globl setDAIF
.type setDAIF, %function
setDAIF:
	msr daif, x0
	ret
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	setDAIF, .-setDAIF

//"+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
//				RPi-SmartStart API TO MULTICORE FUNCTIONS
//"+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

/* "PROVIDE C FUNCTION: uint8_t getCoreID (void);" */
.section .text.getCoreID, "ax", %progbits
.balign	8
.globl getCoreID		
.type getCoreID, %function
getCoreID:
	mrs x0, MPIDR_EL1
	and x0, x0, #3
	ret	
.balign	8
.ltorg
.size	getCoreID, .-getCoreID

/* "PROVIDE C FUNCTION: bool CoreExecute (uint8_t core, void (*func)(void));" */
.section .text.CoreExecute, "ax", %progbits
.balign	8
.globl CoreExecute;
.type CoreExecute, %function
CoreExecute:
    dmb sy
	adrp x2, RPi_CoresReady
	ldr	w2, [x2, #:lo12:RPi_CoresReady]
	and	w0, w0, 255
	cmp	w0, w2
	bcs CoreExecuteFail
	ubfiz x0, x0, 2, 8						// multiply core number x16
	mov	x2, 140
	movk x2, 0x4000, lsl 16					// Load address of mailbox0 write addr = 0x4000008C
	str	w1, [x2, x0, lsl 2]					// Save caller address
	sev
	dmb sy
 	mov	w0, 1
	ret
CoreExecuteFail:
	dmb sy
	mov x0, #0
	ret
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	CoreExecute, .-CoreExecute


//"+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
//	  RPi-SmartStart Compatability for David Welch CALLS he always uses	    }
//"+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

/* "PROVIDE C FUNCTION: void PUT32 (uint32_t addr, uint32_t value);" */
.section .text.PUT32, "ax", %progbits
.balign	8
.globl PUT32
.type PUT32, %function
PUT32:
	str w1,[x0]								// Half word write of value the address
	ret										// Return
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	PUT32, .-PUT32

/* "PROVIDE C FUNCTION: uint32_t GET32 (uint32_t addr);" */
 .section .text.GET32, "ax", %progbits
.balign	8
.globl GET32
.type GET32, %function
GET32:
	uxtw x1, w0								// Expand 32bit addr to 64bit addr
    ldr w0,[x1]								// Now read the address
	ret										// Return
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	GET32, .-GET32

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			VC4 ADDRESS HELPER ROUTINES PROVIDE BY RPi-SmartStart API	    }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: uint32_t ARMaddrToGPUaddr (void* ARMaddress);" */
.section .text.ARMaddrToGPUaddr, "ax", %progbits
.balign	8
.globl ARMaddrToGPUaddr;		
.type ARMaddrToGPUaddr, %function
ARMaddrToGPUaddr:
	mov x1, #0xC0000000						// ARM to VC conversion value
	orr x0, x0, x1							// Create bus address
	ret										// Return
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	ARMaddrToGPUaddr, .-ARMaddrToGPUaddr


/* "PROVIDE C FUNCTION: uint32_t GPUaddrToARMaddr (uint32_t BUSaddress);" */
.section .text.GPUaddrToARMaddr, "ax", %progbits
.balign	8
.globl GPUaddrToARMaddr;		
.type GPUaddrToARMaddr, %function
GPUaddrToARMaddr:
	mov x1, ~0xC0000000						// ARM to VC conversion value	
	and x0, x0, x1							// Create arm address
	ret										// Return
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	GPUaddrToARMaddr, .-GPUaddrToARMaddr

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{			FIQ HELPER ROUTINES PROVIDE BY RPi-SmartStart API		        }
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

/* "PROVIDE C FUNCTION: uintptr_t setFiqFuncAddress (void (*ARMaddress)(void));" */
.section .text.setFiqFuncAddress, "ax", %progbits
.balign	8
.globl setFiqFuncAddress;
.type setFiqFuncAddress, %function
setFiqFuncAddress:
	msr daifset,#1							// Disable fiq interrupts as we are clearly changing call
	ldr x1, =RPi_FiqFuncAddr				// Load address of function to call on interrupt 
	ldr x2, [x1]							// Load current fiq call address
	str x0, [x1]							// Store the new function pointer address we were given
	mov x0, x2								// return the old call function
	ret										// Return
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	setFiqFuncAddress, .-setFiqFuncAddress


.section .text.getSP, "ax", %progbits
.balign	8
.globl getSP;
.type getSP, %function
getSP:
	mov x0, sp
	ret										// Return
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	.getSP, .-getSP

.section .text.restore_context, "ax", %progbits
.balign	8
.globl restore_context;
.type restore_context, %function
restore_context:
	/* Start the first task. */
	portRESTORE_CONTEXT
.balign	8
.ltorg										// Tell assembler ltorg data for this code can go here
.size	.restore_context, .-restore_context


/****************************************************************
       	   DATA FOR SMARTSTART64  NOT EXPOSED TO INTERFACE 
****************************************************************/
.section ".data.notexposed_smartstart64", "aw"
.balign 8

RPi_FiqFuncAddr : .8byte 0;				// Fiq Function Address

/****************************************************************
       	   DATA FOR SMARTSTART64  EXPOSED TO INTERFACE 
****************************************************************/
.section ".data.smartstart64", "aw"
.balign 8

.globl RPi_IO_Base_Addr;				// Make sure Pi_IO_Base_Addr label is global
RPi_IO_Base_Addr : .4byte 0;			// Peripheral Base addr is 4 byte variable in 64bit mode

.globl RPi_ARM_TO_GPU_Alias;			// Make sure RPi_ARM_TO_GPU_Alias label is global
RPi_ARM_TO_GPU_Alias: .4byte 0;			// ARM to GPU alias is 4 byte variable in 32bit mode

.globl RPi_BootAddr;					// Make sure RPi_BootAddr label is global
RPi_BootAddr : .4byte 0;				// CPU boot address is 4 byte variable in 64bit mode

.globl RPi_CoresReady;					// Make sure RPi_CoresReady label is global
RPi_CoresReady : .4byte 0;				// CPU cores ready for use is 4 byte variable in 32bit mode

.globl RPi_CPUBootMode;					// Make sure RPi_CPUBootMode label is global
RPi_CPUBootMode : .4byte 0;				// CPU Boot Mode is 4 byte variable in 64bit mode

.globl RPi_CpuId;						// Make sure RPi_CpuId label is global
RPi_CpuId : .4byte 0;					// CPU Id is 4 byte variable in 64bit mode

.globl RPi_CompileMode;					// Make sure RPi_CompileMode label is global
RPi_CompileMode : .4byte 0;				// Compile mode is 4 byte variable in 64bit mode

.globl RPi_SmartStartVer;				// Make sure RPi_SmartStartVer label is global
RPi_SmartStartVer : .4byte 0x00021002;  // SmartStart version is 4 byte variable in 32bit mode