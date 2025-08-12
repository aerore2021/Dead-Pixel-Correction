/*
 * utils.h
 *
 *  Created on: 2023年8月21日
 *      Author: RuiRo
 */

#ifndef SRC_UTILS_H_
#define SRC_UTILS_H_

#include "type.h"
#include "bsp.h"

#include <stdlib.h>
#include <stdbool.h>

#define VER_MAJOR 0x01
#define VER_MINOR 0x09
#define VER_PATCH 0x00
#define GunAiming 1
#define USE_K 0


void DelaySec(u32 sec);

void DelayMsec(u32 msec);

s16* mean_filter(s16 *image, u16 width, u16 height);
s16* middle_filter(s16 *image, u16 width, u16 height);
static int compare(const void *a, const void *b);
uint32_t min(uint32_t a, uint32_t b);
u32* find_bad_points(u16 *image, u16 width, u16 height, u16 threshold, u16 max_bad_points, int* bad_point_count);

#endif /* SRC_UTILS_H_ */
