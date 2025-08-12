/*
 * DPC上位机控制代码 (RISC-V)
 * 
 * 功能：
 * 1. 配置手动坏点表到检测器
 * 2. 启动检测器进行自动坏点检测
 * 3. 接收自动检测结果
 * 4. 合并手动和自动坏点列表
 * 5. 配置合并后的坏点列表到校正器
 * 6. 启动校正器进行坏点校正
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// 基地址定义 (根据实际硬件平台调整)
#define DPC_DETECTOR_BASE    0xe1008000  // 检测器AXI基地址
#define DPC_CORRECTOR_BASE   0xe100c000  // 校正器AXI基地址

// 检测器寄存器偏移
#define DET_REG_GO           0x00
#define DET_REG_MANUAL_NUM   0x04  
#define DET_REG_K_THRESHOLD  0x08
#define DET_REG_RESERVED     0x0C
#define DET_MANUAL_LUT_BASE  0x10

// 校正器寄存器偏移
#define CORR_REG_GO          0x00
#define CORR_REG_ALL_NUM     0x04
#define CORR_REG_TABLE_RDY   0x08
#define CORR_REG_RESERVED    0x0C
#define CORR_ALL_LUT_BASE    0x10

// 坏点检测中断接口 (通过GPIO或专用中断线)
#define AUTO_BP_VALID_GPIO   0x60001000  // 假设的GPIO基地址
#define AUTO_BP_DATA_GPIO    0x60001004  // 坏点坐标数据
#define AUTO_BP_READY_GPIO   0x60001008  // 准备信号

// 配置参数
#define MAX_MANUAL_BP        128
#define MAX_AUTO_BP          256  
#define MAX_ALL_BP           512
#define K_THRESHOLD_DEFAULT  100
#define FRAME_WIDTH          640
#define FRAME_HEIGHT         512

// 坏点结构体
typedef struct {
    uint16_t x;
    uint16_t y;
    uint8_t type;  // 0=死点, 1=盲点, 2=手动
} BadPixel_t;

// 全局变量
static BadPixel_t manual_bp_list[MAX_MANUAL_BP];
static BadPixel_t auto_bp_list[MAX_AUTO_BP];
static BadPixel_t all_bp_list[MAX_ALL_BP];
static uint32_t manual_bp_count = 0;
static uint32_t auto_bp_count = 0;
static uint32_t all_bp_count = 0;

// 寄存器访问函数
static inline void write_reg32(uint32_t addr, uint32_t value) {
    *(volatile uint32_t*)addr = value;
}

static inline uint32_t read_reg32(uint32_t addr) {
    return *(volatile uint32_t*)addr;
}

// 延时函数
static void delay_ms(uint32_t ms) {
    // 简单的延时实现，实际应用中可以用定时器
    for(volatile uint32_t i = 0; i < ms * 1000; i++);
}

// 初始化DPC系统
int dpc_system_init(void) {
    printf("DPC System Initialization...\n");
    
    // 复位两个模块
    write_reg32(DPC_DETECTOR_BASE + DET_REG_GO, 0);
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_GO, 0);
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_TABLE_RDY, 0);
    
    // 设置检测器参数
    write_reg32(DPC_DETECTOR_BASE + DET_REG_K_THRESHOLD, K_THRESHOLD_DEFAULT);
    
    // 清空坏点列表
    manual_bp_count = 0;
    auto_bp_count = 0;
    all_bp_count = 0;
    
    printf("DPC System Initialized\n");
    return 0;
}

// 添加手动坏点
int dpc_add_manual_badpixel(uint16_t x, uint16_t y) {
    if (manual_bp_count >= MAX_MANUAL_BP) {
        printf("Error: Manual bad pixel list is full\n");
        return -1;
    }
    
    manual_bp_list[manual_bp_count].x = x;
    manual_bp_list[manual_bp_count].y = y;
    manual_bp_list[manual_bp_count].type = 2; // 手动类型
    manual_bp_count++;
    
    printf("Added manual bad pixel at (%d, %d), total: %d\n", x, y, manual_bp_count);
    return 0;
}

// 配置手动坏点表到检测器
int dpc_config_manual_badpixels(void) {
    printf("Configuring manual bad pixels to detector...\n");
    
    // 写入手动坏点数量
    write_reg32(DPC_DETECTOR_BASE + DET_REG_MANUAL_NUM, manual_bp_count);
    
    // 写入手动坏点表
    for (uint32_t i = 0; i < manual_bp_count; i++) {
        uint32_t coord = (manual_bp_list[i].x << 16) | manual_bp_list[i].y;
        write_reg32(DPC_DETECTOR_BASE + DET_MANUAL_LUT_BASE + i * 4, coord);
    }
    
    printf("Manual bad pixels configured: %d\n", manual_bp_count);
    return 0;
}

// 启动自动坏点检测
int dpc_start_auto_detection(void) {
    printf("Starting automatic bad pixel detection...\n");
    
    // 配置手动坏点表
    dpc_config_manual_badpixels();
    
    // 启动检测器
    write_reg32(DPC_DETECTOR_BASE + DET_REG_GO, 1);
    
    printf("Auto detection started\n");
    return 0;
}

// 接收自动检测的坏点 (中断处理函数或轮询)
int dpc_receive_auto_badpixel(uint16_t x, uint16_t y, uint8_t type) {
    if (auto_bp_count >= MAX_AUTO_BP) {
        printf("Warning: Auto bad pixel list is full, ignoring (%d, %d)\n", x, y);
        return -1;
    }
    
    auto_bp_list[auto_bp_count].x = x;
    auto_bp_list[auto_bp_count].y = y;
    auto_bp_list[auto_bp_count].type = type;  // 0=死点, 1=盲点
    auto_bp_count++;
    
    return 0;
}

// 轮询接收自动检测结果
int dpc_poll_auto_detection_results(void) {
    printf("Polling auto detection results...\n");
    
    auto_bp_count = 0;  // 重置计数
    uint32_t timeout = 100000;  // 超时计数
    
    while (timeout--) {
        // 检查是否有新的坏点检测结果
        uint32_t bp_valid = read_reg32(AUTO_BP_VALID_GPIO);
        
        if (bp_valid & 0x1) {
            // 读取坏点数据
            uint32_t bp_data = read_reg32(AUTO_BP_DATA_GPIO);
            uint16_t x = (bp_data >> 16) & 0x3FF;  // 高10位为X坐标
            uint16_t y = bp_data & 0x3FF;          // 低10位为Y坐标
            uint8_t type = (bp_data >> 26) & 0x1;  // 类型位
            
            // 接收坏点
            dpc_receive_auto_badpixel(x, y, type);
            
            // 发送准备信号
            write_reg32(AUTO_BP_READY_GPIO, 1);
            delay_ms(1);
            write_reg32(AUTO_BP_READY_GPIO, 0);
        }
        
        // 检查帧检测是否完成
        uint32_t frame_done = read_reg32(AUTO_BP_VALID_GPIO + 4);
        if (frame_done & 0x1) {
            printf("Frame detection completed\n");
            break;
        }
        
        delay_ms(1);
    }
    
    if (timeout == 0) {
        printf("Warning: Auto detection polling timeout\n");
    }
    
    printf("Auto detection completed, found %d bad pixels\n", auto_bp_count);
    return 0;
}

// 合并手动和自动坏点列表
int dpc_merge_badpixel_lists(void) {
    printf("Merging bad pixel lists...\n");
    
    all_bp_count = 0;
    
    // 添加手动坏点
    for (uint32_t i = 0; i < manual_bp_count && all_bp_count < MAX_ALL_BP; i++) {
        all_bp_list[all_bp_count] = manual_bp_list[i];
        all_bp_count++;
    }
    
    // 添加自动检测的坏点，跳过重复的
    for (uint32_t i = 0; i < auto_bp_count && all_bp_count < MAX_ALL_BP; i++) {
        // 检查是否与手动坏点重复
        int is_duplicate = 0;
        for (uint32_t j = 0; j < manual_bp_count; j++) {
            if (auto_bp_list[i].x == manual_bp_list[j].x && 
                auto_bp_list[i].y == manual_bp_list[j].y) {
                is_duplicate = 1;
                break;
            }
        }
        
        if (!is_duplicate) {
            all_bp_list[all_bp_count] = auto_bp_list[i];
            all_bp_count++;
        }
    }
    
    // 按坐标排序 (行优先)
    for (uint32_t i = 0; i < all_bp_count - 1; i++) {
        for (uint32_t j = i + 1; j < all_bp_count; j++) {
            BadPixel_t *bp1 = &all_bp_list[i];
            BadPixel_t *bp2 = &all_bp_list[j];
            
            if (bp1->y > bp2->y || (bp1->y == bp2->y && bp1->x > bp2->x)) {
                // 交换
                BadPixel_t temp = *bp1;
                *bp1 = *bp2;
                *bp2 = temp;
            }
        }
    }
    
    printf("Bad pixel lists merged: %d total (manual: %d, auto: %d)\n", 
           all_bp_count, manual_bp_count, auto_bp_count);
    
    return 0;
}

// 配置合并后的坏点表到校正器
int dpc_config_corrector_badpixels(void) {
    printf("Configuring merged bad pixels to corrector...\n");
    
    // 先停止校正器
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_GO, 0);
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_TABLE_RDY, 0);
    
    // 写入总坏点数量
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_ALL_NUM, all_bp_count);
    
    // 写入坏点表
    for (uint32_t i = 0; i < all_bp_count; i++) {
        uint32_t coord = (all_bp_list[i].x << 16) | all_bp_list[i].y;
        write_reg32(DPC_CORRECTOR_BASE + CORR_ALL_LUT_BASE + i * 4, coord);
    }
    
    // 设置表准备完成标志
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_TABLE_RDY, 1);
    
    printf("Corrector bad pixel table configured: %d entries\n", all_bp_count);
    return 0;
}

// 启动校正器
int dpc_start_correction(void) {
    printf("Starting bad pixel correction...\n");
    
    // 启动校正器
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_GO, 1);
    
    printf("Bad pixel correction started\n");
    return 0;
}

// 停止DPC系统
int dpc_system_stop(void) {
    printf("Stopping DPC system...\n");
    
    // 停止两个模块
    write_reg32(DPC_DETECTOR_BASE + DET_REG_GO, 0);
    write_reg32(DPC_CORRECTOR_BASE + CORR_REG_GO, 0);
    
    printf("DPC system stopped\n");
    return 0;
}

// 完整的DPC处理流程
int dpc_process_frame(void) {
    printf("=== DPC Frame Processing Start ===\n");
    
    // 1. 启动自动检测
    if (dpc_start_auto_detection() != 0) {
        printf("Error: Failed to start auto detection\n");
        return -1;
    }
    
    // 2. 等待并接收自动检测结果
    if (dpc_poll_auto_detection_results() != 0) {
        printf("Error: Failed to receive auto detection results\n");
        return -1;
    }
    
    // 3. 合并坏点列表
    if (dpc_merge_badpixel_lists() != 0) {
        printf("Error: Failed to merge bad pixel lists\n");
        return -1;
    }
    
    // 4. 配置校正器
    if (dpc_config_corrector_badpixels() != 0) {
        printf("Error: Failed to configure corrector\n");
        return -1;
    }
    
    // 5. 启动校正
    if (dpc_start_correction() != 0) {
        printf("Error: Failed to start correction\n");
        return -1;
    }
    
    printf("=== DPC Frame Processing Complete ===\n");
    return 0;
}

// 打印坏点统计信息
void dpc_print_statistics(void) {
    printf("\n=== DPC Statistics ===\n");
    printf("Manual bad pixels: %d\n", manual_bp_count);
    printf("Auto dead pixels: ");
    uint32_t dead_count = 0, stuck_count = 0;
    for (uint32_t i = 0; i < auto_bp_count; i++) {
        if (auto_bp_list[i].type == 0) dead_count++;
        else stuck_count++;
    }
    printf("%d\n", dead_count);
    printf("Auto stuck pixels: %d\n", stuck_count);
    printf("Total auto pixels: %d\n", auto_bp_count);
    printf("Total corrected pixels: %d\n", all_bp_count);
    printf("Frame size: %dx%d\n", FRAME_WIDTH, FRAME_HEIGHT);
    printf("Bad pixel ratio: %.4f%%\n", (float)all_bp_count * 100.0f / (FRAME_WIDTH * FRAME_HEIGHT));
    printf("======================\n\n");
}

// 示例使用代码
int main(void) {
    printf("DPC Separated System Demo\n");
    
    // 初始化DPC系统
    if (dpc_system_init() != 0) {
        return -1;
    }
    
    // 添加一些示例手动坏点
    dpc_add_manual_badpixel(100, 200);
    dpc_add_manual_badpixel(150, 300);
    dpc_add_manual_badpixel(200, 400);
    
    // 处理一帧图像
    if (dpc_process_frame() != 0) {
        return -1;
    }
    
    // 打印统计信息
    dpc_print_statistics();
    
    // 持续运行 (在实际应用中可能是中断驱动的)
    printf("DPC system running...\n");
    while (1) {
        // 可以在这里添加周期性的处理逻辑
        delay_ms(1000);
        
        // 示例：每10秒重新处理一次
        static uint32_t frame_count = 0;
        if (++frame_count % 10 == 0) {
            printf("Processing frame %d\n", frame_count);
            dpc_process_frame();
            dpc_print_statistics();
        }
    }
    
    return 0;
}
