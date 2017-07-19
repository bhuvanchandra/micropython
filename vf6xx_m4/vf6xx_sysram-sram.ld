/*
    GNU linker script for NXP VF6XX Cortex-M4 core
*/

/* Entry Point */
ENTRY(Reset_Handler)

STACK_SIZE = 0x400;
HEAP_SIZE = 0x200;

MEMORY
{
	/*
	 * Note: 0x1f000000 is an alias for code bus to the same memory
	 * located at 0x3f000000, hence start with the data section
	 * at an offset of 256KiB. One can define this section lenghts
	 * freely
	 */
	pc_ram (rwx) : ORIGIN = 0x1f000000, LENGTH = 256K
	ps_ram (rwx) : ORIGIN = 0x3f040000, LENGTH = 256K
}

/* top end of the stack */
_estack = ORIGIN(ps_ram) + LENGTH(ps_ram);

/* ps_ram extents for the garbage collector */
_ram_end = ORIGIN(ps_ram) + LENGTH(ps_ram);
_heap_end = 0x2023c000; /* tunable */

/* define output sections */
SECTIONS
{
    /* The program code and other data goes into pc_ram */
    .text :
    {
        . = ALIGN(4);
        KEEP(*(.isr_vector)) /* isr vector table */
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */

        . = ALIGN(4);
        _etext = .;        /* define a global symbol at end of code */
        _sidata = _etext;  /* This is used by the startup in order to initialize the .data secion */
    } >pc_ram

    /* This is the initialized data section
    The program executes knowing that the data is in the ps_ram
    but the loader puts the initial values in the pc_ram (inidata).
    It is one task of the startup to copy the initial values from pc_ram to ps_ram. */
    .data : AT ( _sidata )
    {
        . = ALIGN(4);
        _sdata = .;        /* create a global symbol at data start; used by startup code in order to initialise the .data section in ps_ram */
        *(.data)           /* .data sections */
        *(.data*)          /* .data* sections */

        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end; used by startup code in order to initialise the .data section in ps_ram */
    } >ps_ram

    /* Uninitialized data section */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;         /* define a global symbol at bss start; used by startup code */
        *(.bss)
        *(.bss*)
        *(COMMON)

        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end; used by startup code */
    } >ps_ram

    /* this is to define the start of the heap */
    .heap :
    {
        . = ALIGN(4);
	PROVIDE ( end = . );
	PROVIDE ( _end = . );
        _heap_start = .;    /* define a global symbol at heap start */
    } >ps_ram

    .ARM.attributes 0 : { *(.ARM.attributes) }
}
