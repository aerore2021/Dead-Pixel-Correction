# Dead Pixel Correction FPGA Implementation

## 项目概述

这是一个用于FPGA的坏点校正(Dead Pixel Correction, DPC)实现项目。该项目通过AXI4-Lite接口配置坏点列表,通过AXI4-Stream接口处理图像数据流。

## 坏点列表

本项目配置的坏点坐标(行, 列)如下:
- [29, 156]
- [82, 132]
- [82, 133]
- [83, 132]
- [83, 133]

## 目录结构

```
FPGA_v2/
├── src/                    # Verilog源文件
│   ├── DpcTop.v           # 顶层模块
│   ├── Axi4LiteSlave_dpc.v # AXI4-Lite从接口
│   ├── Kernel_dpc.v       # DPC核心处理模块
│   ├── Filter_Function_dpc.v # 滤波功能模块
│   ├── Window_dpc.v       # 滑动窗口模块
│   ├── LineBuf_dpc.v      # 行缓存模块
│   └── manul.v            # 坏点列表管理模块
├── sim/                    # 仿真文件
│   └── tb_DPC_Detector.sv # Testbench
├── scripts/                # Python脚本
│   ├── png_to_txt.py      # PNG转TXT工具
│   ├── txt_to_png.py      # TXT转PNG工具
│   ├── convert_all_images.sh   # 批量转换脚本(Linux/Mac)
│   └── convert_all_images.bat  # 批量转换脚本(Windows)
├── image_inputs/           # 输入测试图像
│   └── dpc_test_*/        # 各测试案例文件夹
├── FPGA_outputs/           # FPGA处理后的输出
├── make.tcl               # Vivado项目创建脚本
├── sim.tcl                # 仿真脚本
└── syn.tcl                # 综合脚本
```

## 使用说明

### 1. 准备测试图像

首先需要将PNG图像转换为TXT格式(每行一个16进制像素值):

#### 方法一: 转换单个图像
```bash
# Linux/Mac
python3 scripts/png_to_txt.py image_inputs/dpc_test_1/1.png

# Windows
python scripts\png_to_txt.py image_inputs\dpc_test_1\1.png
```

#### 方法二: 批量转换所有测试图像
```bash
# Linux/Mac
bash scripts/convert_all_images.sh

# Windows
scripts\convert_all_images.bat
```

### 2. 创建Vivado项目

```bash
vivado -mode tcl -source make.tcl
```

这将创建Vivado项目,配置IP核(BRAM),并添加所有源文件。

### 3. 运行仿真

```bash
vivado -mode tcl -source sim.tcl
```

或者在创建项目时一起运行:
```bash
vivado -mode tcl -source make.tcl -tclargs -simulation
```

仿真将:
1. 通过AXI4-Lite接口配置坏点列表
2. 读取TXT格式的测试图像
3. 通过AXI4-Stream接口发送图像数据
4. 接收处理后的图像数据并保存为TXT文件

### 4. 转换输出图像

将仿真输出的TXT文件转换回PNG格式:

```bash
# 转换单个输出文件 (640x512图像)
python3 scripts/txt_to_png.py FPGA_outputs/1_out.txt -o FPGA_outputs/1_out.png -w 640 -H 512

# 批量转换
python3 scripts/txt_to_png.py -a FPGA_outputs/ -o FPGA_outputs/png/ -w 640 -H 512
```

### 5. 运行综合

```bash
vivado -mode tcl -source syn.tcl
```

或者在创建项目时一起运行:
```bash
vivado -mode tcl -source make.tcl -tclargs -synthesis
```

## 模块说明

### DpcTop
顶层模块,集成AXI4-Lite从接口和DPC核心处理模块。

**接口:**
- `axis_aclk/axis_aresetn`: AXI4-Stream时钟和复位
- `s_axis_*`: AXI4-Stream从接口(图像输入)
- `m_axis_*`: AXI4-Stream主接口(图像输出)
- `s00_axi_*`: AXI4-Lite从接口(配置接口)

### Axi4LiteSlave_dpc
AXI4-Lite从接口,用于配置坏点数量和坏点坐标列表。

**寄存器映射:**
- `0x00`: 控制寄存器(GO位)
- `0x04`: 坏点数量寄存器
- `0x08+`: 坏点LUT(每个坏点4字节,格式: {列[31:16], 行[15:0]})

### Kernel_dpc
DPC核心处理模块,包含行缓存、滑动窗口和坏点检测逻辑。

### Filter_Function_dpc
坏点替换算法实现:
- 基于3x3邻域的多方向插值
- 优先选择梯度最小的方向
- 排除含坏点的方向

### manul.v
管理坏点列表的读取,在处理每帧图像时顺序提供坏点坐标。

## 参数配置

主要参数在testbench和顶层模块中定义:
- `ROW = 512`: 图像高度
- `COL = 640`: 图像宽度
- `AXIS_TDATA_WIDTH = 14`: 像素数据位宽
- `NUM_BAD_PIXELS = 5`: 坏点数量

## 注意事项

1. 坏点坐标格式: 在AXI接口中,坐标格式为 `{列[31:16], 行[15:0]}`
2. 图像格式: 支持灰度图像,像素位宽可配置(默认14位)
3. BRAM配置: 使用Xilinx BRAM IP核,需要在Vivado中生成
4. 仿真时长: 完整的512x640图像仿真约需要50ms仿真时间

## 依赖项

- Xilinx Vivado (推荐2021.1或更高版本)
- Python 3.x
- Pillow (PIL) Python库: `pip install Pillow`
- NumPy Python库: `pip install numpy`

## 故障排除

### Python依赖安装
```bash
pip install Pillow numpy
```

### Vivado IP生成失败
确保Vivado版本支持blk_mem_gen IP核版本8.4。如果版本不匹配,可在make.tcl中调整版本号。

### 仿真超时
如果图像较大或仿真较慢,可在sim.tcl中增加`run_time`值。

## 许可证

本项目仅供学习和研究使用。
