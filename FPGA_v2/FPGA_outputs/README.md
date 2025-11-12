# FPGA Outputs

此文件夹用于存放FPGA仿真输出的结果文件。

## 文件格式

- **TXT格式**: 仿真直接输出的原始格式,每行一个16进制像素值
- **PNG格式**: 转换后的图像文件,存放在 `png/` 子文件夹中

## 目录结构

```
FPGA_outputs/
├── README.md          # 本文件
├── *.txt              # 仿真输出的TXT文件
└── png/               # 转换后的PNG图像
    └── *.png
```

## 使用说明

仿真完成后,使用以下命令将TXT文件转换为PNG:

```bash
# 单个文件转换
python scripts/txt_to_png.py FPGA_outputs/1_out.txt -o FPGA_outputs/png/1_out.png -w 640 -H 512

# 批量转换
python scripts/txt_to_png.py -a FPGA_outputs/ -o FPGA_outputs/png/ -w 640 -H 512
```

或者运行完整流程脚本,它会自动进行转换:
```bash
bash run_all.sh        # Linux/Mac
run_all.bat            # Windows
```
