# DPC分离架构项目

本项目实现了一个基于FPGA+RISC-V的分离式坏点检测校正(DPC)系统，将坏点检测和校正功能分离成两个独立的硬件模块，由RISC-V上位机进行协调控制。

## 项目结构

```
dpc/
├── verilog_code/          # FPGA Verilog代码
│   ├── DPC_Detector.v     # 坏点检测模块
│   ├── DPC_Corrector.v    # 坏点校正模块  
│   ├── DpcTop_Separated.v # 顶层集成模块
│   ├── Axi4LiteSlave_Detector.v  # 检测器AXI接口
│   ├── Axi4LiteSlave_Corrector.v # 校正器AXI接口
│   └── BRAM_BadPoint_Dual.v      # 双口BRAM
├── riscv_code/           # RISC-V软件代码
│   ├── dpc_config.h      # 配置头文件
│   ├── dpc_control.c     # 主控制代码
│   ├── dpc_interrupt.c   # 中断处理代码
│   ├── dpc_demo.c        # 示例应用程序
│   ├── Makefile          # 编译脚本
│   └── linker.ld         # 链接器脚本
├── matlab_code/          # MATLAB参考代码
│   ├── AutoDPC.m         # 自动坏点检测
│   ├── DPC.m             # 坏点校正
│   ├── ManualDPC.m       # 手动坏点处理
│   └── MedForDPC.m       # 中值滤波DPC
└── README.md            # 项目说明文档
```

## 系统架构

### 1. 分离式设计

本系统采用创新的分离式架构，将传统的统一DPC模块分离为：

- **检测器模块(DPC_Detector)**：专门负责k值坏点检测
  - 基于k值算法的自动死点/盲点检测
  - 跳过手动标记的坏点，避免重复检测
  - 实时输出检测结果给上位机

- **校正器模块(DPC_Corrector)**：专门负责坏点校正
  - 接收上位机合并的坏点列表
  - 基于3×3邻域的插值校正
  - 高效的查找表方式进行坏点匹配

### 2. 上位机协调控制

RISC-V上位机负责整个系统的协调和管理：

- **坏点列表管理**：合并手动和自动坏点，去重排序
- **模块配置**：通过AXI4-Lite接口配置两个模块
- **流程控制**：控制检测和校正的时序
- **统计监控**：收集和报告系统运行状态

### 3. 工作流程

```
1. 上位机配置手动坏点表到检测器
2. 启动检测器进行一帧的自动坏点检测
3. 上位机接收自动检测结果（轮询/中断）
4. 合并手动和自动坏点列表，去重排序
5. 配置合并后的坏点表到校正器
6. 启动校正器进行坏点校正
```

## 技术特性

### 1. k值检测算法

- **死点检测**：k=0，像素输出恒定为0
- **盲点检测**：k值偏差超过阈值，像素响应异常
- **邻域窗口**：3×3窗口计算k值
- **阈值可配**：通过寄存器动态调整检测阈值

### 2. AXI接口设计

- **AXI4-Lite配置接口**：寄存器配置和状态读取
- **AXI Stream数据接口**：图像数据流水线处理
- **双AXI接口**：检测器和校正器独立配置

### 3. 存储器架构

- **双口BRAM**：支持同时读写操作
- **坏点查找表**：高效的坐标匹配算法
- **流水线存储**：多级缓冲保证数据流畅

## 编译和使用

### 1. 硬件编译

```bash
cd verilog_code
# 使用Vivado进行综合和实现
vivado -mode batch -source build_fpga.tcl
```

### 2. 软件编译

```bash
cd riscv_code
make all          # 编译所有目标
make debug        # 编译调试版本
make release      # 编译发布版本
```

### 3. 运行示例

```bash
# 在FPGA硬件上运行
./build/dpc_demo.hex

# 或者在仿真器中运行
make sim
```

## 配置说明

### 1. 硬件配置

在`dpc_config.h`中配置硬件参数：

```c
#define FRAME_WIDTH          640         // 图像宽度
#define FRAME_HEIGHT         512         // 图像高度
#define DPC_DETECTOR_BASE    0xe1008000  // 检测器基地址
#define DPC_CORRECTOR_BASE   0xe100c000  // 校正器基地址
```

### 2. 算法参数

```c
#define K_THRESHOLD_DEFAULT  100         // 默认K值阈值
#define MAX_MANUAL_BP        128         // 最大手动坏点数
#define MAX_AUTO_BP          256         // 最大自动检测坏点数
```

## API说明

### 1. 系统控制

```c
int dpc_system_init(void);                    // 系统初始化
int dpc_system_config(const DpcConfig_t *config); // 系统配置
DpcSystemStatus_t* dpc_get_system_status(void);   // 获取状态
```

### 2. 坏点管理

```c
int dpc_add_manual_badpixel(uint16_t x, uint16_t y, uint8_t type);
int dpc_merge_badpixel_lists(void);
int dpc_sort_badpixel_list(BadPixel_t *bp_list, uint32_t count);
```

### 3. 处理流程

```c
int dpc_process_frame(void);                  // 轮询模式处理
int dpc_interrupt_driven_frame_process(...);  // 中断模式处理
```

## 调试功能

### 1. 调试输出

通过宏控制调试信息输出：

```c
#define DPC_DEBUG_ENABLE     1           // 启用调试输出
#define DPC_DEBUG_VERBOSE    1           // 详细调试信息
```

### 2. 统计信息

```c
void dpc_print_statistics(void);              // 打印系统统计
void dpc_print_interrupt_statistics(void);    // 打印中断统计
void dpc_print_badpixel_list(...);           // 打印坏点列表
```

### 3. 硬件状态

```c
int dpc_check_hardware_status(void);          // 检查硬件状态
```

## 性能指标

- **处理速度**：支持实时图像处理
- **检测精度**：k值算法准确识别坏点
- **资源占用**：优化的FPGA资源使用
- **功耗控制**：模块化设计便于功耗管理

## 应用场景

- **图像传感器校正**：CCD/CMOS坏点校正
- **工业视觉**：产品质量检测
- **医疗成像**：X射线、CT等医疗图像处理
- **安防监控**：视频监控图像增强

## 扩展功能

### 1. 多通道支持

可扩展支持多个图像通道并行处理。

### 2. 动态坏点检测

支持运行时动态坏点检测和校正。

### 3. 统计分析

提供详细的坏点统计和分析功能。

### 4. 网络接口

可添加网络接口支持远程配置和监控。

## 故障排除

### 1. 编译错误

- 检查RISC-V工具链安装
- 验证头文件路径
- 确认硬件地址配置

### 2. 运行错误

- 检查硬件连接
- 验证时钟配置
- 确认中断配置

### 3. 性能问题

- 调整缓冲区大小
- 优化算法参数
- 检查内存对齐

## 版本历史

- **v1.0**：基础DPC功能实现
- **v2.0**：分离式架构重构
- **v2.1**：增加中断支持和优化

## 贡献指南

欢迎提交bug报告、功能请求和代码改进。

## 许可证

本项目采用MIT许可证。

## 联系方式

如有问题或建议，请通过以下方式联系：

- 邮箱：[your-email@example.com]
- 项目主页：[project-homepage]

---

© 2024 DPC分离架构项目。保留所有权利。
