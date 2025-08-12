#ifndef SRC_IP_CONFIG_H_
#define SRC_IP_CONFIG_H_

#include "type.h"
#include "io.h"
#include "math.h"
#include "bsp.h"
#include "plic.h"
#include "riscv.h"
#include "string.h"

#include "lut_data.h"
#include "utils.h"
#include "parameters_efinity.h"
#include "readFlash.h"
void writeReg(uint32_t base_addr, uint32_t offset, uint32_t data);

uint32_t readReg(uint32_t base_addr, uint32_t offset);

void setGo(uint32_t base_addr, uint32_t g);

void setMode(uint32_t base_addr, uint32_t m);

void setWidth(uint32_t base_addr, uint32_t w);

void setHeight(uint32_t base_addr, uint32_t h);

void setBaseaddr(uint32_t base_addr, uint32_t a);

void setDpcThreshold(uint32_t base_addr, uint32_t a);

void setDpcSmooth(uint32_t base_addr, uint32_t a);

void setSfilterGo(uint32_t base_addr, uint32_t go);

void setSfilterMode(uint32_t base_addr, uint32_t mode);

void setSfilterLut(uint32_t base_addr, float h);
void setTfilterLut(uint32_t base_addr, float h);
void setDiffMulEXP(uint32_t base_addr, float h);
void setGammaLut_8bit(uint32_t base_addr, float h);

void trap_entry();

void systemInit();

uint8_t* fpgaInit();
uint8_t* param;
static uint8_t param_r[4096];
u32 config[14];//3352-3407

#endif /* SRC_IP_CONFIG_H_ */
