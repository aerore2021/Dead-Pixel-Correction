/*
 * DPC分离架构示例应用程序
 * 
 * 展示如何使用分离的DPC检测器和校正器进行图像处理
 * 包含轮询模式和中断模式两种工作方式
 */

#include "dpc_config.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// 外部函数声明
extern int dpc_interrupt_init(void);
extern int dpc_interrupt_enable(void);
extern int dpc_interrupt_disable(void);
extern int dpc_interrupt_driven_frame_process(BadPixel_t *manual_bp_list, uint32_t manual_count,
                                             BadPixel_t *merged_bp_list, uint32_t *merged_count,
                                             uint32_t max_merged_count);
extern void dpc_print_interrupt_statistics(void);
extern int dpc_test_interrupt_system(void);

// 全局坏点列表
static BadPixel_t g_manual_bp_list[MAX_MANUAL_BP];
static BadPixel_t g_auto_bp_list[MAX_AUTO_BP];
static BadPixel_t g_merged_bp_list[MAX_ALL_BP];
static uint32_t g_manual_bp_count = 0;
static uint32_t g_auto_bp_count = 0;
static uint32_t g_merged_bp_count = 0;

// 系统配置和状态
static DpcConfig_t g_dpc_config;
static DpcSystemStatus_t g_system_status;

// 工作模式
typedef enum {
    DPC_MODE_POLLING = 0,       // 轮询模式
    DPC_MODE_INTERRUPT = 1      // 中断模式
} DpcWorkMode_t;

static DpcWorkMode_t g_work_mode = DPC_MODE_POLLING;

// ====== 基础访问函数实现 ======
static inline void write_reg32(uint32_t addr, uint32_t value) {
    *(volatile uint32_t*)addr = value;
}

static inline uint32_t read_reg32(uint32_t addr) {
    return *(volatile uint32_t*)addr;
}

static inline void delay_ms(uint32_t ms) {
    // 简化的延时实现
    for(volatile uint32_t i = 0; i < ms * 1000; i++);
}

// ====== 系统控制函数实现 ======
int dpc_system_init(void) {
    printf("=== DPC System Initialization ===\n");
    
    // 初始化配置
    g_dpc_config.k_threshold = K_THRESHOLD_DEFAULT;
    g_dpc_config.auto_detect_enable = 1;
    g_dpc_config.manual_correct_enable = 1;
    g_dpc_config.frame_sync_mode = 1;
    g_dpc_config.debug_output_enable = 1;
    
    // 初始化状态
    memset(&g_system_status, 0, sizeof(g_system_status));
    
    // 复位硬件模块
    write_reg32(DPC_DETECTOR_BASE + DET_REG_GO, 0);
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_GO, 0);
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_TABLE_RDY, 0);
    delay_ms(RESET_DELAY_MS);
    
    // 设置默认参数
    write_reg32(DPC_DETECTOR_BASE + DET_REG_K_THRESHOLD, g_dpc_config.k_threshold);
    
    // 清空坏点列表
    g_manual_bp_count = 0;
    g_auto_bp_count = 0;
    g_merged_bp_count = 0;
    
    // 初始化中断系统
    if (dpc_interrupt_init() != DPC_SUCCESS) {
        printf("Warning: Interrupt system initialization failed\n");
    }
    
    printf("DPC System initialized successfully\n");
    printf("  Frame size: %dx%d\n", FRAME_WIDTH, FRAME_HEIGHT);
    printf("  Pixel depth: %d bits\n", PIXEL_DEPTH);
    printf("  K threshold: %d\n", g_dpc_config.k_threshold);
    printf("  Max bad pixels: Manual=%d, Auto=%d, Total=%d\n", 
           MAX_MANUAL_BP, MAX_AUTO_BP, MAX_ALL_BP);
    printf("==================================\n\n");
    
    return DPC_SUCCESS;
}

int dpc_system_config(const DpcConfig_t *config) {
    if (!config) {
        return DPC_ERROR_PARAM;
    }
    
    printf("Updating DPC system configuration...\n");
    
    // 更新配置
    g_dpc_config = *config;
    
    // 应用K值阈值
    write_reg32(DPC_DETECTOR_BASE + DET_REG_K_THRESHOLD, config->k_threshold);
    
    printf("Configuration updated:\n");
    printf("  K threshold: %d\n", config->k_threshold);
    printf("  Auto detect: %s\n", config->auto_detect_enable ? "Enabled" : "Disabled");
    printf("  Manual correct: %s\n", config->manual_correct_enable ? "Enabled" : "Disabled");
    printf("  Debug output: %s\n", config->debug_output_enable ? "Enabled" : "Disabled");
    
    return DPC_SUCCESS;
}

DpcSystemStatus_t* dpc_get_system_status(void) {
    // 更新状态信息
    g_system_status.manual_bp_count = g_manual_bp_count;
    g_system_status.total_bp_count = g_merged_bp_count;
    
    // 统计自动检测的坏点类型
    g_system_status.auto_dead_count = 0;
    g_system_status.auto_stuck_count = 0;
    for (uint32_t i = 0; i < g_auto_bp_count; i++) {
        if (g_auto_bp_list[i].type == BP_TYPE_DEAD) {
            g_system_status.auto_dead_count++;
        } else if (g_auto_bp_list[i].type == BP_TYPE_STUCK) {
            g_system_status.auto_stuck_count++;
        }
    }
    
    // 读取硬件状态
    uint32_t det_status = read_reg32(DPC_DETECTOR_BASE + DET_REG_STATUS);
    uint32_t corr_status = read_reg32(DPC_CORRECTOR_BASE + CORR_REG_STATUS);
    
    g_system_status.detector_enabled = (det_status & DET_STATUS_BUSY) ? 1 : 0;
    g_system_status.corrector_enabled = (corr_status & CORR_STATUS_BUSY) ? 1 : 0;
    
    return &g_system_status;
}

// ====== 坏点管理函数实现 ======
int dpc_add_manual_badpixel(uint16_t x, uint16_t y, uint8_t type) {
    if (g_manual_bp_count >= MAX_MANUAL_BP) {
        DPC_DEBUG("Manual bad pixel list is full");
        return DPC_ERROR_OVERFLOW;
    }
    
    if (x >= FRAME_WIDTH || y >= FRAME_HEIGHT) {
        DPC_DEBUG("Invalid coordinates: (%d, %d)", x, y);
        return DPC_ERROR_PARAM;
    }
    
    // 检查是否已存在
    for (uint32_t i = 0; i < g_manual_bp_count; i++) {
        if (g_manual_bp_list[i].x == x && g_manual_bp_list[i].y == y) {
            DPC_DEBUG("Manual bad pixel (%d, %d) already exists", x, y);
            return DPC_ERROR_CONFIG;
        }
    }
    
    // 添加新的手动坏点
    g_manual_bp_list[g_manual_bp_count].x = x;
    g_manual_bp_list[g_manual_bp_count].y = y;
    g_manual_bp_list[g_manual_bp_count].type = type;
    g_manual_bp_list[g_manual_bp_count].confidence = 255;
    g_manual_bp_count++;
    
    DPC_DEBUG("Added manual bad pixel at (%d, %d), type=%d, total: %d", 
              x, y, type, g_manual_bp_count);
    
    return DPC_SUCCESS;
}

int dpc_sort_badpixel_list(BadPixel_t *bp_list, uint32_t count) {
    if (!bp_list || count == 0) {
        return DPC_ERROR_PARAM;
    }
    
    // 简单的冒泡排序（行优先）
    for (uint32_t i = 0; i < count - 1; i++) {
        for (uint32_t j = i + 1; j < count; j++) {
            BadPixel_t *bp1 = &bp_list[i];
            BadPixel_t *bp2 = &bp_list[j];
            
            if (bp1->y > bp2->y || (bp1->y == bp2->y && bp1->x > bp2->x)) {
                // 交换
                BadPixel_t temp = *bp1;
                *bp1 = *bp2;
                *bp2 = temp;
            }
        }
    }
    
    return DPC_SUCCESS;
}

// ====== 轮询模式处理函数 ======
int dpc_polling_process_frame(void) {
    printf("=== Polling Mode Frame Processing ===\n");
    
    // 1. 配置检测器手动坏点表
    write_reg32(DPC_DETECTOR_BASE + DET_REG_MANUAL_NUM, g_manual_bp_count);
    for (uint32_t i = 0; i < g_manual_bp_count; i++) {
        uint32_t coord = COORD_TO_REG(g_manual_bp_list[i].x, g_manual_bp_list[i].y);
        write_reg32(DPC_DETECTOR_BASE + DET_MANUAL_LUT_BASE + i * 4, coord);
    }
    
    // 2. 启动检测器
    write_reg32(DPC_DETECTOR_BASE + DET_REG_GO, 1);
    DPC_DEBUG("Detector started");
    
    // 3. 轮询接收自动检测结果
    g_auto_bp_count = 0;
    uint32_t timeout = POLLING_TIMEOUT_MS;
    uint32_t frame_done = 0;
    
    while (timeout-- && !frame_done) {
        // 检查坏点数据
        uint32_t bp_valid = read_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_VALID_OFFSET);
        if (bp_valid & 0x1) {
            uint32_t bp_data = read_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_DATA_OFFSET);
            uint16_t x = REG_TO_X(bp_data);
            uint16_t y = REG_TO_Y(bp_data);
            uint8_t type = (bp_data & AUTO_BP_TYPE_MASK) ? BP_TYPE_STUCK : BP_TYPE_DEAD;
            
            if (g_auto_bp_count < MAX_AUTO_BP && x < FRAME_WIDTH && y < FRAME_HEIGHT) {
                g_auto_bp_list[g_auto_bp_count].x = x;
                g_auto_bp_list[g_auto_bp_count].y = y;
                g_auto_bp_list[g_auto_bp_count].type = type;
                g_auto_bp_list[g_auto_bp_count].confidence = 255;
                g_auto_bp_count++;
                
                DPC_VERBOSE("Auto BP: (%d, %d) type=%d", x, y, type);
            }
            
            // 发送准备信号
            write_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_READY_OFFSET, 1);
            delay_ms(1);
            write_reg32(AUTO_BP_GPIO_BASE + AUTO_BP_READY_OFFSET, 0);
        }
        
        // 检查帧完成
        uint32_t det_status = read_reg32(DPC_DETECTOR_BASE + DET_REG_STATUS);
        if (det_status & DET_STATUS_DONE) {
            frame_done = 1;
            DPC_DEBUG("Frame detection completed");
            break;
        }
        
        delay_ms(1);
    }
    
    if (!frame_done) {
        DPC_DEBUG("Detection timeout");
        return DPC_ERROR_TIMEOUT;
    }
    
    // 4. 合并坏点列表
    g_merged_bp_count = 0;
    
    // 添加手动坏点
    for (uint32_t i = 0; i < g_manual_bp_count && g_merged_bp_count < MAX_ALL_BP; i++) {
        g_merged_bp_list[g_merged_bp_count] = g_manual_bp_list[i];
        g_merged_bp_count++;
    }
    
    // 添加自动坏点（去重）
    for (uint32_t i = 0; i < g_auto_bp_count && g_merged_bp_count < MAX_ALL_BP; i++) {
        uint8_t is_duplicate = 0;
        for (uint32_t j = 0; j < g_manual_bp_count; j++) {
            if (g_auto_bp_list[i].x == g_manual_bp_list[j].x && 
                g_auto_bp_list[i].y == g_manual_bp_list[j].y) {
                is_duplicate = 1;
                break;
            }
        }
        
        if (!is_duplicate) {
            g_merged_bp_list[g_merged_bp_count] = g_auto_bp_list[i];
            g_merged_bp_count++;
        }
    }
    
    // 排序
    dpc_sort_badpixel_list(g_merged_bp_list, g_merged_bp_count);
    
    // 5. 配置校正器
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_GO, 0);
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_TABLE_RDY, 0);
    
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_ALL_NUM, g_merged_bp_count);
    for (uint32_t i = 0; i < g_merged_bp_count; i++) {
        uint32_t coord = COORD_TO_REG(g_merged_bp_list[i].x, g_merged_bp_list[i].y);
        write_reg32(DPC_CORRECTOR_BASE + CORR_ALL_LUT_BASE + i * 4, coord);
    }
    
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_TABLE_RDY, 1);
    
    // 6. 启动校正器
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_GO, 1);
    
    DPC_DEBUG("Frame processing completed: Manual=%d, Auto=%d, Total=%d", 
              g_manual_bp_count, g_auto_bp_count, g_merged_bp_count);
    
    g_system_status.frame_count++;
    
    printf("======================================\n\n");
    return DPC_SUCCESS;
}

// ====== 统计和调试函数 ======
void dpc_print_statistics(void) {
    DpcSystemStatus_t *status = dpc_get_system_status();
    
    printf("\n=== DPC System Statistics ===\n");
    printf("Frame count: %d\n", status->frame_count);
    printf("Manual bad pixels: %d\n", status->manual_bp_count);
    printf("Auto dead pixels: %d\n", status->auto_dead_count);
    printf("Auto stuck pixels: %d\n", status->auto_stuck_count);
    printf("Total corrected pixels: %d\n", status->total_bp_count);
    printf("Bad pixel ratio: %.4f%%\n", 
           (float)status->total_bp_count * 100.0f / (FRAME_WIDTH * FRAME_HEIGHT));
    printf("Detector status: %s\n", status->detector_enabled ? "Running" : "Stopped");
    printf("Corrector status: %s\n", status->corrector_enabled ? "Running" : "Stopped");
    printf("Error count: %d\n", status->error_count);
    printf("=============================\n\n");
}

void dpc_print_badpixel_list(const BadPixel_t *bp_list, uint32_t count) {
    if (!bp_list || count == 0) {
        printf("Bad pixel list is empty\n");
        return;
    }
    
    printf("Bad pixel list (%d entries):\n", count);
    for (uint32_t i = 0; i < count; i++) {
        const char *type_str;
        switch (bp_list[i].type) {
            case BP_TYPE_DEAD: type_str = "Dead"; break;
            case BP_TYPE_STUCK: type_str = "Stuck"; break;
            case BP_TYPE_MANUAL: type_str = "Manual"; break;
            default: type_str = "Unknown"; break;
        }
        
        printf("  [%3d] (%3d, %3d) %s (conf: %d)\n", 
               i, bp_list[i].x, bp_list[i].y, type_str, bp_list[i].confidence);
    }
    printf("\n");
}

// ====== 示例应用主函数 ======
void demo_add_sample_manual_badpixels(void) {
    printf("Adding sample manual bad pixels...\n");
    
    // 添加一些示例手动坏点
    dpc_add_manual_badpixel(50, 100, BP_TYPE_MANUAL);
    dpc_add_manual_badpixel(120, 200, BP_TYPE_MANUAL);
    dpc_add_manual_badpixel(300, 250, BP_TYPE_MANUAL);
    dpc_add_manual_badpixel(450, 350, BP_TYPE_MANUAL);
    dpc_add_manual_badpixel(600, 450, BP_TYPE_MANUAL);
    
    printf("Added %d manual bad pixels\n\n", g_manual_bp_count);
}

void demo_configuration_test(void) {
    printf("=== Configuration Test ===\n");
    
    // 测试不同的配置
    DpcConfig_t test_config;
    test_config.k_threshold = 150;
    test_config.auto_detect_enable = 1;
    test_config.manual_correct_enable = 1;
    test_config.frame_sync_mode = 1;
    test_config.debug_output_enable = 1;
    
    dpc_system_config(&test_config);
    
    printf("==========================\n\n");
}

void demo_polling_mode(void) {
    printf("=== Polling Mode Demo ===\n");
    
    g_work_mode = DPC_MODE_POLLING;
    
    // 处理几帧图像
    for (int frame = 1; frame <= 3; frame++) {
        printf("Processing frame %d (polling mode)...\n", frame);
        
        int ret = dpc_polling_process_frame();
        if (ret == DPC_SUCCESS) {
            printf("Frame %d processed successfully\n", frame);
        } else {
            printf("Frame %d processing failed (error: %d)\n", frame, ret);
            g_system_status.error_count++;
        }
        
        delay_ms(100);
    }
    
    printf("=========================\n\n");
}

void demo_interrupt_mode(void) {
    printf("=== Interrupt Mode Demo ===\n");
    
    g_work_mode = DPC_MODE_INTERRUPT;
    
    // 启用中断
    dpc_interrupt_enable();
    
    // 处理几帧图像
    for (int frame = 1; frame <= 3; frame++) {
        printf("Processing frame %d (interrupt mode)...\n", frame);
        
        uint32_t merged_count;
        int ret = dpc_interrupt_driven_frame_process(
            g_manual_bp_list, g_manual_bp_count,
            g_merged_bp_list, &merged_count, MAX_ALL_BP);
        
        if (ret == DPC_SUCCESS) {
            g_merged_bp_count = merged_count;
            printf("Frame %d processed successfully (merged %d bad pixels)\n", 
                   frame, merged_count);
        } else {
            printf("Frame %d processing failed (error: %d)\n", frame, ret);
            g_system_status.error_count++;
        }
        
        delay_ms(100);
    }
    
    // 禁用中断
    dpc_interrupt_disable();
    
    printf("==========================\n\n");
}

int main(void) {
    printf("DPC Separated Architecture Demo Application\n");
    printf("===========================================\n\n");
    
    // 1. 系统初始化
    if (dpc_system_init() != DPC_SUCCESS) {
        printf("System initialization failed!\n");
        return -1;
    }
    
    // 2. 添加示例手动坏点
    demo_add_sample_manual_badpixels();
    
    // 3. 配置测试
    demo_configuration_test();
    
    // 4. 测试中断系统
    printf("=== Interrupt System Test ===\n");
    if (dpc_test_interrupt_system() == DPC_SUCCESS) {
        printf("Interrupt system test PASSED\n");
    } else {
        printf("Interrupt system test FAILED\n");
    }
    printf("==============================\n\n");
    
    // 5. 轮询模式演示
    demo_polling_mode();
    
    // 6. 中断模式演示
    demo_interrupt_mode();
    
    // 7. 打印统计信息
    dpc_print_statistics();
    dpc_print_interrupt_statistics();
    
    // 8. 显示坏点列表
    printf("=== Bad Pixel Lists ===\n");
    printf("Manual bad pixels:\n");
    dpc_print_badpixel_list(g_manual_bp_list, g_manual_bp_count);
    
    printf("Final merged bad pixels:\n");
    dpc_print_badpixel_list(g_merged_bp_list, g_merged_bp_count);
    
    // 9. 持续运行模式（可选）
    printf("=== Continuous Operation ===\n");
    printf("Starting continuous operation (press any key to stop)...\n");
    
    uint32_t continuous_frame = 0;
    while (continuous_frame < 10) { // 限制为10帧演示
        continuous_frame++;
        
        printf("Continuous frame %d... ", continuous_frame);
        
        if (g_work_mode == DPC_MODE_POLLING) {
            int ret = dpc_polling_process_frame();
            printf("%s\n", ret == DPC_SUCCESS ? "OK" : "FAILED");
        } else {
            uint32_t merged_count;
            int ret = dpc_interrupt_driven_frame_process(
                g_manual_bp_list, g_manual_bp_count,
                g_merged_bp_list, &merged_count, MAX_ALL_BP);
            printf("%s (merged: %d)\n", 
                   ret == DPC_SUCCESS ? "OK" : "FAILED", merged_count);
        }
        
        delay_ms(1000); // 1秒间隔
    }
    
    // 10. 系统清理
    printf("\n=== System Cleanup ===\n");
    write_reg32(DPC_DETECTOR_BASE + DET_REG_GO, 0);
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_GO, 0);
    dpc_interrupt_disable();
    
    printf("DPC system stopped\n");
    printf("Final statistics:\n");
    dpc_print_statistics();
    
    printf("Demo completed successfully!\n");
    return 0;
}
