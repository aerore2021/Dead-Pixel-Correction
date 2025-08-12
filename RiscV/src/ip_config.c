#include "ip_config.h"
#define mem0 ((volatile uint16_t*)SENSOR_BUF_ADDR)
#define mem1 ((volatile uint16_t*)0x10d00000)
#define size 640*512


void writeReg(uint32_t base_addr, uint32_t offset, uint32_t data)
{
	uint32_t base = base_addr;
	uint32_t addr = base + offset * 4;
	write_u32(data, addr);
}

uint32_t readReg(uint32_t base_addr, uint32_t offset)
{
	uint32_t base = base_addr;
	uint32_t addr = base + offset * 4;
	uint32_t read = read_u32(addr);
	return read;
}

void setGo(uint32_t base_addr, uint32_t g)
{
	writeReg(base_addr, 0, g);
}
void setMode(uint32_t base_addr, uint32_t m)
{
	writeReg(base_addr, 1, m);
}
void setWidth(uint32_t base_addr, uint32_t w)
{
	writeReg(base_addr, 2, w);
}
void setHeight(uint32_t base_addr, uint32_t h)
{
	writeReg(base_addr, 3, h);
}
void setBaseaddr(uint32_t base_addr, uint32_t a)
{
	writeReg(base_addr, 4, a);
}
void setDpcThreshold(uint32_t base_addr, uint32_t a)
{
	writeReg(base_addr, 2, a);
}
void setDpcSmooth(uint32_t base_addr, uint32_t a)
{
	writeReg(base_addr, 3, a);
}
void setSfilterGo(uint32_t base_addr, uint32_t go)
{
	writeReg(base_addr, 0, (readReg(base_addr, 0) & (~0x1)) | (go & 0x1));
}
void setSfilterMode(uint32_t base_addr, uint32_t mode)
{
	writeReg(base_addr, 0, (readReg(base_addr, 0) & (~0x2)) | ((mode & 0x1) << 1));
}
void setSfilterLut(uint32_t base_addr, float h) // 旧时域查找表(aka 新新时域)
{
	 for (uint32_t i = 1; i < 512; i++) {
	 	uint16_t j;
	 	j = exp(i / (-h)) * 65536;
	 	writeReg(base_addr, i, j);
	 }

}
void setTfilterLut(uint32_t base_addr, float h)
{
	for (uint32_t i = 1; i <= (uint32_t) h+1; i++) {
		uint16_t j;
		if (i <= 6)
			j = 65535;
		else {
			double temp = (double)(i-6)/(double)(h-5);
			j = 65535 - 65535*pow(temp,0.3);
		}
		writeReg(base_addr, i, j);
	}
}

void setDiffMulEXP(uint32_t base_addr, float h)
{
	for (uint32_t i = 0; i < 1024; i++) {
		uint16_t j1;
		uint16_t j2;
		j1 = exp(2*2*i*i / (-2*h*h)) * 65536;
		if (i == 0){
			j1 = 65535;
		}
		j2 = 2*i*exp(2*2*i*i / (-2*h*h))*32;
		writeReg(base_addr, 2048 + i, (j1 << 16) | j2);
	}
}

void setGammaLut_8bit(uint32_t base_addr, float gamma)
{
    for (uint32_t i = 0; i < 256; i++) {
        uint8_t j;
        float normalized = (float)i / 255.0f;
        if (i == 0) {
            j = 0;
        } else {
            j = pow(normalized, gamma) * 255.0f + 0.5f; // 映射到8位
        }
        writeReg(base_addr, i, j);
    }
}

// 串口初始化
void systemInit(){
    //UART Init
    Uart_Config uartA;
    uartA.dataLength = BITS_8;
    uartA.parity = NONE;
    uartA.stop = ONE;
    uartA.clockDivider = CORE_HZ / (UART_BAUD_RATE * UART_A_SAMPLE_PER_BAUD) - 1;
    uart_applyConfig(BSP_UART_TERMINAL, &uartA);

	// TX FIFO empty interrupt enable
	//uart_TX_emptyInterruptEna(BSP_UART_TERMINAL,1);

	// RX FIFO not empty interrupt enable
    uart_RX_NotemptyInterruptEna(BSP_UART_TERMINAL,1);

	//configure PLIC
    //cpu 0 accept all interrupts with priority above 0
	plic_set_threshold(BSP_PLIC, BSP_PLIC_CPU_0, 0);

	//enable SYSTEM_PLIC_USER_INTERRUPT_A_INTERRUPT rising edge interrupt
	plic_set_enable(BSP_PLIC, BSP_PLIC_CPU_0, SYSTEM_PLIC_SYSTEM_UART_0_IO_INTERRUPT, 1);
	plic_set_priority(BSP_PLIC, SYSTEM_PLIC_SYSTEM_UART_0_IO_INTERRUPT, 1);

	//enable interrupts
	csr_write(mtvec, trap_entry); 	// Set the machine trap vector (../common/trap.S)
	csr_set(mie, MIE_MEIE); 		// Enable external interrupts
	csr_write(mstatus, MSTATUS_MPP | MSTATUS_MIE);


}


// fpga初始化
uint8_t* fpgaInit() {
#if USE_K

	readFrameFromFlash(StartAddress_K, 0x10B00000);// k全写1的时候注释

#else
	for(int i=0;i<MAX_WORDS;i++) {
	 	mem[i] = 0x10001000;
	}
#endif

	DelayMsec(1000);
	readFrameFromFlash(GUOGAI_SLOPE_Address, 0x10800000);
	readFrameFromFlash(0x6C0000, 0x10900000);

	param = readParamFromFlash(PARAM_Address);
	memcpy(param_r,param,4096);
	// 清空缓存
	memset((void *)DISP_BUF_ADDR, 0, DISPLAY_WIDTH * DISPLAY_HEIGHT * 2 * 3);
	memset((void*) SENSOR_BUF_ADDR, 0, DISPLAY_WIDTH * DISPLAY_HEIGHT * 2 * 3);
	memset((void*) TESTB_BUF_ADDR, 0, RAW_WIDTH * RAW_HEIGHT * 2 * 3);
	memset((void*) 0x12000000, 0, 1024*768*2*3);

	setMode(READER0_ADDR, 0);
	setWidth(READER0_ADDR, RAW_WIDTH);
	setHeight(READER0_ADDR, RAW_HEIGHT);
	setBaseaddr(READER0_ADDR, SENSOR_BUF_ADDR);

	setMode(WRITER0_ADDR, 0);
	setWidth(WRITER0_ADDR, RAW_WIDTH);
	setHeight(WRITER0_ADDR, RAW_HEIGHT);
#if USE_TESTPATTERN
	setBaseaddr(WRITER0_ADDR, 0x23000000);
#else
	setBaseaddr(WRITER0_ADDR, SENSOR_BUF_ADDR);
#endif

#if USE_TESTPATTERN

	uint16_t num = 0;
	uint16_t a = 256;
	uint16_t b = 0;
	for (uint16_t f = 0; f < 3; f++) {
		for (uint16_t j = 0; j < 512; j++){
			for (uint16_t i = 0; i < 640; i++){
				if(i<100){
					num = 1000;
				}
				else {
					num = 5000;
				}
//				num = (i%a)<<2;
				mem0[f*720*576+j*720+i] = num;

			}
		}
	}

#endif

	setMode(READER2_ADDR, 0);
	setWidth(READER2_ADDR, DISPLAY_WIDTH);
	setHeight(READER2_ADDR, DISPLAY_HEIGHT);
	setBaseaddr(READER2_ADDR, 0x12000000);

	setMode(WRITER2_ADDR, 0);
	setWidth(WRITER2_ADDR, DISPLAY_WIDTH);
	setHeight(WRITER2_ADDR, DISPLAY_HEIGHT);
	setBaseaddr(WRITER2_ADDR, 0x12000000);

	// 挡片
	writeReg(SHUTTER_ADDR, 0, 0x00010002);
	writeReg(SHUTTER_ADDR, 1, 800000000);
	writeReg(SHUTTER_ADDR, 2, 0xAD274800);

	writeReg(SHUTTER_ADDR, 3, 0);

	// 本底
	writeReg(SAMPLE_BACKGROUND_ADDR, 1, 0x10C00000);
	writeReg(SAMPLE_BACKGROUND_ADDR, 2, 0x11000000);

	// NUC

#if USE_TESTPATTERN
	writeReg(NUC_ADDR, 1, 0x00000000);
	writeReg(NUC_ADDR, 2, 0x10d00000);
#else

	u32 low_b,temp_low,temp_high;
	low_b = (param_r[3408] << 8) | param_r[3409];
	temp_low = (param_r[3428] << 8) | param_r[3429];
	temp_high = (param_r[3430] << 8) | param_r[3431];
	DelayMsec(1000);

	u32 temp = (temp_high << 16) | temp_low;

	writeReg(NUC_ADDR, 0, temp);


	writeReg(NUC_ADDR, 1, (low_b << 16) | 0x00002000);

//	writeReg(NUC_ADDR, 2, 0x11000000);//1帧
	writeReg(NUC_ADDR, 2, 0x10C00000);//8帧

#endif
	writeReg(NUC_ADDR, 3, 0x10B00000);

	// DPC
	uint16_t param_dpc;
	u8 count_manual;

	param_dpc = (param_r[0] << 8) | param_r[1];
	count_manual = param_r[3432];
	setDpcThreshold(DPC0_ADDR, param_dpc);
	setDpcSmooth(DPC0_ADDR, 0);
	writeReg(DPC0_ADDR, 1, count_manual);

	u32 col,row;

	for(int i=0;i<128;i++){
		row = param_r[3433+i*4] << 8 | param_r[3433+1+i*4];
		col = param_r[3433+2+i*4] << 8 | param_r[3433+3+i*4];
		writeReg(DPC0_ADDR, i+4, col<<16 | row);

	}


	// TF
	uint32_t alpha;
	uint32_t h;
	alpha = (param_r[12] << 8) | param_r[13];
	h = param_r[14];

	writeReg(TF_ADDR, 0, 0);
	setTfilterLut(TF_ADDR, h & 0xFFFF);// 写入LUT
	writeReg(TF_ADDR, 0, h<<16|alpha<<8|1);	// 启动时域滤波


	// FPN
	uint16_t threshold1;
	uint8_t threshold2;
	u32 threshold_edge;

	threshold1 = (param_r[6] << 8) | param_r[7];
	threshold2 = param_r[3415];
	threshold_edge = (param_r[3416] << 8) | param_r[3417];

	writeReg(CFPN_ADDR, 1, threshold1 & 0xFFFF);
	writeReg(CFPN_ADDR, 2, threshold2 & 0xFF);
	writeReg(CFPN_ADDR, 3, threshold_edge);


	// NLM
	uint16_t param_nlm;
	param_nlm = (param_r[8] << 8) | param_r[9];

	setSfilterMode(NLM0_ADDR, 1);  // 1是7x7
	setSfilterLut(NLM0_ADDR, param_nlm);

	// dde
	u32 per_sum = (param_r[3945] << 8) | param_r[3946];
	u32 per_sum_max = (param_r[3947] << 8) | param_r[3948];

	u32 per_sum_min = (param_r[3949] << 8) | param_r[3950];
	u16 limit_clahe = (param_r[3951] << 8) | param_r[3952];

	u16 rate = param_r[3953];
	u16 G_min = param_r[3954];
	u16 G_max = param_r[3955];

	u16 frame_mean_num = param_r[3956];
	u16 thres_uniform = (param_r[3957]<<8)|param_r[3958];
	u16 clahe_go = param_r[3959];

	u16 merge_rate_ori = 32;

	u32 p0 = (per_sum << 16) | per_sum_max;
	u32 p1 = (per_sum_min << 16)| limit_clahe;
	u32 p2 = (G_max << 10) | (G_min << 5) | rate;
	u32 p3 = (merge_rate_ori << 19)|(clahe_go << 18)|(thres_uniform << 7) | frame_mean_num;

	writeReg(STRETCH_ADDR,0,p0);
	writeReg(STRETCH_ADDR,1,p1);
	writeReg(STRETCH_ADDR,2,p2);
	writeReg(STRETCH_ADDR,3,p3);

	// gamma
	u16 gamma = param_r[3960];
	setGammaLut_8bit(GAMMA_ADDR,gamma / 128.0f);
	setGammaLut_8bit(GAMMA_ADDR2,1.3);

	setDiffMulEXP(STRETCH_ADDR, 200);

	//工作点
	for(int i=0;i<14;i++){
		config[i] = (param_r[3352+i*4] << 24) 	|
					(param_r[3352+i*4+1] << 16)	|
					(param_r[3352+i*4+2] << 8)	|
					(param_r[3352+i*4+3]);
		writeReg(SENSOR_ADDR, i, config[i]);

	}

	// 伪彩色，默认白热
	for(int i = 0;i < 3;i++) {
		writeReg(PSEUDO_COLOR_ADDR, 255, i);
		for (int j = 0;j < 256;j++) {
			if(i==0)
				writeReg(PSEUDO_COLOR_ADDR, j, j);
			else
				writeReg(PSEUDO_COLOR_ADDR, j, 0x80);

		}
	}



	//READER0
	setGo(READER2_ADDR, 1);
	setGo(WRITER2_ADDR, 1);

	//白热+十字丝
	writeReg(MISC_ADDR, 0, 0);

	writeReg(MISC_ADDR, 1, 01000120);

	//画中画
	writeReg(MISC_ADDR, 2, 0);

	//scaler
	writeReg(ZOOM_ADDR, 0, 0x02800200);//x1
	writeReg(CLIPPER_ADDR, 0, 0);
	writeReg(CLIPPER_ADDR, 1, 639);
	writeReg(CLIPPER_ADDR, 2, 0);
	writeReg(CLIPPER_ADDR, 3, 511);

	//对比度
	writeReg(CONTRAST_ADDR, 0, 0);
	writeReg(CONTRAST_ADDR, 1, 192);

	//亮度
	writeReg(BRIGHTNESS_ADDR, 0, 0);
	writeReg(BRIGHTNESS_ADDR, 1, 100);

	//画面移位
	u32 x_offset = (param_r[3410] << 8) | param_r[3411];
	u32 y_offset = (param_r[3412] << 8) | param_r[3413];

	writeReg(TRANSLATION_ADDR, 0, x_offset);
	writeReg(TRANSLATION_ADDR, 1, y_offset);

	//usm
	setGo(USM0_ADDR, 1);

	//时域
	setSfilterGo(NLM0_ADDR, 1);

	//CFPN
	setGo(CFPN_ADDR, 1);

	//DPC
	setGo(DPC0_ADDR, 1);

	//READER0
	setGo(READER0_ADDR, 1);
	setGo(WRITER0_ADDR, 1);

	return param_r;
	}

