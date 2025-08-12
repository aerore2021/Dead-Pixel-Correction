/*
 * utils.c
 *
 *  Created on: 2023年8月21日
 *      Author: RuiRo
 */

#include "utils.h"

// 延时函数(单位:s)
void DelaySec(u32 sec) {
	bsp_uDelay(sec * 1000 * 1000);
}
// 延时函数(单位:ms)
void DelayMsec(u32 msec) {
	bsp_uDelay(msec * 1000);
}

uint32_t min(uint32_t a, uint32_t b){
	uint32_t minOF2;
	minOF2 = (a>b) ? b : a;
	return minOF2;
}

s16* mean_filter(s16 *image, u16 width, u16 height) {
    const int kernel_size = 15;    // 保持7x7滤波窗口
    const int offset = 7;         // 7/2取整
    const int cell_count = 225;   // 7x7的像素总数

    // 参数有效性校验
    if (!image || width < kernel_size || height < kernel_size)
        return NULL;

    // 分配带符号的输出缓冲区
    s16 *output = (s16*)malloc(width * height * sizeof(s16));
    if (!output) return NULL;

    // 主处理循环
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            int sum = 0;
            int valid_count = 0;

            // 邻域遍历优化：预计算边界
            const int y_start = (y - offset) > 0 ? (y - offset) : 0;
            const int y_end = (y + offset) < height ? (y + offset) : height-1;
            const int x_start = (x - offset) > 0 ? (x - offset) : 0;
            const int x_end = (x + offset) < width ? (x + offset) : width-1;

            // 带符号累加循环
            for (int ny = y_start; ny <= y_end; ny++) {
                for (int nx = x_start; nx <= x_end; nx++) {
                    sum += image[ny * width + nx];
                    valid_count++;
                }
            }

            // 带符号的均值计算（四舍五入）
            output[y * width + x] = (s16)((sum + valid_count/2) / valid_count);
        }
    }

    return output;
}



static int compare(const void *a, const void *b) {
    s16 arg1 = *(const s16*)a;
    s16 arg2 = *(const s16*)b;
    return (arg1 > arg2) - (arg1 < arg2);  // 保持正确的符号比较
}

s16* middle_filter(s16 *image, u16 width, u16 height) {


    s16 *result = (s16*)malloc(width * height * sizeof(s16));
    if (!result) return NULL;

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            const s16 current = image[y * width + x];

            // 带符号处理的滤波逻辑
            s16 window[49];
            int count = 0;

            // 收集邻域时保留符号信息
            for (int dy = -3; dy <= 3; dy++) {
                for (int dx = -3; dx <= 3; dx++) {

                    const int nx = x + dx;
                    const int ny = y + dy;
                    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                        window[count++] = image[ny * width + nx];
                    }
                }
            }

            qsort(window, count, sizeof(s16), compare);
            result[y * width + x] = window[count / 2];

        }
    }

    return result;
}

// 比较函数用于qsort
int compare_s16(const void* a, const void* b) {
    s16 val1 = *(const s16*)a;
    s16 val2 = *(const s16*)b;
    return (val1 > val2) - (val1 < val2);
}

u32* find_bad_points(u16 *image, u16 width, u16 height, u16 threshold, u16 max_bad_points, int* bad_point_count) {
    *bad_point_count = 0;  // 初始化坏点计数

//    if (!image || width < 3 || height < 3 || threshold == 0 || max_bad_points == 0)
//        return NULL;

    // 分配足够存储最大可能坏点的内存
    u32* bad_points = (u32*)malloc(max_bad_points * sizeof(u32));
    if (!bad_points) return NULL;

    // 用于存储3×3邻域像素值的数组
    u16 neighborhood[8]; // 3×3-1=8个邻域点
    const int min_valid_neighbors = 4; // 有效邻域的最小数量

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            const u16 current = image[y * width + x];
            int valid_neighbors = 0;

            // 收集3×3邻域像素值（不包括中心点）
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0) continue; // 跳过中心点

                    const int nx = x + dx;
                    const int ny = y + dy;

                    // 检查邻域像素是否在图像范围内
                    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                        neighborhood[valid_neighbors++] = image[ny * width + nx];
                    }
                }
            }

            // 需要有足够多的有效邻域点
            if (valid_neighbors < min_valid_neighbors) {
                continue; // 跳过边界点
            }

            // 计算邻域中值（手动排序）
            u16 sorted[8]; // 最大存储8个值
            memcpy(sorted, neighborhood, valid_neighbors * sizeof(u16));

            // 对小数组进行冒泡排序
            for (int i = 0; i < valid_neighbors - 1; i++) {
                for (int j = 0; j < valid_neighbors - i - 1; j++) {
                    if (sorted[j] > sorted[j+1]) {
                        u16 temp = sorted[j];
                        sorted[j] = sorted[j+1];
                        sorted[j+1] = temp;
                    }
                }
            }

            // 获取中值
            u16 median = sorted[valid_neighbors / 2];

            // 计算当前像素与邻域中值的绝对差
            const int diff = abs((int)current - (int)median);

            // 如果差值大于阈值，则判定为坏点
            if ((diff > (int)threshold)) {
                // 将坐标打包为u32: 高16位为x坐标, 低16位为y坐标
                bad_points[*bad_point_count] = ((u32)x << 16) | (u32)y;
                (*bad_point_count)++;

                // 检查是否达到最大坏点数量限制
                if (*bad_point_count >= max_bad_points) {
                    goto MAX_BAD_POINTS_REACHED;
                }
            }
        }
    }

    MAX_BAD_POINTS_REACHED:

    // 如果实际检测到的坏点较少，缩小内存分配
    if (*bad_point_count == 0) {
        free(bad_points);
        return NULL;
    } else if (*bad_point_count < max_bad_points) {
        bad_points = realloc(bad_points, *bad_point_count * sizeof(u32));
    }

    return bad_points;
}
