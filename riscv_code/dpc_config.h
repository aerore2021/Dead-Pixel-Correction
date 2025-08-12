/*
 * DPC系统配置头文件
 * 
 * 定义了DPC检测和校正系统的硬件配置、寄存器映射和参数
 */

#ifndef _DPC_CONFIG_H_
#define _DPC_CONFIG_H_

#include <stdint.h>

// ====== 硬件配置 ======
// 基地址定义 (根据实际硬件平台调整)
#define DPC_DETECTOR_BASE    0xe1008000  // 检测器AXI基地址
#define DPC_CORRECTOR_BASE   0xe100c000  // 校正器AXI基地址
#define AUTO_BP_GPIO_BASE    0x60001000  // 自动坏点GPIO基地址

// 图像参数
#define FRAME_WIDTH          640         // 图像宽度
#define FRAME_HEIGHT         512         // 图像高度
#define PIXEL_DEPTH          10          // 像素位宽
#define MAX_PIXEL_VALUE      ((1 << PIXEL_DEPTH) - 1)

// 坏点表大小限制
#define MAX_MANUAL_BP        128         // 最大手动坏点数
#define MAX_AUTO_BP          256         // 最大自动检测坏点数  
#define MAX_ALL_BP           512         // 总坏点表大小

// ====== 检测器寄存器映射 ======
#define DET_REG_GO           0x00        // 启动寄存器
#define DET_REG_MANUAL_NUM   0x04        // 手动坏点数量
#define DET_REG_K_THRESHOLD  0x08        // K值阈值
#define DET_REG_STATUS       0x0C        // 状态寄存器
#define DET_MANUAL_LUT_BASE  0x10        // 手动坏点表基地址 (0x10-0x20F)

// 检测器状态位定义
#define DET_STATUS_BUSY      (1 << 0)    // 检测忙标志
#define DET_STATUS_DONE      (1 << 1)    // 帧检测完成
#define DET_STATUS_ERROR     (1 << 2)    // 错误标志

// ====== 校正器寄存器映射 ======
#define CORR_REG_GO          0x00        // 启动寄存器
#define CORR_REG_ALL_NUM     0x04        // 总坏点数量
#define CORR_REG_TABLE_RDY   0x08        // 坏点表准备标志
#define CORR_REG_STATUS      0x0C        // 状态寄存器
#define CORR_ALL_LUT_BASE    0x10        // 总坏点表基地址 (0x10-0x80F)

// 校正器状态位定义
#define CORR_STATUS_BUSY     (1 << 0)    // 校正忙标志
#define CORR_STATUS_READY    (1 << 1)    // 就绪标志
#define CORR_STATUS_ERROR    (1 << 2)    // 错误标志

// ====== GPIO接口映射 ======
#define AUTO_BP_VALID_OFFSET 0x00        // 坏点有效信号
#define AUTO_BP_DATA_OFFSET  0x04        // 坏点数据
#define AUTO_BP_READY_OFFSET 0x08        // 准备信号
#define AUTO_BP_STATUS_OFFSET 0x0C       // 状态信号

// GPIO数据格式定义
#define AUTO_BP_X_MASK       0x3FF0000   // X坐标掩码 (bit[25:16])
#define AUTO_BP_Y_MASK       0x3FF       // Y坐标掩码 (bit[9:0])
#define AUTO_BP_TYPE_MASK    0x4000000   // 类型掩码 (bit[26])
#define AUTO_BP_VALID_MASK   0x80000000  // 有效标志 (bit[31])

// ====== 算法参数 ======
#define K_THRESHOLD_DEFAULT  100         // 默认K值阈值
#define K_THRESHOLD_MIN      10          // 最小K值阈值
#define K_THRESHOLD_MAX      1000        // 最大K值阈值

// 检测窗口大小
#define DETECT_WINDOW_SIZE   3           // 3x3检测窗口

// 校正参数
#define CORRECT_WINDOW_SIZE  3           // 3x3校正窗口
#define MIN_VALID_NEIGHBORS  4           // 最少有效邻居像素数

// ====== 坏点类型定义 ======
#define BP_TYPE_DEAD         0           // 死点 (k=0)
#define BP_TYPE_STUCK        1           // 盲点 (k值偏差大)
#define BP_TYPE_MANUAL       2           // 手动标记

// ====== 错误代码定义 ======
#define DPC_SUCCESS          0           // 成功
#define DPC_ERROR_PARAM      -1          // 参数错误
#define DPC_ERROR_OVERFLOW   -2          // 缓冲区溢出
#define DPC_ERROR_TIMEOUT    -3          // 超时错误
#define DPC_ERROR_HARDWARE   -4          // 硬件错误
#define DPC_ERROR_CONFIG     -5          // 配置错误

// ====== 调试配置 ======
#define DPC_DEBUG_ENABLE     1           // 启用调试输出
#define DPC_DEBUG_VERBOSE    0           // 详细调试信息

#if DPC_DEBUG_ENABLE
    #define DPC_DEBUG(fmt, ...) printf("[DPC] " fmt "\n", ##__VA_ARGS__)
    #if DPC_DEBUG_VERBOSE
        #define DPC_VERBOSE(fmt, ...) printf("[DPC-V] " fmt "\n", ##__VA_ARGS__)
    #else
        #define DPC_VERBOSE(fmt, ...)
    #endif
#else
    #define DPC_DEBUG(fmt, ...)
    #define DPC_VERBOSE(fmt, ...)
#endif

// ====== 性能配置 ======
#define POLLING_TIMEOUT_MS   5000        // 轮询超时时间 (毫秒)
#define FRAME_TIMEOUT_MS     1000        // 帧处理超时时间
#define CONFIG_TIMEOUT_MS    100         // 配置超时时间

// 延时配置
#define RESET_DELAY_MS       10          // 复位延时
#define CONFIG_DELAY_MS      1           // 配置延时
#define READY_DELAY_MS       1           // 准备信号延时

// ====== 坏点结构体定义 ======
typedef struct {
    uint16_t x;                          // X坐标
    uint16_t y;                          // Y坐标
    uint8_t type;                        // 坏点类型
    uint8_t confidence;                  // 置信度 (0-255)
} BadPixel_t;

// DPC系统状态结构体
typedef struct {
    uint32_t manual_bp_count;            // 手动坏点数量
    uint32_t auto_dead_count;            // 自动死点数量
    uint32_t auto_stuck_count;           // 自动盲点数量
    uint32_t total_bp_count;             // 总坏点数量
    uint32_t frame_count;                // 处理帧计数
    uint32_t error_count;                // 错误计数
    uint8_t detector_enabled;            // 检测器启用状态
    uint8_t corrector_enabled;           // 校正器启用状态
} DpcSystemStatus_t;

// DPC配置结构体
typedef struct {
    uint32_t k_threshold;                // K值阈值
    uint8_t auto_detect_enable;          // 自动检测使能
    uint8_t manual_correct_enable;       // 手动校正使能
    uint8_t frame_sync_mode;             // 帧同步模式
    uint8_t debug_output_enable;         // 调试输出使能
} DpcConfig_t;

// ====== 工具宏定义 ======
#define ARRAY_SIZE(arr)      (sizeof(arr) / sizeof((arr)[0]))
#define MIN(a, b)           ((a) < (b) ? (a) : (b))
#define MAX(a, b)           ((a) > (b) ? (a) : (b))
#define CLAMP(val, min, max) (MIN(MAX(val, min), max))

// 坐标转换宏
#define COORD_TO_REG(x, y)   (((x) << 16) | (y))
#define REG_TO_X(reg)        (((reg) >> 16) & 0x3FF)
#define REG_TO_Y(reg)        ((reg) & 0x3FF)

// 位操作宏
#define SET_BIT(reg, bit)    ((reg) |= (1 << (bit)))
#define CLR_BIT(reg, bit)    ((reg) &= ~(1 << (bit)))
#define GET_BIT(reg, bit)    (((reg) >> (bit)) & 0x1)

// ====== 函数声明 ======
// 基础访问函数
static inline void write_reg32(uint32_t addr, uint32_t value);
static inline uint32_t read_reg32(uint32_t addr);
static inline void delay_ms(uint32_t ms);

// 系统控制函数
int dpc_system_init(void);
int dpc_system_config(const DpcConfig_t *config);
int dpc_system_reset(void);
int dpc_system_stop(void);
DpcSystemStatus_t* dpc_get_system_status(void);

// 检测器控制函数
int dpc_detector_start(void);
int dpc_detector_stop(void);
int dpc_detector_set_k_threshold(uint32_t threshold);
int dpc_detector_config_manual_bp(const BadPixel_t *bp_list, uint32_t count);

// 校正器控制函数
int dpc_corrector_start(void);
int dpc_corrector_stop(void);
int dpc_corrector_config_all_bp(const BadPixel_t *bp_list, uint32_t count);
int dpc_corrector_set_ready(uint8_t ready);

// 坏点管理函数
int dpc_add_manual_badpixel(uint16_t x, uint16_t y, uint8_t type);
int dpc_remove_manual_badpixel(uint16_t x, uint16_t y);
int dpc_merge_badpixel_lists(void);
int dpc_sort_badpixel_list(BadPixel_t *bp_list, uint32_t count);

// 处理流程函数
int dpc_process_frame(void);
int dpc_poll_auto_detection_results(void);
int dpc_receive_auto_badpixel(uint16_t x, uint16_t y, uint8_t type);

// 调试和统计函数
void dpc_print_statistics(void);
void dpc_print_badpixel_list(const BadPixel_t *bp_list, uint32_t count);
int dpc_validate_badpixel(const BadPixel_t *bp);
int dpc_check_hardware_status(void);

#endif /* _DPC_CONFIG_H_ */
