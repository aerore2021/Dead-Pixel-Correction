/*
 * my_uart.h
 * uart中断相关函数
 *
 *  Created on: 2023年8月21日
 *      Author: RuiRo
 */

#ifndef SRC_MY_UART_H_
#define SRC_MY_UART_H_

#include "bsp.h"
#include "uart.h"
#include "riscv.h"
#include "plic.h"
#include "parameters_efinity.h"


// 串口收发缓冲数组
extern u8 rx_buf[UART_BUF_LEN];
extern u8 tx_buf[UART_BUF_LEN];
extern u16 rx_idx;
extern u16 tx_idx;

void trap();
void uartInterruptSub(u16 *rx_idx, u8 *buffer);
void uartInterrupt(u16 *rx_idx, u8 *buffer);
void responseToIPC(u8* WriteBuffer, u16 write_length);
void badOrderHandler(u16 *idx, u16 *rx_idx, u8 *buffer);
void param_transfer();

#endif /* SRC_MY_UART_H_ */
