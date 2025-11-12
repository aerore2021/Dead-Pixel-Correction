# 项目完成检查清单

## ✅ 已完成项目

### 1. 图像转换工具 ✅
- [x] PNG to TXT 转换器 (png_to_txt.py)
- [x] TXT to PNG 转换器 (txt_to_png.py)
- [x] 批量转换脚本 (Linux/Mac/Windows)
- [x] 转换功能测试脚本

### 2. 坏点列表配置 ✅
- [x] 坏点坐标定义: [29,156; 82,132; 82,133; 83,132; 83,133]
- [x] 坐标格式修正: {列[31:16], 行[15:0]}
- [x] manul.v 地址偏移修正
- [x] manul.v 坐标映射修正

### 3. Testbench开发 ✅
- [x] AXI4-Lite写事务实现
- [x] 坏点列表配置流程
- [x] 从文件读取测试图像
- [x] AXI4-Stream图像输入
- [x] AXI4-Stream图像输出
- [x] 输出保存到文件
- [x] 超时保护
- [x] 进度监控

### 4. 源代码修正 ✅
- [x] Axi4LiteSlave_dpc.v wen_lut清零逻辑
- [x] Axi4LiteSlave_dpc.v 读取逻辑完善
- [x] manul.v 坐标映射修正
- [x] manul.v BRAM地址偏移修正

### 5. TCL脚本更新 ✅
- [x] make.tcl 源文件列表更新
- [x] make.tcl BRAM IP配置
- [x] make.tcl 时序约束更新
- [x] sim.tcl 仿真时长调整
- [x] syn.tcl 项目名称更新

### 6. 文档编写 ✅
- [x] README.md 完整项目文档
- [x] QUICKSTART.md 快速入门指南
- [x] SUMMARY.md 项目完善总结
- [x] FPGA_outputs/README.md
- [x] requirements.txt
- [x] .gitignore

### 7. 自动化脚本 ✅
- [x] run_all.sh (Linux/Mac完整流程)
- [x] run_all.bat (Windows完整流程)
- [x] convert_all_images.sh
- [x] convert_all_images.bat

## 使用前准备

### 环境检查
```bash
# 1. 检查Python版本
python --version  # 需要 Python 3.x

# 2. 安装Python依赖
pip install -r requirements.txt

# 3. 测试转换工具
python scripts/test_conversion.py

# 4. 检查Vivado安装
vivado -version
```

### 快速验证步骤

#### 步骤1: 转换测试图像
```bash
# Windows
python scripts\png_to_txt.py image_inputs\dpc_test_1\1.png

# Linux/Mac
python3 scripts/png_to_txt.py image_inputs/dpc_test_1/1.png
```
检查是否生成 `1.txt` 文件

#### 步骤2: 创建项目(可选,可直接用run_all)
```bash
vivado -mode batch -source make.tcl
```
检查是否生成 `DPC_Detector_proj/` 文件夹

#### 步骤3: 运行仿真
```bash
vivado -mode batch -source sim.tcl
```
检查是否生成 `FPGA_outputs/1_out.txt`

#### 步骤4: 转换输出
```bash
# Windows
python scripts\txt_to_png.py FPGA_outputs\1_out.txt -o FPGA_outputs\1_out.png -w 640 -H 512

# Linux/Mac
python3 scripts/txt_to_png.py FPGA_outputs/1_out.txt -o FPGA_outputs/1_out.png -w 640 -H 512
```
检查是否生成 `1_out.png`

### 一键运行
```bash
# Windows
run_all.bat

# Linux/Mac
chmod +x run_all.sh
./run_all.sh
```

## 关键参数配置

### 图像参数
- 宽度: 640像素
- 高度: 512像素
- 位宽: 14位

### 坏点参数
- 数量: 5个
- 坐标: 见tb_DPC_Detector.sv

### 仿真参数
- 时钟频率: 100MHz
- 仿真时长: 50ms
- 完整帧处理: ~3.3ms

## 输出检查

仿真成功后应有:
- ✅ FPGA_outputs/1_out.txt (TXT格式输出)
- ✅ 327,680行数据 (640×512)
- ✅ 每行4位16进制数

转换成功后应有:
- ✅ FPGA_outputs/png/1_out.png
- ✅ 640×512灰度图像
- ✅ 坏点位置被校正

## 可能的问题和解决方案

### 问题1: Python模块未找到
```
错误: ModuleNotFoundError: No module named 'PIL'
解决: pip install Pillow numpy
```

### 问题2: Vivado找不到
```
错误: vivado: command not found
解决: 添加Vivado到PATH或使用完整路径
```

### 问题3: IP核生成失败
```
错误: BRAM IP generation failed
解决: 检查Vivado版本,可能需要调整IP版本号
```

### 问题4: 仿真超时
```
问题: 仿真未完成就超时
解决: 增加sim.tcl中的run_time值
```

### 问题5: 输出文件为空
```
问题: FPGA_outputs/1_out.txt 为空或行数不对
解决: 检查testbench中的IMAGE_INPUT_PATH路径
     检查输入TXT文件是否正确生成
```

## 下一步操作

完成验证后可以:
1. ✅ 对比FPGA输出与Matlab参考输出
2. ✅ 运行所有8个测试用例
3. ✅ 检查坏点校正效果
4. ✅ 运行综合查看资源使用
5. ✅ 优化性能或资源占用

## 项目结构总览

```
FPGA_v2/
├── src/                      # Verilog源文件 ✅
├── sim/                      # 仿真文件 ✅
├── scripts/                  # Python脚本 ✅
├── image_inputs/             # 测试图像 (需准备PNG)
├── FPGA_outputs/             # 输出结果 (仿真生成)
├── make.tcl                  # 项目创建 ✅
├── sim.tcl                   # 仿真脚本 ✅
├── syn.tcl                   # 综合脚本 ✅
├── run_all.sh/.bat           # 自动化脚本 ✅
├── README.md                 # 完整文档 ✅
├── QUICKSTART.md             # 快速入门 ✅
├── SUMMARY.md                # 项目总结 ✅
├── CHECKLIST.md              # 本文件 ✅
├── requirements.txt          # Python依赖 ✅
└── .gitignore                # 版本控制 ✅
```

## 最终确认

- [x] 所有源文件已正确配置
- [x] 坏点列表配置正确
- [x] Testbench完整实现
- [x] 转换工具可用
- [x] TCL脚本更新
- [x] 文档完整
- [x] 自动化脚本就绪

## 🎉 项目完成!

项目已全面完善,可以开始运行仿真验证了!

建议首次运行使用:
```bash
./run_all.sh      # Linux/Mac
run_all.bat       # Windows
```

祝仿真顺利! 🚀
