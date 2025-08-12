/*
 * RISC-V链接器脚本 for DPC项目
 * 
 * 定义了内存布局和段分配
 * 适用于典型的嵌入式RISC-V系统
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

/* 内存映射定义 (根据实际硬件调整) */
MEMORY
{
    /* 指令存储器 - 通常是片上ROM或Flash */
    IMEM (rx) : ORIGIN = 0x80000000, LENGTH = 128K
    
    /* 数据存储器 - 通常是片上RAM */
    DMEM (rwx) : ORIGIN = 0x80020000, LENGTH = 64K
    
    /* 外设寄存器空间 */
    PERIPHERAL (rw) : ORIGIN = 0xe0000000, LENGTH = 256M
}

/* 栈大小定义 */
STACK_SIZE = 8K;
HEAP_SIZE = 16K;

/* 段定义 */
SECTIONS
{
    /* 启动代码段 - 放在IMEM开始处 */
    .text.start : ALIGN(4)
    {
        KEEP(*(.text.start))
        . = ALIGN(4);
    } > IMEM
    
    /* 代码段 */
    .text : ALIGN(4)
    {
        *(.text)
        *(.text.*)
        
        /* 保持中断向量表 */
        KEEP(*(.text.irq_handler))
        KEEP(*(.text.exception_handler))
        
        . = ALIGN(4);
        _etext = .;
    } > IMEM
    
    /* 只读数据段 */
    .rodata : ALIGN(4)
    {
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
        . = ALIGN(4);
        _erodata = .;
    } > IMEM
    
    /* 数据段初始化值 */
    .data : ALIGN(4)
    {
        _sdata = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > DMEM AT > IMEM
    
    /* 数据段加载地址 */
    _sidata = LOADADDR(.data);
    
    /* BSS段 (未初始化数据) */
    .bss : ALIGN(4)
    {
        _sbss = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > DMEM
    
    /* 堆内存 */
    .heap : ALIGN(4)
    {
        _sheap = .;
        . = . + HEAP_SIZE;
        _eheap = .;
    } > DMEM
    
    /* 栈内存 */
    .stack : ALIGN(4)
    {
        . = . + STACK_SIZE;
        _estack = .;
    } > DMEM
    
    /* 调试信息段 */
    .debug_info 0 : { *(.debug_info) }
    .debug_abbrev 0 : { *(.debug_abbrev) }
    .debug_line 0 : { *(.debug_line) }
    .debug_frame 0 : { *(.debug_frame) }
    .debug_str 0 : { *(.debug_str) }
    .debug_loc 0 : { *(.debug_loc) }
    .debug_macinfo 0 : { *(.debug_macinfo) }
    .debug_pubtypes 0 : { *(.debug_pubtypes) }
    .debug_ranges 0 : { *(.debug_ranges) }
    .debug_pubnames 0 : { *(.debug_pubnames) }
    .debug_aranges 0 : { *(.debug_aranges) }
    
    /* 丢弃不需要的段 */
    /DISCARD/ :
    {
        *(.note.GNU-stack)
        *(.gnu_debuglink)
        *(.gnu.lto_*)
        *(.discard)
        *(.discard.*)
    }
}

/* 符号定义 - 供C代码使用 */
_text_size = _etext - ORIGIN(IMEM);
_data_size = _edata - _sdata;
_bss_size = _ebss - _sbss;
_heap_start = _sheap;
_heap_end = _eheap;
_stack_top = _estack;

/* 内存使用统计 */
_imem_used = _erodata - ORIGIN(IMEM);
_dmem_used = _estack - ORIGIN(DMEM);
_imem_free = LENGTH(IMEM) - _imem_used;
_dmem_free = LENGTH(DMEM) - _dmem_used;

/* 内存溢出检查 */
ASSERT(_imem_used <= LENGTH(IMEM), "指令存储器溢出!")
ASSERT(_dmem_used <= LENGTH(DMEM), "数据存储器溢出!")
ASSERT(_estack <= (ORIGIN(DMEM) + LENGTH(DMEM)), "栈空间溢出!")
ASSERT(_eheap <= _estack - STACK_SIZE, "堆栈冲突!")

/* 提供给C代码的内存信息 */
PROVIDE(__text_start = ORIGIN(IMEM));
PROVIDE(__text_end = _etext);
PROVIDE(__data_start = _sdata);
PROVIDE(__data_end = _edata);
PROVIDE(__bss_start = _sbss);
PROVIDE(__bss_end = _ebss);
PROVIDE(__heap_start = _sheap);
PROVIDE(__heap_end = _eheap);
PROVIDE(__stack_top = _estack);

/* DPC外设基地址提供给C代码 */
PROVIDE(__dpc_detector_base = 0xe1008000);
PROVIDE(__dpc_corrector_base = 0xe100c000);
PROVIDE(__auto_bp_gpio_base = 0x60001000);
