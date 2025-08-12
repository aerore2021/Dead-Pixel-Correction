/*
 * my_uart.c
 *
 *  Created on: 2023年8月21日
 *      Author: RuiRo
 */

#include "my_uart.h"

u8 rx_buf[UART_BUF_LEN];
u8 tx_buf[UART_BUF_LEN];
u16 rx_idx = 0;
u16 tx_idx = 0;

// 回复上位机
void responseToIPC(u8* WriteBuffer, u16 write_length) {
	u16 cur_idx = 0;
	while (cur_idx < write_length){
		u8 data = *(WriteBuffer + cur_idx);
		uart_write(BSP_UART_TERMINAL,data);
		cur_idx++;
	}
}

// 处理错误指令
void badOrderHandler(u16 *idx, u16 *rx_idx, u8 *buffer) {
	int i = 0;
	// 清空rx_buf数组.
	for(int i = *rx_idx;i < BUF_LEN;i++) {
		buffer[i - *rx_idx] = buffer[i];
	}
	*rx_idx = 0;
	*idx = 0;
}

// 该函数在发生interrupts或exceptions时，会被trap_entry函数调用.
void trap(){
	int32_t mcause = csr_read(mcause);
    // Interrupt if set, exception if cleared
	int32_t interrupt = mcause < 0;
	int32_t cause     = mcause & 0xF;

	if(interrupt){
		switch(cause){
			case CAUSE_MACHINE_EXTERNAL: {
				uartInterrupt(&rx_idx, rx_buf);
				break;
			}
			default: {
				break;
			}
		}
	}
}

// uart中断处理总函数
void uartInterrupt(u16 *rx_idx, u8 *buffer) {
    uint32_t claim;
	// 当存在等待响应的中断时
	while(claim = plic_claim(BSP_PLIC, BSP_PLIC_CPU_0)){
		switch(claim){
			// 中断类型为uart中断
			case SYSTEM_PLIC_SYSTEM_UART_0_IO_INTERRUPT: {
				uartInterruptSub(rx_idx, buffer);
				break;
			}
			default: {
				break;
			}
		}
        // 中断复位
		plic_release(BSP_PLIC, BSP_PLIC_CPU_0, claim);
	}
}

// uart中断处理子函数
void uartInterruptSub(u16 *rx_idx, u8 *buffer) {
	// 当TX FIFO为空时，中断.
	if (uart_status_read(BSP_UART_TERMINAL) & 0x00000100){
        // TX FIFO empty interrupt disable
		uart_status_write(BSP_UART_TERMINAL,uart_status_read(BSP_UART_TERMINAL) & 0xFFFFFFFE);
        // TX FIFO empty interrupt enable
		uart_status_write(BSP_UART_TERMINAL, uart_status_read(BSP_UART_TERMINAL) | 0x01);
	}
	// 当RX FIFO不为空时，中断.
	else if (uart_status_read(BSP_UART_TERMINAL) & 0x00000200){
        // RX FIFO not empty interrupt disable
		uart_status_write(BSP_UART_TERMINAL,uart_status_read(BSP_UART_TERMINAL) & 0xFFFFFFFD);
		// 将 UART FIFO 的数据读到缓冲数组中
        while(uart_readOccupancy(BSP_UART_TERMINAL)){
        	u32 val = uart_read(BSP_UART_TERMINAL);
        	buffer[*rx_idx] = val;
        	*rx_idx = *rx_idx + 1;
		}
        // RX FIFO not empty interrupt enable
		uart_status_write(BSP_UART_TERMINAL,uart_status_read(BSP_UART_TERMINAL) | 0x02);
	}
}

