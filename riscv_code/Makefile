# DPC分离架构项目Makefile
# 用于RISC-V平台的DPC控制软件编译

# 工具链配置
CROSS_COMPILE = riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
SIZE = $(CROSS_COMPILE)size

# 目录配置
SRC_DIR = .
BUILD_DIR = build
VERILOG_DIR = ../verilog_code
DOC_DIR = ../docs

# 源文件
SOURCES = dpc_demo.c \
          dpc_control.c \
          dpc_interrupt.c

HEADERS = dpc_config.h

# 目标文件
OBJECTS = $(SOURCES:%.c=$(BUILD_DIR)/%.o)
TARGET = $(BUILD_DIR)/dpc_demo
TARGET_HEX = $(TARGET).hex
TARGET_BIN = $(TARGET).bin
TARGET_MAP = $(TARGET).map
TARGET_DIS = $(TARGET).dis

# 编译器标志
ARCH_FLAGS = -march=rv32i -mabi=ilp32
CFLAGS = -Wall -Wextra -O2 -g -std=c99 $(ARCH_FLAGS)
CFLAGS += -ffunction-sections -fdata-sections
CFLAGS += -DRISCV_TARGET=1

# 链接器标志
LDFLAGS = $(ARCH_FLAGS) -T linker.ld
LDFLAGS += -Wl,--gc-sections -Wl,-Map=$(TARGET_MAP)
LDFLAGS += -nostartfiles -nostdlib

# 库文件（如果需要的话）
LIBS = -lgcc

# 调试标志
DEBUG_FLAGS = -DDPC_DEBUG_ENABLE=1 -DDPC_DEBUG_VERBOSE=1

# 默认目标
all: $(TARGET_HEX) $(TARGET_BIN) $(TARGET_DIS)

# 创建构建目录
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# 编译源文件
$(BUILD_DIR)/%.o: %.c $(HEADERS) | $(BUILD_DIR)
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# 链接目标文件
$(TARGET): $(OBJECTS) linker.ld
	@echo "Linking $@..."
	$(CC) $(LDFLAGS) $(OBJECTS) $(LIBS) -o $@
	$(SIZE) $@

# 生成HEX文件
$(TARGET_HEX): $(TARGET)
	@echo "Creating HEX file $@..."
	$(OBJCOPY) -O ihex $< $@

# 生成二进制文件
$(TARGET_BIN): $(TARGET)
	@echo "Creating binary file $@..."
	$(OBJCOPY) -O binary $< $@

# 生成反汇编文件
$(TARGET_DIS): $(TARGET)
	@echo "Creating disassembly file $@..."
	$(OBJDUMP) -D $< > $@

# 调试版本
debug: CFLAGS += $(DEBUG_FLAGS)
debug: clean all

# 发布版本
release: CFLAGS += -DNDEBUG -Os
release: clean all

# 清理
clean:
	@echo "Cleaning build files..."
	rm -rf $(BUILD_DIR)

# 深度清理
distclean: clean
	rm -f *.hex *.bin *.map *.dis

# 安装（复制到目标目录）
install: all
	@echo "Installing to target system..."
	@mkdir -p /tmp/dpc_install
	cp $(TARGET_HEX) /tmp/dpc_install/
	cp $(TARGET_BIN) /tmp/dpc_install/
	@echo "Installation complete"

# 代码分析
analyze:
	@echo "Running code analysis..."
	@which cppcheck > /dev/null && cppcheck --enable=all $(SOURCES) || echo "cppcheck not found"
	@which splint > /dev/null && splint $(SOURCES) || echo "splint not found"

# 代码格式化
format:
	@echo "Formatting code..."
	@which clang-format > /dev/null && clang-format -i $(SOURCES) $(HEADERS) || echo "clang-format not found"

# 生成文档
docs:
	@echo "Generating documentation..."
	@mkdir -p $(DOC_DIR)
	@which doxygen > /dev/null && doxygen Doxyfile || echo "doxygen not found"

# 显示项目信息
info:
	@echo "DPC Separated Architecture Project"
	@echo "=================================="
	@echo "Sources: $(SOURCES)"
	@echo "Headers: $(HEADERS)"
	@echo "Target: $(TARGET)"
	@echo "Compiler: $(CC)"
	@echo "Flags: $(CFLAGS)"
	@echo ""
	@echo "Available targets:"
	@echo "  all      - Build all targets"
	@echo "  debug    - Build debug version"
	@echo "  release  - Build release version"
	@echo "  clean    - Clean build files"
	@echo "  install  - Install to target"
	@echo "  analyze  - Run code analysis"
	@echo "  format   - Format source code"
	@echo "  docs     - Generate documentation"
	@echo "  test     - Run tests"
	@echo "  sim      - Run simulation"

# 测试目标
test: all
	@echo "Running tests..."
	@echo "Note: Hardware tests require actual FPGA hardware"
	@echo "Running software-only tests..."
	# 这里可以添加软件测试脚本

# 仿真目标
sim: all
	@echo "Running FPGA simulation..."
	@echo "Note: This requires Vivado or ModelSim"
	@cd $(VERILOG_DIR) && make sim

# FPGA综合和实现
fpga: 
	@echo "Running FPGA build..."
	@cd $(VERILOG_DIR) && make fpga

# 完整构建（软件+硬件）
full: fpga all
	@echo "Full build completed"

# 帮助信息
help: info

# 防止文件名冲突
.PHONY: all debug release clean distclean install analyze format docs info test sim fpga full help

# 依赖关系
$(BUILD_DIR)/dpc_demo.o: dpc_demo.c dpc_config.h
$(BUILD_DIR)/dpc_control.o: dpc_control.c dpc_config.h
$(BUILD_DIR)/dpc_interrupt.o: dpc_interrupt.c dpc_config.h

# 自动生成依赖关系
-include $(OBJECTS:.o=.d)

$(BUILD_DIR)/%.d: %.c | $(BUILD_DIR)
	@$(CC) $(CFLAGS) -MM -MT $(@:.d=.o) $< > $@
