/*
 * efinity 下位机 v0.5
 * written by ivlab
 *
 */
// 系统头文件
#include "stdint.h"
#include "plic.h"
#include "clint.h"
#include "bsp.h"
#include "riscv.h"
#include "string.h"
#include "stdio.h"
#include "math.h"
// 自定义头文件
#include "transmit.h"
#include "ip_config.h"
#include "utils.h"
#include "my_uart.h"
#include "lut_data.h"
#include "parameters_efinity.h"
#include "preprocess_data.h"
#include "readFlash.h"


void main() {

	// 初始化
	systemInit();
	uint8_t* param_w = (uint8_t*)malloc(sizeof(uint8_t)*4096);
	param_w = fpgaInit();

	// 局部变量定义
    u8 	msg             = 0xF2;             // 指令类型, 具有唯一性, 主要通过该位识别指令类型.
    u16 idx				= 0;				// 当前已读取的下标
	u16 state_machine   = 0;                // 状态机的当前状态
	u16 data_length     = 0;                // 接收的上位机指令中的数据的长度
	u16 crc_res        = 0;                // CRC的结果(用于校验指令传输过程中是否出错)
	u16 count           = 0;                // 实际读取长度(临时变量, 读取已知长度的数据时使用, 用于计数)
	u16 read_len        = 0;                // 应该读取的数据的长度(临时变量, 读取已知长度的数据时使用, 用于限制范围)
	u16 clock_cnt		= 0;				// 计数器(计数,处理指令重复/缺失的情况)
	u8 pack[UART_BUF_LEN];					// 保存数据的数组
	u8 crc_respond[7];						//CRC校验的返回值
	uint8_t hex[4096];						// 更新固件暂存数组
	s16* mean_cold = (u16*)malloc(sizeof(u16)*RAW_WIDTH*RAW_HEIGHT);
	s16* dpc_cold = (u16*)malloc(sizeof(u16)*RAW_WIDTH*RAW_HEIGHT);
	s16* mean_hot = (u16*)malloc(sizeof(u16)*RAW_WIDTH*RAW_HEIGHT);
	s16* dpc_hot = (u16*)malloc(sizeof(u16)*RAW_WIDTH*RAW_HEIGHT);

	// 数组初始化
	memset(rx_buf, '*', UART_BUF_LEN);
	// 死循环
	while(1){
		idx = 0;
		msg = 0xF2;
		state_machine = 0;
		data_length = 0;
		crc_res = 0;
		count = 0;
		read_len = 0;
		clock_cnt = 0;
		while(1) {
			if(state_machine == 0 && rx_idx > idx) {
				// 包头 0x6E
				if(rx_buf[idx] == UART_SOP) {
					state_machine += 1;
					idx++;
				}
				else {
					badOrderHandler(&idx, &rx_idx, rx_buf);
				}
			}
			else if(state_machine == 1 && rx_idx > idx) {
				// 保留位 0x00
				if(rx_buf[idx] == 0x00){
					state_machine += 1;
					idx++;
				}
				else {
					state_machine = 0; // 帧头未校验通过, 重置状态机.
					badOrderHandler(&idx, &rx_idx, rx_buf);
				}
				clock_cnt++;
				if(clock_cnt > UART_TIMEOUT_COUNT) {
					state_machine = 0;
					clock_cnt = 0;
				}
			}
			else if(state_machine == 2 && rx_idx > idx) {
				// 保留位 0x00
				if(rx_buf[idx] == 0x00){
					state_machine += 1;
					idx++;
				}
				else {
					state_machine = 0; // 帧头未校验通过, 重置状态机.
					badOrderHandler(&idx, &rx_idx, rx_buf);
				}
				clock_cnt++;
				if(clock_cnt > UART_TIMEOUT_COUNT) {
					state_machine = 0;
					clock_cnt = 0;
				}
			}
			else if(state_machine == 3 && rx_idx > idx) {
				// 将指令类型存放在变量msg中
				msg = rx_buf[idx];
				state_machine += 1;
				idx++;
				clock_cnt++;
				if(clock_cnt > UART_TIMEOUT_COUNT) {
					state_machine = 0;
					clock_cnt = 0;
				}
			}
			else if(state_machine == 4 && rx_idx > idx + 1) {
				// 接收表示数据长度的数据:2个字节.第1个字节为数据长度的高8位,第2个字节为数据长度的低8位.
				// 数据长度的结果保存在data_length中.
				count = 0;
				read_len = 2;
				while (count != read_len) {
					if(count == 0)
						data_length |= (rx_buf[idx] << 8);
					else
						data_length |= rx_buf[idx];
					count++;
					idx++;
				}
				if(count == read_len){
					state_machine += 1;
				}
				else {
					state_machine = 0;
					badOrderHandler(&idx, &rx_idx, rx_buf);
				}
				clock_cnt++;
				if(clock_cnt > UART_TIMEOUT_COUNT) {
					state_machine = 0;
					clock_cnt = 0;
				}
			}
			else if(state_machine == 5 && rx_idx > idx + 1) {
				// 接收前6位数据CRC校验的结果:2个字节.第1个字节为CRC的高8位,第2个字节为CRC的低8位.
				// CRC结果保存在crcVaule中.
				count = 0;
				read_len = 2;
				crc_res = 0;
				while (count != read_len) {
					if(count == 0)
						crc_res |= (rx_buf[idx] << 8);
					else
						crc_res |= rx_buf[idx];
					count++;
					idx++;
				}
				// CRC校验
				u16 crc_res = doCrc(rx_buf,idx);
				// 如果已经读完数据, 并且CRC校验的结果正确 && crc_res == 0
				if(count == read_len) {
					state_machine += 1;
				}
				else {
					state_machine = 0;
					badOrderHandler(&idx, &rx_idx, rx_buf);
				}
				clock_cnt++;
				if(clock_cnt > UART_TIMEOUT_COUNT) {
					state_machine = 0;
					clock_cnt = 0;
				}
			}
			else if(state_machine == 6 && rx_idx > idx + data_length - 1) {
				// 接收数据, 将接收到的数据保存在pack数组中
				count = 0;
				while (count != data_length) {
					pack[count] = rx_buf[idx];
					count++;
					idx++;
				}
				if(count == data_length) {
					state_machine += 1;
				}
				else {
					state_machine = 0;
					badOrderHandler(&idx, &rx_idx, rx_buf);
				}
				clock_cnt++;
				if(clock_cnt > UART_TIMEOUT_COUNT) {
					state_machine = 0;
					clock_cnt = 0;
				}
			}
			else if(state_machine == 7 && rx_idx > idx + 1) {
				// 接收所有数据CRC校验的结果: 2个字节. 第1个字节为CRC的高8位, 第2个字节为CRC的低8位.
				count = 0;
				read_len = 2;
				crc_res = 0;
				while (count != read_len) {
					if(count == 0)
						crc_res |= (rx_buf[idx] << 8);
					else
						crc_res |= rx_buf[idx];
					count++;
					idx++;
				}
				clock_cnt++;
				if(clock_cnt > UART_TIMEOUT_COUNT) {
					state_machine = 0;
					clock_cnt = 0;
				}
				// 作CRC校验
				u16 crc_res = doCrc(rx_buf,idx);
				// 如果所有数据都没有问题, 那么我们需要根据不同的情况进行相应的操作.
				if(count == read_len) {
					// 回复长度, 如果为0则不回复, 注意设置!
					u16 WriteLength = idx;
					switch (msg){
						// 如果msg为0xF2, 表示该指令为无效指令, 不做任何处理.
						case 0xF2: break;
						// 握手信号
						case CAMERA_CONNECT: {

							break;
						}
						// 获取软件版本
						case SOFTWARE_VERSION: {
							rx_buf[8] = VER_MAJOR;
							rx_buf[9] = VER_MINOR;
							rx_buf[10] = VER_PATCH;
							break;
						}
						// 自动坏点校正(DPC)
						case AutoFindBp: {
							// 指令类型
							u8 order_type = rx_buf[9];
							// 坏点查找阈值, 范围为[0,100]
							u32 badpoint_threshold = (((u32)rx_buf[10] << 8) + (u32)rx_buf[11]);
							// 关闭自动坏点替换
							if(order_type == 0) {
								writeReg(DPC0_ADDR, 2, badpoint_threshold);
							}
							// 修改坏点替换阈值, 启动自动坏点替换
							else {
								writeReg(DPC0_ADDR, 2, badpoint_threshold);
							}

							// 把参数写进flash
							param_w[0] = rx_buf[10];
							param_w[1] = rx_buf[11];

							writeParamToFlash(param_w,PARAM_Address);

							break;

						}
						// 手动坏点校正(DPC), 46
						case HandFindBp: {
							// 指令类型
							u8 order_type = rx_buf[8];
							// 坏点位置坐标
							u32 row = (((u32)rx_buf[9] << 8) + (u32)rx_buf[10]);
							u32 col = (((u32)rx_buf[11] << 8) + (u32)rx_buf[12]);
							u8 count_manual = param_w[3432];

							if(order_type == 0) {
								for(int i=0;i<128;i++){
									writeReg(DPC0_ADDR, i+4, 0xFFFFFFFF);
								}
							}
							// 打开手动去坏点并写入flash和ddr
							else if(order_type == 1){
								writeReg(DPC0_ADDR, count_manual+4, col<<16 | row);
								param_w[3433+count_manual*4] = rx_buf[9];
								param_w[3433+1+count_manual*4] = rx_buf[10];
								param_w[3433+2+count_manual*4] = rx_buf[11];
								param_w[3433+3+count_manual*4] = rx_buf[12];
								count_manual = count_manual + 1;
							}
							else{
								// 其他类型指令，清除所有坏点坐标
								count_manual = 0;
								for(int i=0;i<128;i++){
									for(int j = 0;j<4;j++){
										param_w[3433+j+i*4] = 0xFF;
									}
									writeReg(DPC0_ADDR, i+4, 0xFFFFFFFF);
								}
							}

							writeReg(DPC0_ADDR, 1, count_manual);
							param_w[3432] = count_manual;

							writeParamToFlash(param_w,PARAM_Address);

							break;


						}
						// 自动标定坏点(DPC)，56
						case AutoCaliBp: {

							// 坏点阈值和坐标
							u32 threshold = rx_buf[8] << 8 | rx_buf[9];
							u8 max_count = rx_buf[10];
							u8 count_manual = param_w[3432];

							for(int i=0;i<MAX_WORDS;i++) {
							 	u32 data = TFilter_ADDR[i];
							 	u16 data_part;
							 	data_part = ((data >> 16) & 0xFFFF) >> 2;
							 	cold[2*(i+RAW_WIDTH)+1] = data_part;
							 	data_part = (data & 0xFFFF) >> 2;
							 	cold[2*(i+RAW_WIDTH)] = data_part;
							}

							int bad_count = 0;
							// 限制最多返回100个坏点
							u32* bad_points = find_bad_points(cold+2*RAW_WIDTH, RAW_WIDTH, RAW_HEIGHT, threshold, max_count, &bad_count);


							for(int i=0;i<bad_count;i++){
								writeReg(DPC0_ADDR, count_manual+4, bad_points[i]);
								param_w[3433+count_manual*4] = (bad_points[i]>>8) & 0xFF;
								param_w[3433+1+count_manual*4] = bad_points[i] & 0xFF;
								param_w[3433+2+count_manual*4] = (bad_points[i]>>24) & 0xFF;
								param_w[3433+3+count_manual*4] = (bad_points[i]>>16) & 0xFF;
								count_manual = count_manual + 1;
							}

							writeReg(DPC0_ADDR, 1, count_manual);
							param_w[3432] = count_manual;

							writeParamToFlash(param_w,PARAM_Address);



							break;



						}
						// 细节增强(USM)
						case SPATIAL_THRESHOLD: {
							// 指令类型
							u8 order_type = rx_buf[8];
							// usm参数
							u32 amount_numerator = rx_buf[9];
							u32 amount_denominator = rx_buf[10];
							u32 threshold_highfreq = rx_buf[11];
							u32 threshold_sobel = rx_buf[12];

							// 关闭
							if(order_type == 0) {
								writeReg(USM0_ADDR, 1, 0);
							}
							// 启动细节增强
							else if(order_type == 1) {
								writeReg(USM0_ADDR, 1, amount_numerator);
								writeReg(USM0_ADDR, 2, amount_denominator);
								writeReg(USM0_ADDR, 3, threshold_highfreq);
								writeReg(USM0_ADDR, 4, threshold_sobel);

							}


							// 把参数写进flash
							param_w[2] = amount_numerator;
							param_w[3] = amount_denominator;
							param_w[4] = threshold_highfreq;
							param_w[5] = threshold_sobel;


							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						// 竖条纹消除(CFPN)
						case SFILTER:{
							// 指令类型
							u8 order_type = rx_buf[8];
							// 滤波阈值1
							u32 threshold1 = (rx_buf[9]<<8)| rx_buf[10];
							// 滤波阈值2
							u32 threshold2 = rx_buf[11];
							// 关闭竖条纹消除IP
							u16 threshold_edge = (rx_buf[12] << 8) | rx_buf[13];
							if(order_type == 0) {
								writeReg(CFPN_ADDR, 1, 0);
								writeReg(CFPN_ADDR, 2, 0);
								writeReg(CFPN_ADDR, 3, 0);
							}
							// 启动竖条纹消除IP
							else if(order_type == 1) {
								writeReg(CFPN_ADDR, 1, threshold1);
								writeReg(CFPN_ADDR, 2, threshold2);
								writeReg(CFPN_ADDR, 3, threshold_edge);
								setGo(CFPN_ADDR, 1);
							}

							// 把参数写进flash
							param_w[6] = rx_buf[9];
							param_w[7] = rx_buf[10];
							param_w[3415] = rx_buf[11];
							param_w[3416] = rx_buf[12];
							param_w[3417] = rx_buf[13];

							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						// 空域滤波(NLM)
						case BFILTER: {
							// 指令类型
							u8 order_type = rx_buf[8];
							// 平滑参数h, 范围为[0,500]
							u16 h = ((u16)rx_buf[9]) * 2;
							// 停止空域滤波
							if(order_type == 0) {
								for(int i = 1; i < RAW_HEIGHT; i++){
									writeReg(NLM0_ADDR, i, 0);
								}
							}
							// 启动空域滤波
							else if(order_type == 1) {
								setSfilterLut(NLM0_ADDR, h);
							}

							// 把参数写进flash
							param_w[8] = (h >> 8) & 0xFF;
							param_w[9] = h & 0xFF;

							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						// 限制对比度的自适应直方图均衡(CLAHE)
						case CLAHEENABLE: {
							// 指令类型
							u8 order_type = rx_buf[8];
							// AGC限制值(映射到[0,2000])
							u16 AGCLimit = ((u16)rx_buf[9]) * 20;
							// 关闭AGC
							if(order_type == 0)
								writeReg(CLAHE_ADDR, 0, 0);
							// 启动AGC
							else if(order_type == 1) {
								// 配置参数：AGC限制值
								writeReg(CLAHE_ADDR, 1, AGCLimit);
								// 启动AGC
								writeReg(CLAHE_ADDR, 0, 1);
							}

							// 把参数写进flash
							param_w[10] = (AGCLimit >> 8) & 0xFF;
							param_w[11] = AGCLimit & 0xFF;

							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						// S曲线
						case SCURVE: {
							u8 order_type = rx_buf[8];
							u8 mode = rx_buf[9];
							// 关闭S曲线
							if(order_type == 0) {
								// 写入S曲线对应的查找表(LUT)
								for (int i = 0; i < 256; i++) {
									writeReg(SCURVE_ADDR, i, i);
								}
							}
							else {
								// 写入S曲线对应的查找表(LUT)
								u8 scurve_data_r;
								for (int i = 0; i < 256; i++) {
									scurve_data_r = param_w[15+i];
									writeReg(SCURVE_ADDR, i, scurve_data_r);
								}
							}


							break;
						}
						// 画面缩放(Scaler)
						case ZOOM : {//3416
							u8 mode = rx_buf[8];
							u32 x_set = (rx_buf[9] << 8) | rx_buf[10];
							u32 y_set = (rx_buf[11] << 8) | rx_buf[12];

							u32 x_left;
							u32 x_right;

							u32 y_below;
							u32 y_under;

							switch(mode) {
								case 1://1倍
									x_left = 0;
									x_right = 639;
									y_below = 0;
									y_under = 511;
									break;
								case 2://2倍
									x_left = min(x_set, 186);
									x_right = min(x_set + 453, 639);
									y_below = min(y_set, 150);
									y_under = min(y_set + 361,511);
									break;
								case 4://4倍
									x_left = min(x_set, 320);
									x_right = min(x_set + 319, 639);
									y_below = min(y_set, 256);
									y_under = min(y_set + 255,511);
									break;
								case 8://8倍
									x_left = min(x_set, 414);
									x_right = min(x_set + 225, 639);
									y_below = min(y_set, 330);
									y_under = min(y_set + 181,511);
									break;
								default:
									x_left = 0;
									x_right = 639;
									y_below = 0;
									y_under = 511;
									break;
							}
							u32 x_zone = {(x_left<<16)|x_right};
							u32 y_zone = {(y_below<<16)|y_under};
							writeReg(ZOOM_ADDR, 0, x_zone);
							writeReg(ZOOM_ADDR, 1, y_zone);

							break;
						}
						// old时域滤波
						case TFILTER: {
							// 指令类型
							u8 order_type = rx_buf[8];
							// 滤波系数alpha(比例), go为1时才能配置(即开启时域滤波时才能配置该参数), 取值范围为[0,255].
							u32 alpha = (u32)(1.0 * rx_buf[10]);
							// 权重系数h(指数), go为0时才能配置(即关闭时域滤波时才能配置该参数), 取值范围为[0,500].
							u32 h = (u32)rx_buf[11];
							if(order_type == 0) {
								// 停止时域滤波
								writeReg(TF_ADDR, 0, 0);
								break;
							}
							// 启动时域滤波
							if(order_type == 1) {
								setTfilterLut(TF_ADDR, h);
								// 开启时域滤波, 并配置滤波系数.
								writeReg(TF_ADDR, 0, h<<16|alpha<<8|1);

								// 把参数写进flash
								param_w[12] = (alpha >> 8) & 0xFF;
								param_w[13] = alpha & 0xFF;
								param_w[14] = h & 0xFF;

								writeParamToFlash(param_w,PARAM_Address);

								break;
							}
							break;
						}
						// 极性反转
						case POlARITY: {
							u32 state = readReg(MISC_ADDR, 0);
							u8 mode = rx_buf[8];
							// 白热
							if(mode == 0) {
								writeReg(MISC_ADDR, 0, state & 0x2);
							}
							// 黑热
							else {
								writeReg(MISC_ADDR, 0, state | 0x1);
							}
							break;
						}
						// 十字丝
						case CROSSHAIR: {
							u8 order_type = rx_buf[8];
							u32 cross_x = ((u32)rx_buf[9] << 8) + (u32)rx_buf[10];
							u32 cross_y = ((u32)rx_buf[11] << 8) + (u32)rx_buf[12];
							u32 mode = readReg(MISC_ADDR, 0);
							// 关闭十字丝
							if(order_type == 0) {
								// 在不改变极性的情况下, 将reg0的第1位设置为0(从第0位算起)
								writeReg(MISC_ADDR, 0, mode & (0x01));
							}
							// 打开十字丝
							else {
								// mode[0]: 极性	mode[1]: 十字丝开关		mode[2：3]: 十字丝模式(模式只会影响十字丝大小)
								// 取mode第0位, 并和10作与运算, 即在不改变极性的情况下, 打开十字丝开关, 并设置十字丝模式为模式2.
								writeReg(MISC_ADDR, 0, 0x2 | (mode & 0x1));
								writeReg(MISC_ADDR, 1, (cross_y << 16) | cross_x);
							}
							break;
						}
						// 画中画
						case PICTURE_IN_PICTURE: {//3415
							u8 order_type = rx_buf[8];

						#if GunAiming
							// 关闭画中画
							if(order_type == 0) {
								writeReg(MISC_ADDR, 2, 0);
							}
							// 打开画中画
							else {
								writeReg(MISC_ADDR, 2, 1);
							}

						#else
							// 关闭画中画
							if(order_type == 0) {
								writeReg(MISC_ADDR, 2, 2);
							}
							// 打开画中画
							else {
								writeReg(MISC_ADDR, 2, 3);
							}

						#endif

							break;
						}
						// 伪彩色
						case PSEUDO_COLOR: {
							u8 order_type = rx_buf[8]; 
							u8 mode = rx_buf[9];
							u8 scurve_data_r;

							// 关闭伪彩色
							if(order_type == 0) {

								setGammaLut_8bit(GAMMA_ADDR2,1.3);
								u32 p2 = (25 << 10) | (5 << 5) | 26;
								u32 p3 = (32 << 19)|(1 << 18)|(250 << 7) | 32;
								writeReg(STRETCH_ADDR,2,p2);
								writeReg(STRETCH_ADDR,3,p3);

								// 写入伪彩色对应的查找表(LUT)
								writeReg(TRANSLATION_ADDR, 3, 1);

								for(int i = 0;i < 3;i++) {
									writeReg(PSEUDO_COLOR_ADDR, 255, i);
									for (int j = 0;j < 256;j++) {
										if(i==0)
											writeReg(PSEUDO_COLOR_ADDR, j, j);
										else
											writeReg(PSEUDO_COLOR_ADDR, j, 0x80);

									}
								}

								writeReg(TRANSLATION_ADDR, 3, 0);
							}
							else {
								setGammaLut_8bit(GAMMA_ADDR2,1.0);

								if(mode == 4){//红热
									u32 p2 = (5 << 10) | (3 << 5) | 30;
									u32 p3 = (38 << 19)|(1 << 18)|(250 << 7) | 32;

									writeReg(STRETCH_ADDR,2,p2);
									writeReg(STRETCH_ADDR,3,p3);


								}
								else {
									u32 p2 = (25 << 10) | (5 << 5) | 26;
									u32 p3 = (32 << 19)|(1 << 18)|(250 << 7) | 32;

									writeReg(STRETCH_ADDR,2,p2);
									writeReg(STRETCH_ADDR,3,p3);

								}



								if(mode == 5){
									u8 scurve_data_r;
									writeReg(TRANSLATION_ADDR, 3, 1);

									for(int i = 0;i < 3;i++) {
										writeReg(PSEUDO_COLOR_ADDR, 255, i);
										for (int j = 0;j < 256;j++) {
											// 第i个通道第j个像素的映射值
											scurve_data_r = pseudo_color_lut_data[4][i][j];
											writeReg(PSEUDO_COLOR_ADDR, j, scurve_data_r);
										}
									}

									writeReg(TRANSLATION_ADDR, 3, 0);
								}
								else if (mode == 6){
									writeReg(TRANSLATION_ADDR, 3, 1);

									for(int i = 0;i < 3;i++) {
										writeReg(PSEUDO_COLOR_ADDR, 255, i);
										for (int j = 0;j < 256;j++) {
											// 黑热
											if(i==0)
												writeReg(PSEUDO_COLOR_ADDR, j, 255-j);
											else
												writeReg(PSEUDO_COLOR_ADDR, j, 0x80);

										}
									}

									writeReg(TRANSLATION_ADDR, 3, 0);
								}
								else{
									writeReg(TRANSLATION_ADDR, 3, 1);

									for(int i = 0;i < 3;i++) {
										writeReg(PSEUDO_COLOR_ADDR, 255, i);
										for (int j = 0;j < 256;j++) {
											// 第i个通道第j个像素的映射值
											scurve_data_r = param_w[271 + 768*(mode - 1) + j + i*256];
											writeReg(PSEUDO_COLOR_ADDR, j, scurve_data_r);
										}
									}

									writeReg(TRANSLATION_ADDR, 3, 0);
								}
							}
							break;
						}
						// 挡片控制
						case SHUTTER: {
							// 自动挡片时间间隔
							u8 auto_shutter = rx_buf[8];
							// 噪声下最小挡片时间间隔
							u8 minimal_shutter = rx_buf[9];
							// 手动挡片触发
							u8 manual_shutter = rx_buf[10];
							if(manual_shutter == 1) { // 打挡片
								u32 reg0 = readReg(SHUTTER_ADDR, 0);
								// 先拉高, 再拉低, 中间延迟100ms用于IP核响应.
								reg0 = reg0 & 0xFFFEFFFF; // 打挡片位变成0
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00010000); // 不打挡片结束之后换回打挡片使能状态
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00010001); // 0x00010001是打挡片，0x00000001是不打
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00010000); // 0x00010001是打挡片，0x00000001是不打


							}
							else if(manual_shutter == 2){			// 不打挡片
								u32 reg0 = readReg(SHUTTER_ADDR, 0);
								// 先拉高, 再拉低, 中间延迟100ms用于IP核响应.
								reg0 = reg0 & 0xFFFEFFFF; // 打挡片位变成0
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000001); // 0x00010001是打挡片，0x00000001是不打
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000000);


							}
							break;
						}
						// 温度读取
						case SENSOR_TMP: {
							u16 temp_raw;
							double temp_real;
							u16 temp;
							do{
								temp_raw = (readReg(SENSOR_ADDR, 15) >> 16) & 0x3FFF;
							}while(temp_raw==0);

							temp_real = 20 + ((6867-(double)(temp_raw))/33.8);
							if(temp_real > 0){
								rx_buf[8] = 0;
							}
							else{
								rx_buf[8] = 1;
								temp_real = -temp_real;
							}

							temp = (u16)(temp_real*256);

							rx_buf[9] = temp >> 8;
							rx_buf[10] = temp & 0xff;
							break;
						}
						// 更新smartdata
						case EXPORE_TIME: {//3352-3407
							for(int i=0;i<56;i++)
								param_w[3352] = rx_buf[8+i];
							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						// 手动设置S曲线
						case SCURVE_USER: {
							for (int i = 0; i < 256; i++) {
								// 从rx_buf[8]开始的256个数据为S曲线数据
								writeReg(SCURVE_ADDR, i, rx_buf[i+8]);
								param_w[15+i] = rx_buf[i+8];//15-270

							}

							//把参数写进flash
							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						// 手动设置伪彩色曲线
						case PSEUDO_COLOR_USER: {
							writeReg(TRANSLATION_ADDR, 3, 1);

							for (int num = 0; num < 3; num++) {
								writeReg(PSEUDO_COLOR_ADDR, 255, num);
								for (int i = 0; i < 256; i++) {
									writeReg(PSEUDO_COLOR_ADDR, i, rx_buf[num*256+i+8+1]);
									param_w[271 + 768*rx_buf[8] + i + num*256] = rx_buf[num*256+i+8+1];//271-3342
								}
							}

							writeReg(TRANSLATION_ADDR, 3, 0);
							//把参数写进flash
							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						// dde参数调整
						case LINEARSTRETCH: {//3945-3959

							u32 per_sum = (rx_buf[8] << 8) | rx_buf[9];
							u32 per_sum_max = (rx_buf[10] << 8) | rx_buf[11];

							u32 per_sum_min = (rx_buf[12] << 8) | rx_buf[13];
							u16 limit_clahe = (rx_buf[14] << 8) | rx_buf[15];

							u16 rate = rx_buf[16];
							u16 G_min = rx_buf[17];
							u16 G_max = rx_buf[18];

							u16 frame_mean_num = rx_buf[19];
							u16 thres_uniform = (rx_buf[20]<<8)|rx_buf[21];
							u16 clahe_go = rx_buf[22];

							u32 p0 = (per_sum << 16) | per_sum_max;
							u32 p1 = (per_sum_min << 16)| limit_clahe;
							u32 p2 = (G_max << 10) | (G_min << 5) | rate;
							u32 p3 = (clahe_go << 18)|(thres_uniform << 7) | frame_mean_num;

							writeReg(STRETCH_ADDR,0,p0);
							writeReg(STRETCH_ADDR,1,p1);
							writeReg(STRETCH_ADDR,2,p2);
							writeReg(STRETCH_ADDR,3,p3);


							for(int i=0;i<15;i++){
								param_w[3945+i] = rx_buf[8+i];

							}

							writeParamToFlash(param_w,PARAM_Address);


							break;
						}
						case DVPON: {
							setGo(READER2_ADDR, 1);

							break;
						}
						case MASK: {
							u32 mask = (rx_buf[8] << 8) | rx_buf[9];
							writeReg(MISC_ADDR, 2, 16384 + mask);
							break;
						}
						//SOBEL启动与参数
						case SOBEL: {//3351

							u32 go = rx_buf[8];
							if (go == 1) {
								u32 p2 = (63 << 10) | (31 << 5) | 0;
								writeReg(STRETCH_ADDR,2,p2);

							}
							else if (go == 0){
								u32 p2 = (25 << 10) | (5 << 5) | 26;
								writeReg(STRETCH_ADDR,2,p2);
							}

							DelayMsec(40);

							// 伪彩色白热
							writeReg(TRANSLATION_ADDR, 3, 1);

							for(int i = 0;i < 3;i++) {
								writeReg(PSEUDO_COLOR_ADDR, 255, i);
								for (int j = 0;j < 256;j++) {
									if(i==0)
										writeReg(PSEUDO_COLOR_ADDR, j, j);
									else
										writeReg(PSEUDO_COLOR_ADDR, j, 0x80);

								}
							}

							writeReg(TRANSLATION_ADDR, 3, 0);
							break;
						}
						//关机
						case PWOFF: {
							writeReg(POWER_ADDR, 0, 0x08);

							break;
						}
						//自调节工作点(产线用)3352-3407
						case WORKPOINT: {
							u32 Test_data_r = 0;
							u32 mean = 0;
							u32 Test_data = 0;

							u32 GOF = ((config[7]<<4)&0xF0) | ((config[6]>>28)&0xF);
							u32 ADC_GAIN = config[11] & 0xFF;
							u32 SFB_OOC = (config[6]>>20) & 0xFF;


							u32 GOF_adjust = GOF + 22; //GOF + 22LSB

							config[6] = (config[6] & 0x0FFFFFFF) | (GOF_adjust<<28);
							config[7] = (config[7] & 0xFFFFFFF0) | (GOF_adjust>>4);

							//初始化
							writeReg(SENSOR_ADDR, 6, config[6]);
							writeReg(SENSOR_ADDR, 7, config[7]);

							bsp_uDelay(1000000);

							//开始调节ADC_GAIN

							while (1){
								config[11] = (config[11] & 0xFFFFFF00) | ADC_GAIN;
								writeReg(SENSOR_ADDR, 11, config[11]);
								bsp_uDelay(1000000);

								Test_data_r = Test_data;
								bsp_uDelay(1000000);

								do{
									Test_data = readReg(SENSOR_ADDR, 14)&0x00003fff;
								}while(Test_data == 0);
								bsp_uDelay(1000000);

								if(Test_data == 0x00003fff && (Test_data_r == 0x00003fff || Test_data_r == 0))
									ADC_GAIN = ADC_GAIN - 2;
								else if(Test_data < 0x00003fff && Test_data_r < 0x00003fff )
										ADC_GAIN = ADC_GAIN + 2;
								else if(Test_data == 0x00003fff && (Test_data_r < 0x00003fff && Test_data_r > 0)){
									ADC_GAIN = ADC_GAIN - 2;
									goto EXIT;
								}
								else if(Test_data < 0x00003fff && Test_data_r == 0x00003fff)
									goto EXIT;
								Test_data_r = Test_data;
								bsp_uDelay(1000000);

							}
							EXIT:
							bsp_uDelay(100000);

							config[6] = (config[6] & 0x0FFFFFFF) | (GOF<<28);
							config[7] = (config[7] & 0xFFFFFFF0) | (GOF>>4);

							writeReg(SENSOR_ADDR, 6, config[6]);
							writeReg(SENSOR_ADDR, 7, config[7]);

							bsp_uDelay(1000000);

							//开始调节SFB_OOC
							do{
								if(mean < 7000){
									SFB_OOC = SFB_OOC + 4;
								}
								else if(mean >9000){
									SFB_OOC = SFB_OOC - 4;
								}

								config[6] = (config[6] & 0xF00FFFFF) | (SFB_OOC << 20);

								writeReg(SENSOR_ADDR, 6, config[6]);

								bsp_uDelay(1000000);

								do{
									mean = readReg(SENSOR_ADDR, 15) & 0x00003fff;
								}while(mean == 0);
								bsp_uDelay(1000000);

							}while(mean < 7000 || mean > 9000);

							bsp_uDelay(1000000);
							writeReg(SENSOR_ADDR, 6, config[6]);
							writeReg(SENSOR_ADDR, 7, config[7]);
							writeReg(SENSOR_ADDR, 11, config[11]);
							bsp_uDelay(1000000);

							//把参数写进flash

							param_w[3376] = config[6] >> 24;
							param_w[3377] = config[6] >> 16 & 0xFF;
							param_w[3383] = config[7] & 0xFF;
							param_w[3399] = config[11] & 0xFF;


							writeParamToFlash(param_w,PARAM_Address);

							break;

						}
						//采集k
						case CALCULATEK: {//3408-3409
							u8 stat = rx_buf[8]; // 0是采集冷本底，1是采集热本底，2是计算并保存k
							if(stat == 0) {
								// 先做采集本底
								u32 reg0 = readReg(SHUTTER_ADDR, 0);
								cold_sum = 0;
								cold_mean = 0;
								// 先拉高, 再拉低, 中间延迟100ms用于IP核响应.
								reg0 = reg0 & 0xFFFEFFFF; // 打挡片位变成0
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000001); // 0x00010001是打挡片，0x00000001是不打
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000000);
								DelayMsec(500);
								// 等待采集本底结束
								int waittime = 0;
								while(readReg(SAMPLE_BACKGROUND_ADDR, 3) & 0x00000001 != 0x00000001){
									waittime++;
								}

								for(int i=0;i<(RAW_WIDTH * (RAW_HEIGHT+4));i++) {
									cold[i] = 0xFFFF;
								}

								DelayMsec(100);

								for(int i=0;i<MAX_WORDS;i++) {
								 	u32 data = K_ADDR[i];
								 	u16 data_part;
								 	data_part = ((data >> 16) & 0xFFFF) >> 2;
								 	cold[2*(i+RAW_WIDTH) + 1] = data_part;
								 	cold_sum += data_part;
								 	data_part = (data & 0xFFFF) >> 2;
								 	cold[2*(i+RAW_WIDTH)] = data_part;
								 	cold_sum += data_part;
								 }

								cold_mean = cold_sum / (RAW_WIDTH * RAW_HEIGHT);
								param_w[3408] = (cold_mean >> 8) & 0xFF;
								param_w[3409] = cold_mean & 0xFF;

								writeParamToFlash(param_w,PARAM_Address);
							}
							else if(stat == 1) {
								// 先做采集本底
								u32 reg0 = readReg(SHUTTER_ADDR, 0);
								hot_sum = 0;
								hot_mean = 0;
								// 先拉高, 再拉低, 中间延迟100ms用于IP核响应.
								reg0 = reg0 & 0xFFFEFFFF; // 打挡片位变成0
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000001); // 0x00010001是打挡片，0x00000001是不打
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000000);
								DelayMsec(500);
								// 等待采集本底结束
								int waittime = 0;
								while(readReg(SAMPLE_BACKGROUND_ADDR, 3) & 0x00000001 != 0x00000001){
									waittime++;
								}
								for(int i=0;i<(RAW_WIDTH * (RAW_HEIGHT+4));i++) {
									hot[i] = 0xFFFF;
								}

								DelayMsec(100);

								for(int i=0;i<MAX_WORDS;i++) {
								 	u32 data = K_ADDR[i];
								 	u16 data_part;
									data_part = ((data >> 16) & 0xFFFF) >> 2;
									hot[2*(i+RAW_WIDTH)+1] = data_part;
									hot_sum += data_part;
									data_part = (data & 0xFFFF) >> 2;
									hot[2*(i+RAW_WIDTH)] = data_part;
									hot_sum += data_part;
								 }
								hot_mean = hot_sum / (RAW_WIDTH * RAW_HEIGHT);

							}
							else if(stat == 2){
								double tmp2 = hot_mean - cold_mean;

								for(int i=0;i<(RAW_WIDTH * (RAW_HEIGHT+4));i++) {
									k_value[i] = 0xFFFF;
								}

								DelayMsec(100);

								for(int i=0;i<RAW_WIDTH * RAW_HEIGHT;i++) {
									double result;
									double tmp1 = hot[i+2*RAW_WIDTH] - cold[i+2*RAW_WIDTH];
									result = tmp1 / tmp2;
									if(result > 2)result = 2;
									else if(result < 0.5) result = 0.5;
									u16 result_u16 = (u16)(result * 4096);
									k_value[i+2*RAW_WIDTH] = result_u16;
								}

								writeFrameToFlash(k_value+2*RAW_WIDTH, StartAddress_K);
							}
							break;
						}
						//x2000串口更新硬核固件
						case WRITE_HARDHEX: {
							uint32_t HARDHEX_Address_tmp = ((rx_buf[8] << 16) | (rx_buf[9] << 8) | rx_buf[10]); //硬核固件的flash暂存地址，范围为HARDHEX_Address_tmp + num_package_hard


							uint32_t len = 4096;
							int times = (rx_buf[13] << 8 | rx_buf[14]);
							//package的序号算出flash地址
							uint32_t address_hex = HARDHEX_Address_tmp + (times-1)*len;
							memcpy(hex, rx_buf + 15, len);
							WriteHEXToFlash(hex, address_hex);
							break;
						}
						//x2000串口更新软核固件
						case WRITE_SOFTHEX: {

							uint32_t SOFTHEX_Address_tmp = (rx_buf[8] << 16) | (rx_buf[9] << 8) | rx_buf[10]; //硬核固件的flash暂存地址，范围为SOFTHEX_Address_tmp + num_package_soft

							uint32_t len = 4096;
							int times = (rx_buf[13] << 8 | rx_buf[14]);
							//package的序号算出flash地址
							uint32_t address_hex = SOFTHEX_Address_tmp + (times-1)*len;
							memcpy(hex, rx_buf + 15, len);
							WriteHEXToFlash(hex, address_hex);

							break;
						}
						//拷贝flash内容
						case COPYHEX: {
							uint32_t HARDHEX_Address_tmp = ((rx_buf[8] << 16) | (rx_buf[9] << 8) | rx_buf[10]); //硬核固件的flash暂存地址，范围为HARDHEX_Address_tmp + num_package_hard
							uint32_t HARDHEX_Address = 0x000000; //硬核固件的flash地址，范围为0x000000 + num_package_hard

							uint32_t SOFTHEX_Address_tmp = ((rx_buf[11] << 16) | (rx_buf[12] << 8) | rx_buf[13]); ; //硬核固件的flash暂存地址，范围为SOFTHEX_Address_tmp + num_package_soft
							uint32_t SOFTHEX_Address = ((rx_buf[14] << 16) | (rx_buf[15] << 8) | rx_buf[16]); //硬核固件的flash地址，范围为SOFTHEX_Address + num_package_soft

							uint32_t num_package_hard = (rx_buf[17] << 8) | rx_buf[18];//硬核包个数							uint32_t num_package_soft;//软核包个数
							uint32_t num_package_soft = (rx_buf[19] << 8) | rx_buf[20];//软核包个数

							CopyHex(HARDHEX_Address_tmp, HARDHEX_Address, num_package_hard);
							CopyHex(SOFTHEX_Address_tmp, SOFTHEX_Address, num_package_soft);

							break;
						}
						//640界面位移//3410-3414
						case TRANSLATION: {
							u32 x_offset = (rx_buf[8] << 8) | rx_buf[9];
							u32 y_offset = (rx_buf[10] << 8) | rx_buf[11];

							writeReg(TRANSLATION_ADDR, 0, x_offset);
							writeReg(TRANSLATION_ADDR, 1, y_offset);

							param_w[3410] = rx_buf[8];
							param_w[3411] = rx_buf[9];
							param_w[3412] = rx_buf[10];
							param_w[3413] = rx_buf[11];

							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						//亮度调节
						case BRIGHTNESS: {
							u32 bias = rx_buf[8];
							u32 bound = rx_buf[9];

							writeReg(BRIGHTNESS_ADDR, 0, bias);
							writeReg(BRIGHTNESS_ADDR, 1, bound);

							break;
						}
						//对比度调节
						case CONTRAST: {
							u32 go = rx_buf[8];
							u32 contrast = (rx_buf[9] << 8) | rx_buf[10];

							writeReg(CONTRAST_ADDR, 0, go);
							writeReg(CONTRAST_ADDR, 1, contrast);

							break;
						}
						//采集锅盖
						case GUOGAI_SAVE: {
							u8 stat = rx_buf[8]; // 0是采集冷锅盖，1是采集热锅盖
							u32 temp_low = 0;
							u32 temp_high = 0;


							if(stat == 0) {
				
								do{
									temp_low = (readReg(SENSOR_ADDR, 15) >> 16) & 0x3FFF;
								}while(temp_low==0);

								DelayMsec(100);

								for(int i=0;i<(RAW_WIDTH * (RAW_HEIGHT+4));i++) {
									hot[i] = 0;
									cold[i] = 0;
									k_value[i] = 0;
									sub_value_min[i] = 0;
									sub_value_max[i] = 0;
								}

								// 先做采集镜头均匀面
								u32 reg0 = readReg(SHUTTER_ADDR, 0);
								// 先拉高, 再拉低, 中间延迟100ms用于IP核响应.
								reg0 = reg0 & 0xFFFEFFFF; // 打挡片位变成0
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000001); // 0x00010001是打挡片，0x00000001是不打
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000000);
								DelayMsec(500);
								// 等待采集本底结束
								int waittime = 0;
								while(readReg(SAMPLE_BACKGROUND_ADDR, 3) & 0x00000001 != 0x00000001){
									waittime++;
								}

								DelayMsec(100);

								for(int i=0;i<MAX_WORDS;i++) {
								 	u32 data = BENDI_ADDR[i];
								 	u16 data_part;
									data_part = ((data >> 16) & 0xFFFF) >> 2;
									hot[2*(i+RAW_WIDTH)] = data_part;
									data_part = (data & 0xFFFF) >> 2;
									hot[2*(i+RAW_WIDTH) + 1] = data_part;
								}

								DelayMsec(1000);

								reg0 = readReg(SHUTTER_ADDR, 0);
								// 先拉高, 再拉低, 中间延迟100ms用于IP核响应.
								reg0 = reg0 & 0xFFFEFFFF; // 打挡片位变成0
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00010001); // 0x00010001是打挡片，0x00000001是不打
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00010000); // 0x00010001是打挡片，0x00000001是不打

								DelayMsec(1000);

								for(int i=0;i<MAX_WORDS;i++) {

									u32 data = BENDI_ADDR[i];
									u16 data_part;
									data_part = ((data >> 16) & 0xFFFF) >> 2;
									cold[2*(i+RAW_WIDTH)] = data_part;
									data_part = (data & 0xFFFF) >> 2;
									cold[2*(i+RAW_WIDTH) + 1] = data_part;

									sub_value_min[2*(i+RAW_WIDTH)] = (s16)(hot[2*(i+RAW_WIDTH)]) - (s16)(cold[2*(i+RAW_WIDTH)]);
									sub_value_min[2*(i+RAW_WIDTH)+1] = (s16)(hot[2*(i+RAW_WIDTH)+1]) - (s16)(cold[2*(i+RAW_WIDTH)+1]);

								}
								DelayMsec(1000);
								dpc_cold = middle_filter(sub_value_min+2*RAW_WIDTH, RAW_WIDTH, RAW_HEIGHT);
								DelayMsec(1000);
								mean_cold = mean_filter(dpc_cold, RAW_WIDTH, RAW_HEIGHT);

								writeFrameToFlash(mean_cold, 0x620000);

								DelayMsec(1000);

								param_w[3428] = (temp_low >> 8) & 0xFF;
								param_w[3429] = temp_low & 0xFF;

								writeParamToFlash(param_w,PARAM_Address);

								DelayMsec(1000);


							}
							else if(stat == 1) {

								readFrameFromFlash(0x620000, 0x10700000);

								// 先做采集镜头均匀面
								u32 reg0 = readReg(SHUTTER_ADDR, 0);
								// 先拉高, 再拉低, 中间延迟100ms用于IP核响应.
								reg0 = reg0 & 0xFFFEFFFF; // 打挡片位变成0
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000001); // 0x00010001是打挡片，0x00000001是不打
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00000000);
								DelayMsec(500);
								// 等待采集本底结束
								int waittime = 0;
								while(readReg(SAMPLE_BACKGROUND_ADDR, 3) & 0x00000001 != 0x00000001){
									waittime++;
								}

								DelayMsec(100);

								for(int i=0;i<MAX_WORDS;i++) {
								 	u32 data = BENDI_ADDR[i];
								 	u16 data_part;
									data_part = ((data >> 16) & 0xFFFF) >> 2;
									hot[2*(i+RAW_WIDTH)] = data_part;
									data_part = (data & 0xFFFF) >> 2;
									hot[2*(i+RAW_WIDTH) + 1] = data_part;
								}

								DelayMsec(1000);

								reg0 = readReg(SHUTTER_ADDR, 0);
								// 先拉高, 再拉低, 中间延迟100ms用于IP核响应.
								reg0 = reg0 & 0xFFFEFFFF; // 打挡片位变成0
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00010001); // 0x00010001是打挡片，0x00000001是不打
								DelayMsec(100);
								writeReg(SHUTTER_ADDR, 0, reg0 | 0x00010000); // 0x00010001是打挡片，0x00000001是不打

								DelayMsec(1000);

								for(int i=0;i<MAX_WORDS;i++) {

									u32 data = BENDI_ADDR[i];
									u16 data_part;
									data_part = ((data >> 16) & 0xFFFF) >> 2;
									cold[2*(i+RAW_WIDTH)] = data_part;
									data_part = (data & 0xFFFF) >> 2;
									cold[2*(i+RAW_WIDTH) + 1] = data_part;


									sub_value_max[2*(i+RAW_WIDTH)] = (s16)(hot[2*(i+RAW_WIDTH)]) - (s16)(cold[2*(i+RAW_WIDTH)]);
									sub_value_max[2*(i+RAW_WIDTH)+1] = (s16)(hot[2*(i+RAW_WIDTH)+1]) - (s16)(cold[2*(i+RAW_WIDTH)+1]);

								}

								for(int i=0;i<MAX_WORDS;i++) {

									u32 data = COLD_ADDR[i];
									u16 data_part;
									data_part = ((data >> 16) & 0xFFFF);
									cold[2*(i+RAW_WIDTH)] = data_part;
									data_part = (data & 0xFFFF);
									cold[2*(i+RAW_WIDTH) + 1] = data_part;


								}

								for(int i=0;i<RAW_WIDTH*RAW_HEIGHT;i++) {
									mean_cold[i] = cold[i+2*RAW_WIDTH];

								}

								DelayMsec(1000);
								dpc_hot = middle_filter(sub_value_max+2*RAW_WIDTH, RAW_WIDTH, RAW_HEIGHT);
								DelayMsec(1000);

								mean_hot = mean_filter(dpc_hot, RAW_WIDTH, RAW_HEIGHT);
								DelayMsec(1000);
								writeFrameToFlash(mean_hot, 0x6C0000);
								DelayMsec(1000);
								readFrameFromFlash(0x6C0000, 0x10900000);
								DelayMsec(1000);

								temp_low = (param_w[3428] << 8) | param_w[3429];
								DelayMsec(1000);

								do{
									temp_high = (readReg(SENSOR_ADDR, 15)>>16) & 0x3fff;
								}while(temp_high == 0);

								param_w[3430] = (temp_high >> 8) & 0xFF;
								param_w[3431] = temp_high & 0xFF;
								DelayMsec(1000);

								s16 tmp1 = (s16)temp_low - (s16)temp_high;

								int tmp2;
								int tmp3;
								int result_even,result_odd;


								for(int i=0;i<MAX_WORDS;i++) {

									tmp2 = ((int)mean_hot[2*i]-(int)mean_cold[2*i])*256;
									tmp3 = ((int)mean_hot[2*i+1]-(int)mean_cold[2*i+1])*256;

									result_even = tmp2 / tmp1;
									result_odd = tmp3 / tmp1;

									k_value[2*(i+RAW_WIDTH)] = (s16)result_even;

									k_value[2*(i+RAW_WIDTH) + 1] = (s16)result_odd;


								}

								DelayMsec(1000);
								writeFrameToFlash(k_value+2*RAW_WIDTH, GUOGAI_SLOPE_Address);
								DelayMsec(1000);
								readFrameFromFlash(GUOGAI_SLOPE_Address, 0x10800000);


								writeParamToFlash(param_w,PARAM_Address);


							}

							break;
						}
						case GAMMA_SHIFT:{
							u16 gamma = rx_buf[8];
							setGammaLut_8bit(GAMMA_ADDR,gamma / 128.0f);
							param_w[3960] = rx_buf[8];
							writeParamToFlash(param_w,PARAM_Address);

							break;
						}
						//写默认参数
						case WIRTE_DEFAULT: {

							param_w[0] = 0;
							param_w[1] = 100;

							param_w[2] = 19;
							param_w[3] = 5;
							param_w[4] = 0;
							param_w[5] = 10;

							param_w[6] = 0x01;
							param_w[7] = 0x2C;

							param_w[8] = 0;
							param_w[9] = 30;

							param_w[10] = 0;
							param_w[11] = 100;

							param_w[12] = 0;
							param_w[13] = 240;
							param_w[14] = 50;

							for (int i = 0; i < 256; i++) {
								param_w[15+i] = gamma_our[i];

							}

							for(int mode = 0; mode < 4; mode++){
								for (int num = 0; num < 3; num++) {
									for (int i = 0; i < 256; i++) {
										param_w[271 + 768*mode + i + num*256] = pseudo_color_lut_data[mode][num][i];//271-3342
									}
								}
							}


							param_w[3343] = 0x20;
							param_w[3344] = 0x0A;
							param_w[3345] = 0X66;
							param_w[3346] = 0x03;
							param_w[3347] = 0xE8;
							param_w[3348] = 0xB4;
							param_w[3349] = 0x02;
							param_w[3350] = 0x00;

							param_w[3351] = 255;

							//408个默认工作点
							param_w[3352] = 0x00;
							param_w[3353] = 0x00;
							param_w[3354] = 0x00;
							param_w[3355] = 0x00;
							param_w[3356] = 0xA6;
							param_w[3357] = 0xBD;
							param_w[3358] = 0x1C;
							param_w[3359] = 0x40;
							param_w[3360] = 0x51;
							param_w[3361] = 0x33;
							param_w[3362] = 0x3E;
							param_w[3363] = 0xC3;
							param_w[3364] = 0x00;
							param_w[3365] = 0x80;
							param_w[3366] = 0x08;
							param_w[3367] = 0x04;
							param_w[3368] = 0xB6;
							param_w[3369] = 0x1B;
							param_w[3370] = 0x6D;
							param_w[3371] = 0xC1;
							param_w[3372] = 0x16;
							param_w[3373] = 0xC5;
							param_w[3374] = 0xB3;
							param_w[3375] = 0x6D;
							param_w[3376] = 0xC8;
							param_w[3377] = 0xCC;
							param_w[3378] = 0x87;
							param_w[3379] = 0x8C;
							param_w[3380] = 0x1F;
							param_w[3381] = 0xF0;
							param_w[3382] = 0x32;
							param_w[3383] = 0x64;
							param_w[3384] = 0x5D;
							param_w[3385] = 0x82;
							param_w[3386] = 0xA1;
							param_w[3387] = 0x70;
							param_w[3388] = 0xA5;
							param_w[3389] = 0x0C;
							param_w[3390] = 0x0C;
							param_w[3391] = 0x03;
							param_w[3392] = 0x3B;
							param_w[3393] = 0x57;
							param_w[3394] = 0xFF;
							param_w[3395] = 0xFF;
							param_w[3396] = 0x53;
							param_w[3397] = 0xBA;
							param_w[3398] = 0xF2;
							param_w[3399] = 0x75;
							param_w[3400] = 0x39;
							param_w[3401] = 0x0A;
							param_w[3402] = 0x37;
							param_w[3403] = 0x34;
							param_w[3404] = 0x3F;
							param_w[3405] = 0xD5;
							param_w[3406] = 0x00;
							param_w[3407] = 0x01;


							param_w[3408] = 0x1F;
							param_w[3409] = 0x40;

							param_w[3410] = 0x02;
							param_w[3411] = 0x80;
							param_w[3412] = 0x02;
							param_w[3413] = 0x00;
							param_w[3414] = 0x00;

							param_w[3415] = 30;
							param_w[3416] = 0x03;
							param_w[3417] = 0xE8;

							param_w[3419] = 15;
							param_w[3420] = 0;
							param_w[3421] = 150;
							param_w[3422] = 8;
							param_w[3423] = 30;
							param_w[3424] = 10;

							param_w[3432] = 0;
							for(int i=0;i<512;i++){
								param_w[3433+i] = 0xFF;
							}

							//dde
							param_w[3945] = 0x75;
							param_w[3946] = 0x30;
							param_w[3947] = 0;
							param_w[3948] = 32;
							param_w[3949] = 0;
							param_w[3950] = 32;
							param_w[3951] = 0;
							param_w[3952] = 100;
							param_w[3953] = 26;
							param_w[3954] = 5;
							param_w[3955] = 25;
							param_w[3956] = 32;
							param_w[3957] = 0x01;
							param_w[3958] = 0xF4;
							param_w[3959] = 1;
							param_w[3960] = 166;

							u16 clear[RAW_WIDTH*RAW_HEIGHT];
							for(int i=0;i<RAW_WIDTH*RAW_HEIGHT;i++){
								clear[i] = 0;
							}
							writeFrameToFlash(clear, 0x6C0000);
							writeFrameToFlash(clear, GUOGAI_SLOPE_Address);

							memset((void*) 0x10800000, 0, RAW_WIDTH * RAW_HEIGHT * 2);
							memset((void*) 0x10900000, 0, RAW_WIDTH * RAW_HEIGHT * 2);


							writeParamToFlash(param_w,PARAM_Address);



							break;
						}
					}

					//CRC校验回复
					u16 len_crc_full = ((rx_buf[4] << 8) | rx_buf[5]) + 8;
					u16 crc_res_1 = doCrc(rx_buf,6);
					u16 crc_res_2 = doCrc(rx_buf,len_crc_full);

					crc_respond[0] = (crc_res_1 >> 8) & 0xFF;
					crc_respond[1] = crc_res_1 & 0xFF;
					crc_respond[2] = (crc_res_2 >> 8) & 0xFF;
					crc_respond[3] = crc_res_2 & 0xFF;

					crc_respond[4] = rx_buf[8] & 0xFF;
					crc_respond[5] = rx_buf[9] & 0xFF;
					crc_respond[6] = rx_buf[10] & 0xFF;


					responseToIPC(crc_respond, 7);

				}
				else {
					state_machine = 0;
					badOrderHandler(&idx, &rx_idx, rx_buf);
				}
				// 所有状态运行完毕, 重置状态机.
				state_machine = 0;
				// 数组前移
				for(int i = idx;i < UART_BUF_LEN;i++) {
					rx_buf[i - idx] = rx_buf[i];
				}
				rx_idx = 0;
				break;
			}
		}
	}
}
