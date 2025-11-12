# 快速入门指南

## 前置要求

1. **Xilinx Vivado** (推荐2021.1或更高版本)
2. **Python 3.x**
3. **Python库**: Pillow和NumPy

安装Python依赖:
```bash
pip install -r requirements.txt
```

## 快速开始 (一键运行)

### Windows用户
双击运行 `run_all.bat` 或在命令行中:
```cmd
run_all.bat
```

### Linux/Mac用户
```bash
chmod +x run_all.sh
./run_all.sh
```

这将自动完成:
1. 转换PNG图像到TXT格式
2. 创建Vivado项目
3. 运行仿真
4. 转换输出TXT到PNG格式

## 分步执行

如果需要分步控制,请按以下步骤操作:

### 步骤1: 准备测试图像

转换PNG到TXT:
```bash
# Windows
python scripts\png_to_txt.py -a image_inputs\dpc_test_1

# Linux/Mac
python3 scripts/png_to_txt.py -a image_inputs/dpc_test_1
```

### 步骤2: 创建Vivado项目

```bash
vivado -mode batch -source make.tcl
```

### 步骤3: 运行仿真

```bash
vivado -mode batch -source sim.tcl
```

### 步骤4: 查看结果

转换输出TXT到PNG:
```bash
# Windows
python scripts\txt_to_png.py FPGA_outputs\1_out.txt -o FPGA_outputs\1_out.png -w 640 -H 512

# Linux/Mac
python3 scripts/txt_to_png.py FPGA_outputs/1_out.txt -o FPGA_outputs/1_out.png -w 640 -H 512
```

## 坏点配置

当前配置的坏点列表 (行, 列):
- [29, 156]
- [82, 132]
- [82, 133]
- [83, 132]
- [83, 133]

要修改坏点列表,编辑 `sim/tb_DPC_Detector.sv` 中的以下部分:
```systemverilog
parameter NUM_BAD_PIXELS = 5;

initial begin
    bad_pixels[0] = {16'd156, 16'd29};   // [29, 156]
    bad_pixels[1] = {16'd132, 16'd82};   // [82, 132]
    // ... 添加更多坏点
end
```

注意: 坏点格式为 `{列[31:16], 行[15:0]}`

## 运行综合

如需要综合设计:
```bash
vivado -mode batch -source syn.tcl
```

## 故障排除

### Python模块未找到
```bash
pip install Pillow numpy
```

### Vivado找不到
确保Vivado已添加到系统PATH,或使用完整路径:
```bash
# Windows示例
"C:\Xilinx\Vivado\2021.1\bin\vivado.bat" -mode batch -source make.tcl

# Linux示例
/opt/Xilinx/Vivado/2021.1/bin/vivado -mode batch -source make.tcl
```

### 仿真超时
编辑 `sim.tcl`,增加运行时间:
```tcl
set run_time 100ms  # 从50ms增加到100ms
```

### IP核生成失败
检查Vivado版本是否支持blk_mem_gen IP v8.4。如不支持,在 `make.tcl` 中修改版本号。

## 测试图像

测试图像位于 `image_inputs/dpc_test_*/` 文件夹中。

每个测试文件夹应包含:
- `*.png`: 原始测试图像
- `*.txt`: 转换后的文本格式(运行转换脚本后生成)

## 输出结果

仿真结果保存在 `FPGA_outputs/` 文件夹:
- TXT格式的原始输出
- 转换后的PNG图像(在 `png/` 子文件夹)

## 获取帮助

查看完整文档: `README.md`

查看各脚本的帮助信息:
```bash
python scripts/png_to_txt.py --help
python scripts/txt_to_png.py --help
```
