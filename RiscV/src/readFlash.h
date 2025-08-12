/*
 * readFlash.h
 *
 *  Created on: 2024年6月22日
 *      Author: RuiRo
 */

#ifndef SRC_READFLASH_H_
#define SRC_READFLASH_H_

#include <stdint.h>
#include "bsp.h"
#include "spi.h"
#include "spiDemo.h"
#include "parameters_efinity.h"
//#include "stdint.h"

//User Binary Location
#define StartAddress_K    		0x900000 //k的flash地址，范围为0x900000-0x9A0000
#define HARDHEX_Address_DST     0x000000 //硬核固件的默认flash地址，范围为0x000000 - 0x400000(实际为0x362E32)

#define PARAM_Address			0x800000 //FPGA各个IP参数存储的flash起始地址

#define GUOGAI_SLOPE_Address	0x760000 //锅盖斜率均匀面的flash起始地址



//Read size
#define ReadSize        124*1024

void readFrameFromFlash(uint32_t address_flash, uint32_t address_mem);
void writeFrameToFlash(u16 k[], uint32_t address_start);
void WriteHEXToFlash(uint8_t hex[4096], uint32_t adress_hex);

void writeParamToFlash(u8 param[4096],uint32_t address);
uint8_t* readParamFromFlash(uint32_t address);

void CopyHex(uint32_t HARDHEX_Address_tmp, uint32_t HARDHEX_Address, uint32_t times);


uint8_t Sector[4096];



#endif /* SRC_READFLASH_H_ */
