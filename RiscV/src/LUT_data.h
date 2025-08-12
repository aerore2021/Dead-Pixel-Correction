#ifndef SRC_LUT_DATA_H_
#define SRC_LUT_DATA_H_

#include "type.h"

#define USE_TESTPATTERN 0

// S曲线IP 查找表数组
extern u8 scurve_lut_data[3][256];
// 伪彩色IP 查找表数组
extern u8 pseudo_color_lut_data[5][3][256];

extern u8 gamma_our[256];
extern u16 k[640*512];
extern u16 cold[640 * 516];
extern u16 hot[640 * 516];
extern s16 k_value[640 * 516];
extern s16 sub_value_max[640 * 516];
extern s16 sub_value_min[640 * 516];
extern u64 cold_sum;
extern u16 cold_mean;
extern u64 hot_sum;
extern u16 hot_mean;

#endif /* SRC_LUT_DATA_H_ */
