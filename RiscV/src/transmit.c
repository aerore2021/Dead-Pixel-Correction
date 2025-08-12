/*
 * transmit.c
 *
 *  Created on: 2023年6月27日
 *      Author: RuiRo
 */

#include "transmit.h"

/*
* CRC校验函数,用于校验传输的指令是否正确.
*/
u16 doCrc(u8* message, u16 len) {
	u16 crc_reg = 0;
	u16 cur_value;
	for (int i = 0; i < len; i++) {
		cur_value = (u16)(message[i] << 8);
		for (int j = 0; j < 8; j++) {
			if ((short)(crc_reg ^ cur_value) < 0) {
				crc_reg = (u16)((crc_reg << 1) ^ 0x1021);
			}
			else {
				crc_reg <<= 1;
			}
			cur_value <<= 1;
		}
	}
	return crc_reg;
}



