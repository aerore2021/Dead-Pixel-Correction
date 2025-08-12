/*
 * paramaters_efinity.h
 *
 *  Created on: 2023年6月27日
 *      Author: RuiRo
 */

#ifndef SRC_PARAMETERS_EFINITY_H_
#define SRC_PARAMETERS_EFINITY_H_

#define UART_A_SAMPLE_PER_BAUD 	8
#define CORE_HZ 				50000000 // 100MHZ:100000000 50MHZ:50000000 由于memory_clk 从100MHZ改成50MHZ, 这步也需要修改, 否则会导致波特率不对
#define UART_BUF_LEN 			8192    // 缓冲区大小(不要开太大, 会占用过多内存)
#define UART_BAUD_RATE 			1000000  // uart波特率, 必须与上位机(x2000)保持一致!
#define UART_TIMEOUT_COUNT 		1000   // 超时时间

#define SAMPLE_BACKGROUND_ADDR 	0xe1001000
#define NUC_ADDR 				0xe1002000
#define READER0_ADDR 			0xe1003000
#define READER1_ADDR 			0xe1004000
#define WRITER0_ADDR 			0xe1005000
#define WRITER1_ADDR 			0xe1006000
#define CLAHE_ADDR 				0xe1007000
#define DPC0_ADDR 				0xe1008000
#define USM0_ADDR 				0xe1009000
#define NLM0_ADDR 				0xe100a000
#define SCURVE_ADDR 			0xe100b000
#define	CFPN_ADDR 				0xe100c000
#define WRITER2_ADDR 			0xe100d000
#define READER2_ADDR 			0xe100e000
#define PSEUDO_COLOR_ADDR		0xe100f000
#define TF_ADDR                 0xe1010000
#define SHUTTER_ADDR            0xe1011000
#define CLIPPER_ADDR			0xe1012000
#define ZOOM_ADDR               0xe1013000
#define MISC_ADDR               0xe1014000
#define TMP101_ADDR				0xe1015000
#define TRANSLATION_ADDR		0xe1016000
#define CONTRAST_ADDR			0xe1017000
#define BRIGHTNESS_ADDR			0xe1018000
#define SENSOR_ADDR				0xe1019000
#define POWER_ADDR				0xe1020000
#define	STRETCH_ADDR			0xe1030000
#define GAMMA_ADDR              0xe1040000
#define GAMMA_ADDR2             0xe1041000

#define DISP_BUF_ADDR 			0x10500000
#define SENSOR_BUF_ADDR 		0x10000000
#define TESTB_BUF_ADDR 		0x10d00000

#define RAW_WIDTH 				640
#define RAW_HEIGHT 				512
#define DISPLAY_WIDTH			640
#define DISPLAY_HEIGHT			512
#define BUF_LEN 				4096
#define K_ADDR ((volatile uint32_t*)0x11000000)
#define TFilter_ADDR ((volatile uint32_t*)0x13000000)
#define COLD_ADDR ((volatile uint32_t*)0x10700000)

#define BENDI_ADDR ((volatile uint32_t*)0x10C00000)
#define mem ((volatile uint32_t*)0x10B00000)
#define MAX_WORDS (640 * 512 / 2)


#endif /* SRC_PARAMETERS_EFINITY_H_ */
