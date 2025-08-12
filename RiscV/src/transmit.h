/*
 * transmit.h
 *
 *  Created on: 2023年6月27日
 *      Author: RuiRo
 */

#ifndef SRC_TRANSMIT_H_
#define SRC_TRANSMIT_H_

#include "type.h"

#define   UART_SOP  			0x6E
#define   UART_EOP  			0x5A
#define   No_Operation  		0x00
#define   SET_DEFAULTS  		0x01
#define   CAMERA_RESET  		0x02
#define   RESET_FACTORY  		0x03
#define   SERIAL_NUMBER  		0x04
#define   GET_REVISION 			0x05
#define   FACTORYPARA  			0x06
#define   GET_K_STATE 			0x07
#define   GAIN_MODE  			0x0A
#define   FFC_MODE_SELECT  		0x0B
#define   DO_FFC  				0x0C
#define   FFC_PERIOD  			0x0D
#define   FFC_TEMP_DELTA  		0x0E
#define   VIDEO_MODE  			0x0F
#define   VIDEO_LUT  			0x10
#define   VIDEO_ORIENTATION  	0x11
#define   DIGITAL_OUTPUT_MODE  	0x12
#define   AGC_TYPE  			0x13
#define   BRIGHTNESS  			0x15
#define   SCURVE                0x16
#define   CONTRAST              0x17
#define   BRIGHTNESS_BIAS  		0x18
#define   CLAHEENABLE  			0x19
#define   POlARITY  			0x1A
#define   SAVESYSPARAPARA  		0x1B
#define   MIRROR                0x1C
#define   CROSSHAIR             0x1D
#define   PICTURE_IN_PICTURE	0x1E
#define   SPOT_METER_MODE  		0x1F
#define   READ_SENSOR_TEMP  	0x20
#define   EXTERNAL_SYNC  		0x21
#define   ISOTHERM  			0x22
#define   ISOTHERM_THRESHOLD  	0x23
#define   PSEUDO_COLOR			0x24
#define   TEST_PATTERN  		0x25
#define   VIDEO_COLOR  			0x26
#define   OSD					0x27
#define   GUOGAI_SAVE			0x28
#define   GAMMA_SHIFT			0x29
#define   SPOT_METER  			0x2A
#define   SPOT_DISPLAY  		0x2B
#define   DDE_GAIN  			0x2C
#define   SHUTTER				0x31
#define   ZOOM  				0x32
#define   GAMMA_CTRL  			0x33
#define   FFC_WARN_TIME  		0x3C
#define   AGC_FILTER  			0x3E
#define   PLATEAU_LEVEL  		0x3F
#define   SENSOR_TMP			0x40
#define   SCURVE_USER           0x41
#define   PSEUDO_COLOR_USER     0x42
#define   GET_SPOT_METER_DATA  	0x43
#define   EXPORE_TIME           0x44
#define	  DVPON					0x45
#define	  MASK					0x46
#define	  SOBEL					0x47
#define	  PWOFF					0x48
#define	  CALCULATEK			0x49
#define	  WORKPOINT				0x4A
#define   TRANSLATION			0x4B
#define   AGC_ROI  				0x4C
#define   WRITE_HARDHEX  		0x4D
#define   COPYHEX  				0x4E
#define   WRITE_SOFTHEX  		0x4F
#define   BASE_SEL  			0x50
#define   AutoCaliBp			0x51
#define   WIRTE_DEFAULT  		0x53
#define   ITT_MIDPOIT  			0x55
#define   CMD_TEST  			0x56
#define   CMD_TEST2  			0x5A
#define   TRIGGER_CTRL  		0x5B
#define   CAMERA_PART  			0x66
#define   CAMERA_CONNECT  		0x67
#define   MAX_AGC_GAIN  		0x6A
#define   PAN_AND_TILT  		0x70
#define   VIDEO_STANDARD  		0x72
#define   SHUTTER_POSITION  	0x79
#define   HandFindBp  			0x7E
#define   AutoFindBp  			0x7F
#define   HotSupplement  		0x80
#define   BlockArithmetic  		0x81
#define   BFILTER  				0x83
#define   SFILTER  				0x84
#define   TFILTER  				0x85
#define   BADPOINT  			0x86
#define   OCCCTRL  				0x87
#define   ADAVGCTRL  			0x88
#define   IRSYSDATASET  		0x89
#define   SYSPARAREAD  			0x8A
#define   MEMORYRADWRITE  		0x8B
#define   PRODUCTDATETIME  		0x8C
#define   KPARAREGU  			0x8D
#define   TESTAVGCTRL  			0x8E
#define   ALLFILTERCTRL  		0x8F
#define   AUTOAGCGK  			0x90
#define   AUTOAGCGMIN  			0x91
#define   AUTOAGCGMAX  			0x92
#define   AUTOAGCOFFSET  		0x93
#define   AUTOPEGAIN  			0x94
#define   AUTOPEPMAX  			0x95
#define   AUTOPEPMIN  			0x96
#define   AUTOPEOFFSET  		0x97
#define   AUTOPEGMAX  			0x98
#define   AUTOPEL1  			0x99
#define   AUTOPEL2  			0x9A
#define   AUTOPEADDAVG  		0x9B
#define   AUTOPEADDENA  		0x9C
#define   AUTOPEMIXENA  		0x9D
#define   MANUALBRIGHT  		0x9E
#define   MANUALCONTRAST  		0x9F
#define   LINEARSTRETCH			0xA0
#define   READ_ENVIROMENT_TEMP  0xA1
#define   READ_DS18B20_TEMP  	0xA2
#define   DATACOLLECT  			0xC0
#define   SPATIAL_THRESHOLD  	0xE3
#define   SOFTWARE_VERSION  	0xD0
#define   GAIN_SWITCH_PARAMS  	0xDB
#define   HIGHPIXEL_BLOCK_SHOW  0xDC
#define   CAMERALENSCTRL  		0xF0
#define   INT_MODE  			0xF1

u16 doCrc(u8* message, u16 len);


#endif /* SRC_TRANSMIT_H_ */
