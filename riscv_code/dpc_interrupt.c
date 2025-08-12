/*
 * DPC中断处理模块
 * 
 * 功能：
 * 1. 处理自动坏点检测中断
 * 2. 管理坏点数据接收
 * 3. 提供异步处理接口
 */

#include "dpc_config.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// 中断状态标志
static volatile uint8_t auto_bp_interrupt_flag = 0;
static volatile uint8_t frame_done_interrupt_flag = 0;
static volatile uint32_t auto_bp_buffer_head = 0;
static volatile uint32_t auto_bp_buffer_tail = 0;

// 自动坏点接收缓冲区
#define AUTO_BP_BUFFER_SIZE  512
static BadPixel_t auto_bp_buffer[AUTO_BP_BUFFER_SIZE];
static volatile uint32_t auto_bp_lost_count = 0;

// 中断统计
static volatile uint32_t total_interrupts = 0;
static volatile uint32_t bp_interrupts = 0;
static volatile uint32_t frame_done_interrupts = 0;

// 中断向量定义 (根据实际硬件平台调整)
#define DPC_AUTO_BP_IRQ_NUM     16      // 自动坏点中断号
#define DPC_FRAME_DONE_IRQ_NUM  17      // 帧完成中断号

// 中断控制寄存器 (假设的中断控制器)
#define NVIC_BASE               0xe000e000
#define NVIC_ISER_OFFSET        0x100
#define NVIC_ICER_OFFSET        0x180
#define NVIC_ISPR_OFFSET        0x200
#define NVIC_ICPR_OFFSET        0x280

// 内联函数：使能中断
static inline void enable_irq(uint32_t irq_num) {
    uint32_t reg_offset = NVIC_ISER_OFFSET + (irq_num / 32) * 4;
    uint32_t bit_pos = irq_num % 32;
    write_reg32(NVIC_BASE + reg_offset, 1 << bit_pos);
}

// 内联函数：禁用中断
static inline void disable_irq(uint32_t irq_num) {
    uint32_t reg_offset = NVIC_ICER_OFFSET + (irq_num / 32) * 4;
    uint32_t bit_pos = irq_num % 32;
    write_reg32(NVIC_BASE + reg_offset, 1 << bit_pos);
}

// 内联函数：清除中断挂起
static inline void clear_pending_irq(uint32_t irq_num) {
    uint32_t reg_offset = NVIC_ICPR_OFFSET + (irq_num / 32) * 4;
    uint32_t bit_pos = irq_num % 32;
    write_reg32(NVIC_BASE + reg_offset, 1 << bit_pos);
}

// 环形缓冲区操作
static inline uint32_t buffer_next_index(uint32_t index) {
    return (index + 1) % AUTO_BP_BUFFER_SIZE;
}

static inline uint8_t buffer_is_full(void) {
    return (buffer_next_index(auto_bp_buffer_head) == auto_bp_buffer_tail);
}

static inline uint8_t buffer_is_empty(void) {
    return (auto_bp_buffer_head == auto_bp_buffer_tail);
}

static inline uint32_t buffer_count(void) {
    if (auto_bp_buffer_head >= auto_bp_buffer_tail) {
        return auto_bp_buffer_head - auto_bp_buffer_tail;
    } else {
        return AUTO_BP_BUFFER_SIZE - auto_bp_buffer_tail + auto_bp_buffer_head;
    }
}

// 自动坏点中断处理函数
void __attribute__((interrupt)) dpc_auto_bp_irq_handler(void) {
    total_interrupts++;
    bp_interrupts++;
    
    // 读取坏点数据
    uint32_t bp_data = read_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_DATA_OFFSET);
    
    // 检查数据有效性
    if (bp_data & AUTO_BP_VALID_MASK) {
        // 解析坐标和类型
        uint16_t x = (bp_data & AUTO_BP_X_MASK) >> 16;
        uint16_t y = bp_data & AUTO_BP_Y_MASK;
        uint8_t type = (bp_data & AUTO_BP_TYPE_MASK) ? BP_TYPE_STUCK : BP_TYPE_DEAD;
        
        // 坐标有效性检查
        if (x < FRAME_WIDTH && y < FRAME_HEIGHT) {
            // 存储到缓冲区
            if (!buffer_is_full()) {
                auto_bp_buffer[auto_bp_buffer_head].x = x;
                auto_bp_buffer[auto_bp_buffer_head].y = y;
                auto_bp_buffer[auto_bp_buffer_head].type = type;
                auto_bp_buffer[auto_bp_buffer_head].confidence = 255; // 满置信度
                
                auto_bp_buffer_head = buffer_next_index(auto_bp_buffer_head);
                
                DPC_VERBOSE("Auto BP detected: (%d, %d) type=%d", x, y, type);
            } else {
                // 缓冲区满，丢弃数据
                auto_bp_lost_count++;
                DPC_DEBUG("Auto BP buffer full, lost pixel at (%d, %d)", x, y);
            }
        }
    }
    
    // 发送准备信号
    write_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_READY_OFFSET, 1);
    
    // 设置中断标志
    auto_bp_interrupt_flag = 1;
    
    // 清除中断挂起
    clear_pending_irq(DPC_AUTO_BP_IRQ_NUM);
}

// 帧完成中断处理函数
void __attribute__((interrupt)) dpc_frame_done_irq_handler(void) {
    total_interrupts++;
    frame_done_interrupts++;
    
    // 设置帧完成标志
    frame_done_interrupt_flag = 1;
    
    // 复位准备信号
    write_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_READY_OFFSET, 0);
    
    DPC_DEBUG("Frame detection completed, buffer has %d bad pixels", buffer_count());
    
    // 清除中断挂起
    clear_pending_irq(DPC_FRAME_DONE_IRQ_NUM);
}

// 初始化DPC中断系统
int dpc_interrupt_init(void) {
    DPC_DEBUG("Initializing DPC interrupt system...");
    
    // 初始化缓冲区
    auto_bp_buffer_head = 0;
    auto_bp_buffer_tail = 0;
    auto_bp_lost_count = 0;
    
    // 清除中断标志
    auto_bp_interrupt_flag = 0;
    frame_done_interrupt_flag = 0;
    
    // 清除统计
    total_interrupts = 0;
    bp_interrupts = 0;
    frame_done_interrupts = 0;
    
    // 清除中断挂起状态
    clear_pending_irq(DPC_AUTO_BP_IRQ_NUM);
    clear_pending_irq(DPC_FRAME_DONE_IRQ_NUM);
    
    // 初始化GPIO准备信号
    write_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_READY_OFFSET, 0);
    
    DPC_DEBUG("DPC interrupt system initialized");
    return DPC_SUCCESS;
}

// 启用DPC中断
int dpc_interrupt_enable(void) {
    DPC_DEBUG("Enabling DPC interrupts...");
    
    // 启用自动坏点中断
    enable_irq(DPC_AUTO_BP_IRQ_NUM);
    
    // 启用帧完成中断
    enable_irq(DPC_FRAME_DONE_IRQ_NUM);
    
    DPC_DEBUG("DPC interrupts enabled");
    return DPC_SUCCESS;
}

// 禁用DPC中断
int dpc_interrupt_disable(void) {
    DPC_DEBUG("Disabling DPC interrupts...");
    
    // 禁用中断
    disable_irq(DPC_AUTO_BP_IRQ_NUM);
    disable_irq(DPC_FRAME_DONE_IRQ_NUM);
    
    DPC_DEBUG("DPC interrupts disabled");
    return DPC_SUCCESS;
}

// 清除中断标志
void dpc_clear_interrupt_flags(void) {
    auto_bp_interrupt_flag = 0;
    frame_done_interrupt_flag = 0;
}

// 检查自动坏点中断标志
uint8_t dpc_check_auto_bp_interrupt(void) {
    return auto_bp_interrupt_flag;
}

// 检查帧完成中断标志
uint8_t dpc_check_frame_done_interrupt(void) {
    return frame_done_interrupt_flag;
}

// 从缓冲区读取一个坏点
int dpc_read_auto_badpixel(BadPixel_t *bp) {
    if (buffer_is_empty()) {
        return DPC_ERROR_PARAM; // 缓冲区为空
    }
    
    // 临界区保护
    disable_irq(DPC_AUTO_BP_IRQ_NUM);
    
    *bp = auto_bp_buffer[auto_bp_buffer_tail];
    auto_bp_buffer_tail = buffer_next_index(auto_bp_buffer_tail);
    
    enable_irq(DPC_AUTO_BP_IRQ_NUM);
    
    return DPC_SUCCESS;
}

// 读取多个坏点到数组
int dpc_read_auto_badpixels(BadPixel_t *bp_array, uint32_t max_count, uint32_t *actual_count) {
    if (!bp_array || !actual_count) {
        return DPC_ERROR_PARAM;
    }
    
    *actual_count = 0;
    
    // 临界区保护
    disable_irq(DPC_AUTO_BP_IRQ_NUM);
    
    uint32_t available = buffer_count();
    uint32_t to_read = MIN(max_count, available);
    
    for (uint32_t i = 0; i < to_read; i++) {
        bp_array[i] = auto_bp_buffer[auto_bp_buffer_tail];
        auto_bp_buffer_tail = buffer_next_index(auto_bp_buffer_tail);
    }
    
    *actual_count = to_read;
    
    enable_irq(DPC_AUTO_BP_IRQ_NUM);
    
    DPC_VERBOSE("Read %d auto bad pixels from buffer", to_read);
    return DPC_SUCCESS;
}

// 获取缓冲区中的坏点数量
uint32_t dpc_get_buffer_count(void) {
    return buffer_count();
}

// 清空自动坏点缓冲区
void dpc_clear_auto_bp_buffer(void) {
    disable_irq(DPC_AUTO_BP_IRQ_NUM);
    
    auto_bp_buffer_head = 0;
    auto_bp_buffer_tail = 0;
    
    enable_irq(DPC_AUTO_BP_IRQ_NUM);
    
    DPC_DEBUG("Auto bad pixel buffer cleared");
}

// 获取丢失的坏点数量
uint32_t dpc_get_lost_bp_count(void) {
    return auto_bp_lost_count;
}

// 重置丢失计数
void dpc_reset_lost_bp_count(void) {
    auto_bp_lost_count = 0;
}

// 中断驱动的帧处理函数
int dpc_interrupt_driven_frame_process(BadPixel_t *manual_bp_list, uint32_t manual_count,
                                       BadPixel_t *merged_bp_list, uint32_t *merged_count,
                                       uint32_t max_merged_count) {
    if (!merged_bp_list || !merged_count) {
        return DPC_ERROR_PARAM;
    }
    
    DPC_DEBUG("Starting interrupt-driven frame processing...");
    
    // 清除缓冲区和中断标志
    dpc_clear_auto_bp_buffer();
    dpc_clear_interrupt_flags();
    
    // 启动自动检测
    int ret = dpc_detector_start();
    if (ret != DPC_SUCCESS) {
        return ret;
    }
    
    // 等待帧完成中断
    uint32_t timeout = FRAME_TIMEOUT_MS;
    while (timeout-- && !frame_done_interrupt_flag) {
        delay_ms(1);
    }
    
    if (!frame_done_interrupt_flag) {
        DPC_DEBUG("Frame processing timeout");
        return DPC_ERROR_TIMEOUT;
    }
    
    // 读取所有自动检测的坏点
    BadPixel_t auto_bp_list[MAX_AUTO_BP];
    uint32_t auto_count = 0;
    
    ret = dpc_read_auto_badpixels(auto_bp_list, MAX_AUTO_BP, &auto_count);
    if (ret != DPC_SUCCESS) {
        return ret;
    }
    
    DPC_DEBUG("Auto detection found %d bad pixels", auto_count);
    
    // 合并手动和自动坏点列表
    *merged_count = 0;
    
    // 添加手动坏点
    uint32_t manual_added = MIN(manual_count, max_merged_count);
    for (uint32_t i = 0; i < manual_added; i++) {
        merged_bp_list[*merged_count] = manual_bp_list[i];
        (*merged_count)++;
    }
    
    // 添加自动坏点，检查重复
    for (uint32_t i = 0; i < auto_count && *merged_count < max_merged_count; i++) {
        // 检查是否与手动坏点重复
        uint8_t is_duplicate = 0;
        for (uint32_t j = 0; j < manual_added; j++) {
            if (auto_bp_list[i].x == manual_bp_list[j].x && 
                auto_bp_list[i].y == manual_bp_list[j].y) {
                is_duplicate = 1;
                break;
            }
        }
        
        if (!is_duplicate) {
            merged_bp_list[*merged_count] = auto_bp_list[i];
            (*merged_count)++;
        }
    }
    
    // 排序合并后的坏点列表
    dpc_sort_badpixel_list(merged_bp_list, *merged_count);
    
    // 配置校正器
    ret = dpc_corrector_config_all_bp(merged_bp_list, *merged_count);
    if (ret != DPC_SUCCESS) {
        return ret;
    }
    
    // 启动校正器
    ret = dpc_corrector_start();
    if (ret != DPC_SUCCESS) {
        return ret;
    }
    
    DPC_DEBUG("Frame processing completed, merged %d bad pixels", *merged_count);
    
    // 清除中断标志
    dpc_clear_interrupt_flags();
    
    return DPC_SUCCESS;
}

// 获取中断统计信息
void dpc_get_interrupt_statistics(uint32_t *total, uint32_t *bp_int, uint32_t *frame_int, uint32_t *lost) {
    if (total) *total = total_interrupts;
    if (bp_int) *bp_int = bp_interrupts;
    if (frame_int) *frame_int = frame_done_interrupts;
    if (lost) *lost = auto_bp_lost_count;
}

// 打印中断统计信息
void dpc_print_interrupt_statistics(void) {
    printf("\n=== DPC Interrupt Statistics ===\n");
    printf("Total interrupts: %d\n", total_interrupts);
    printf("Bad pixel interrupts: %d\n", bp_interrupts);
    printf("Frame done interrupts: %d\n", frame_done_interrupts);
    printf("Buffer count: %d\n", buffer_count());
    printf("Lost bad pixels: %d\n", auto_bp_lost_count);
    printf("Buffer utilization: %.1f%%\n", 
           (float)buffer_count() * 100.0f / AUTO_BP_BUFFER_SIZE);
    printf("===============================\n\n");
}

// 测试中断系统
int dpc_test_interrupt_system(void) {
    DPC_DEBUG("Testing DPC interrupt system...");
    
    // 初始化中断系统
    int ret = dpc_interrupt_init();
    if (ret != DPC_SUCCESS) {
        return ret;
    }
    
    // 启用中断
    ret = dpc_interrupt_enable();
    if (ret != DPC_SUCCESS) {
        return ret;
    }
    
    // 模拟一些坏点检测（实际中这将由硬件产生）
    // 这里我们直接写GPIO寄存器来模拟
    for (int i = 0; i < 5; i++) {
        uint32_t test_data = COORD_TO_REG(100 + i, 200 + i) | AUTO_BP_VALID_MASK;
        write_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_DATA_OFFSET, test_data);
        
        // 触发中断（在实际硬件中，这将由硬件自动触发）
        // 这里我们手动调用中断处理函数进行测试
        dpc_auto_bp_irq_handler();
        
        delay_ms(10);
    }
    
    // 模拟帧完成
    dpc_frame_done_irq_handler();
    
    // 检查结果
    uint32_t buffer_count_result = buffer_count();
    if (buffer_count_result == 5) {
        DPC_DEBUG("Interrupt system test PASSED");
        
        // 读取并验证数据
        BadPixel_t test_bp;
        for (int i = 0; i < 5; i++) {
            ret = dpc_read_auto_badpixel(&test_bp);
            if (ret == DPC_SUCCESS) {
                DPC_VERBOSE("Read test BP: (%d, %d)", test_bp.x, test_bp.y);
            }
        }
        
        return DPC_SUCCESS;
    } else {
        DPC_DEBUG("Interrupt system test FAILED (expected 5, got %d)", buffer_count_result);
        return DPC_ERROR_HARDWARE;
    }
}
