/*
 * readFlash.c
 *
 *  Created on: 2024年6月22日
 *      Author: RuiRo
 */


#include "readFlash.h"

//////////// zch start/////////////////
#define SPI_CS 0

// !!! FOR TEST ONLY !!!
//#define MAX_MEMSIZE (8*1024)
#define BURST_SIZE 32
#define USE_FIFO 1
//#define USE_FIFO 0

static void spiFlash_select(u32 spi, u32 cs){
	spi_select(spi, cs);
}

static void spiFlash_diselect(u32 spi, u32 cs){
	spi_diselect(spi, cs);
}

static void spiFlash_init_(u32 spi){
	Spi_Config spiCfg;
	spiCfg.cpol = 0;
	spiCfg.cpha = 0;
	spiCfg.mode = 0;
	spiCfg.clkDivider = 0;
	spiCfg.ssSetup = 2;
	spiCfg.ssHold = 2;
	spiCfg.ssDisable = 2;
	spi_applyConfig(spi, &spiCfg);
	spi_waitXferBusy(spi);
}

static void spiFlash_init_mode_(u32 spi, u32 mode ){
	Spi_Config spiCfg;
	spiCfg.cpol = 0;
	spiCfg.cpha = 0;
	spiCfg.mode = mode;
	spiCfg.clkDivider = 0;
	spiCfg.ssSetup = 2;
	spiCfg.ssHold = 2;
	spiCfg.ssDisable = 2;
	spi_applyConfig(spi, &spiCfg);
	spi_waitXferBusy(spi);
}

static void spiFlash_init(u32 spi, u32 cs){
	spiFlash_init_(spi);
	spiFlash_diselect(spi, cs);
}

static void spiFlash_wake_(u32 spi){
	spi_write(spi, 0xAB);
#if defined(DEFAULT_ADDRESS_BYTE) || defined(MX25_FLASH)
	//return to 3-byte addressing
	bsp_uDelay(300);
	spi_write(spi, 0xE9);
#endif
}

static void spiFlash_wake(u32 spi, u32 cs){
	spiFlash_select(spi,cs);
	spiFlash_wake_(spi);
	spiFlash_diselect(spi,cs);
	spi_waitXferBusy(spi);
}

static u32 spi_burst_read(u32 reg, uint8_t *ram){
    while(spi_cmdAvailability(reg) == 0);
    for(int i=0;i<BURST_SIZE;i++)
    	write_u32(SPI_CMD_READ, reg + SPI_DATA);
    while(spi_rspOccupancy(reg) < BURST_SIZE);
    for(int i=0;i<BURST_SIZE;i++){
    	u8 data = read_u32(reg + SPI_DATA);
    	ram[i] = data;
    }
}

static void spiFlash_f2m_(u32 spi, u32 flashAddress, u32 memoryAddress, u32 size){
	spi_write(spi, 0x0B);
	spi_write(spi, flashAddress >> 16);
	spi_write(spi, flashAddress >>  8);
	spi_write(spi, flashAddress >>  0);
	spi_write(spi, 0);
	uint8_t *ram = (uint8_t *) memoryAddress;
	bsp_printf("%s:start\r\n",__FUNCTION__);
#if USE_FIFO
	for(u32 idx = 0;idx < size/BURST_SIZE;idx++){
		spi_burst_read(SPI, ram);
		ram += BURST_SIZE;
#ifdef MAX_MEMSIZE
		if(idx>=MAX_MEMSIZE/BURST_SIZE)
			ram=(uint8_t *) memoryAddress;
#endif
	}
#else
	for(u32 idx = 0;idx < size;idx++){
		u8 value = spi_read(spi);
#ifdef MAX_MEMSIZE
		ram[idx%MAX_MEMSIZE] = value;
#else
		ram[idx] = value;
#endif
	}
#endif
	bsp_printf("%s:end\r\n",__FUNCTION__);
}

static void spiFlash_dual_f2m_(u32 spi, u32 flashAddress, u32 memoryAddress, u32 size){
	spi_write(spi, 0x3B);
	spi_write(spi, flashAddress >> 16);
	spi_write(spi, flashAddress >>  8);
	spi_write(spi, flashAddress >>  0);
	spi_write(spi, 0);
	spi_waitXferBusy(spi); // Make sure all spi data transferred before switching mode
	spiFlash_init_mode_(spi, 0x01); // change mode to dual data mode
	uint8_t *ram = (uint8_t *) memoryAddress;
	bsp_printf("%s:start\r\n",__FUNCTION__);
#if USE_FIFO
	for(u32 idx = 0;idx < size/BURST_SIZE;idx++){
		spi_burst_read(SPI, ram);
		ram += BURST_SIZE;
#ifdef MAX_MEMSIZE
		if(idx>=MAX_MEMSIZE/BURST_SIZE)
			ram=(uint8_t *) memoryAddress;
#endif
	}
#else
	for(u32 idx = 0;idx < size;idx++){
		u8 value = spi_read(spi);
#ifdef MAX_MEMSIZE
		ram[idx%MAX_MEMSIZE] = value;
#else
		ram[idx] = value;
#endif
	}
#endif
	bsp_printf("%s:end\r\n",__FUNCTION__);
	spiFlash_init_mode_(spi, 0x00); // change mode back to single data mode
}

static void spiFlash_quad_f2m_(u32 spi, u32 flashAddress, u32 memoryAddress, u32 size){
	spi_write(spi, 0x6B);
	spi_write(spi, flashAddress >> 16);
	spi_write(spi, flashAddress >>  8);
	spi_write(spi, flashAddress >>  0);
	spi_write(spi, 0);
	spi_waitXferBusy(spi); // Make sure all spi data transferred before switching mode
	spiFlash_init_mode_(spi, 0x02); // change mode to quad data mode
	uint8_t *ram = (uint8_t *) memoryAddress;
	bsp_printf("%s:start\r\n",__FUNCTION__);
#if USE_FIFO
	for(u32 idx = 0;idx < size/BURST_SIZE;idx++){
		spi_burst_read(SPI, ram);
		ram += BURST_SIZE;
#ifdef MAX_MEMSIZE
		if(idx>=MAX_MEMSIZE/BURST_SIZE)
			ram=(uint8_t *) memoryAddress;
#endif
	}
#else
	for(u32 idx = 0;idx < size;idx++){
		u8 value = spi_read(spi);
#ifdef MAX_MEMSIZE
		ram[idx%MAX_MEMSIZE] = value;
#else
		ram[idx] = value;
#endif
	}
#endif
	bsp_printf("%s:end\r\n",__FUNCTION__);
	spiFlash_init_mode_(spi, 0x00); // change mode back to single data mode
}

static void spiFlash_f2m(u32 spi, u32 cs, u32 flashAddress, u32 memoryAddress, u32 size){
    spiFlash_select(spi,cs);
    spiFlash_f2m_(spi, flashAddress, memoryAddress, size);
    spiFlash_diselect(spi,cs);
}

static void spiFlash_f2m_dual(u32 spi, u32 cs, u32 flashAddress, u32 memoryAddress, u32 size){
    spiFlash_select(spi,cs);
    spiFlash_dual_f2m_(spi, flashAddress, memoryAddress, size);
    spiFlash_diselect(spi,cs);
}

static void spiFlash_f2m_quad(u32 spi, u32 cs, u32 flashAddress, u32 memoryAddress, u32 size){
#if defined(DEFAULT_ADDRESS_BYTE) || defined(MX25_FLASH)
	spiFlash_enable_quad_access(spi,cs);
#endif
    spiFlash_select(spi,cs);
    spiFlash_quad_f2m_(spi, flashAddress, memoryAddress, size);
    spiFlash_diselect(spi,cs);
}

//////////// zch end/////////////////

void init(){
    //SPI init
    Spi_Config spiA;
    spiA.cpol = 1;
    spiA.cpha = 1;
    //Assume full duplex (standard SPI)
    spiA.mode = 0;
    spiA.clkDivider = 10;
    spiA.ssSetup = 5;
    spiA.ssHold = 5;
    spiA.ssDisable = 5;
    spi_applyConfig(SPI, &spiA);
}

void WaitBusy(void)
{
    u8 out;
    u16 timeout=0;

    while(1)
    {
        bsp_uDelay(1*1000);
//    	DelayMsec(1000);
        spi_select(SPI, 0);
        //Write Enable
        spi_write(SPI, 0x05);
        out = spi_read(SPI);
        spi_diselect(SPI, 0);
        if((out & 0x01) ==0x00)
            return;
        timeout++;
        //sector erase max=400ms
        if(timeout >=400)
        {
//            bsp_printf("Time out \r\n");
            return;
        }
    }
}

void WriteEnableLatch(void)
{
    spi_select(SPI, 0);
    //Write Enable latch
    spi_write(SPI, 0x06);
    spi_diselect(SPI, 0);
}

void GlobalLock(void)
{
    WriteEnableLatch();
    spi_select(SPI, 0);
    //Global lock
    spi_write(SPI, 0x7E);
    spi_diselect(SPI, 0);
}

void GlobalUnlock(void)
{
    WriteEnableLatch();
    spi_select(SPI, 0);
    //Global unlock
    spi_write(SPI, 0x98);
    spi_diselect(SPI, 0);
}

void SectorErase(u32 Addr)
{
    WriteEnableLatch();
    spi_select(SPI, 0);
    //Erase Sector
    spi_write(SPI, 0x20);
    spi_write(SPI, (Addr>>16)&0xFF);
    spi_write(SPI, (Addr>>8)&0xFF);
    spi_write(SPI, Addr&0xFF);
    spi_diselect(SPI, 0);
    WaitBusy();
}

void readFrameFromFlash(uint32_t address_flash, uint32_t address_mem) {
    int times = 640 * 512 * 2;
    spiFlash_init(SPI, SPI_CS);
	spiFlash_wake(SPI, SPI_CS);
	spiFlash_f2m_quad(SPI, SPI_CS, address_flash, address_mem, times);

}




void writeFrameToFlash(u16 k[], uint32_t address_start) {
	init();
	u8 out;
	uint32_t i;
	uint32_t len =256;
	uint32_t Sector_size = 4096;
	uint32_t times = 640 * 512 * 2 / len;
	uint32_t times_erase = 640 * 512 * 2 / Sector_size;
	uint32_t page_erase_size = 64 * 1024;
	uint32_t address = address_start;
	GlobalUnlock();
	//Write sequential number for testing
	for(int time_erase = 0; time_erase < times_erase; time_erase++) {
		SectorErase(address);
		address += Sector_size;
	}

	address = address_start;
	for(int time = 0; time < times; time++) {
		WriteEnableLatch();
		spi_select(SPI, 0);
		spi_write(SPI, 0x02);
		spi_write(SPI, (address>>16)&0xFF);
		spi_write(SPI, (address>>8)&0xFF);
		spi_write(SPI, address&0xFF);
		for(i=0;i<len;i++)
		{
			uint16_t data;
			int number;
			number = (time * 256 + i) / 2;
			data = k[number];
			// 一次写8位
			if(i % 2 == 1) {
				spi_write(SPI, (data >> 8) & 0xFF);
			}
			else {
				spi_write(SPI, data & 0xFF);
			}

		}
		spi_diselect(SPI, 0);
		address += len;
        WaitBusy();
	}
	//wait for page progarm done
	WaitBusy();
	GlobalLock();
}



void WriteHEXToFlash(uint8_t hex[4096], uint32_t adress_hex) {
	init();
	uint32_t i;
	uint32_t len =256;
	uint32_t Sector_size = 4096;
	uint32_t times = Sector_size / len;
	uint32_t times_erase = 640 * 512 * 2 / Sector_size;
	uint32_t address = adress_hex;
	GlobalUnlock();
	//Write sequential number for testing
	SectorErase(address);

	for(int time = 0; time < times; time++) {
		WriteEnableLatch();
		spi_select(SPI, 0);
		spi_write(SPI, 0x02);
		spi_write(SPI, (address>>16)&0xFF);
		spi_write(SPI, (address>>8)&0xFF);
		spi_write(SPI, address&0xFF);
		for(i=0;i<len;i++)
		{
			uint32_t data;
			int number;
			number = time * 256 + i;
			data = hex[number];
			spi_write(SPI, data & 0xFF);

		}
		spi_diselect(SPI, 0);
		address += len;
        WaitBusy();
	}
	//wait for page progarm done
	WaitBusy();
	GlobalLock();
}


void CopyHex(uint32_t Address_tmp, uint32_t Address, uint32_t times){
	init();
	uint32_t i;
	uint32_t len =256;
	uint32_t Sector_size = 4096;
	uint8_t data = 0;
	uint32_t address_src;
	uint32_t address_dst;
	uint32_t write_times = Sector_size/len;


	for (int i = 0; i < times; i++){
		address_src = Address_tmp + i*Sector_size;
		address_dst = Address + i*Sector_size;
		//先读出一个sector的内容
		for (int j=0;j<Sector_size;j++){
			spi_select(SPI, 0);
			spi_write(SPI, 0x03);
			spi_write(SPI, ((address_src + j)>>16)&0xFF);
			spi_write(SPI, ((address_src + j)>>8)&0xFF);
			spi_write(SPI, (address_src + j)&0xFF);
			Sector[j] = spi_read(SPI);
			spi_diselect(SPI, 0);
		}

		GlobalUnlock();
		SectorErase(address_dst);
		//写一个sector的内容
		for(int k = 0; k < write_times; k++) {
			WriteEnableLatch();
			spi_select(SPI, 0);
			spi_write(SPI, 0x02);
			spi_write(SPI, (address_dst>>16)&0xFF);
			spi_write(SPI, (address_dst>>8)&0xFF);
			spi_write(SPI, address_dst&0xFF);
			for(int l=0;l<len;l++)
			{
				int number;
				number = k * 256 + l;
				data = Sector[number];
				spi_write(SPI, data & 0xFF);

			}
			spi_diselect(SPI, 0);
			address_dst += len;
			WaitBusy();
		}
		//wait for page progarm done
		WaitBusy();
		GlobalLock();
	}
}





void writeParamToFlash(u8 param[4096],uint32_t address) {
		init();
		uint32_t i;
		uint32_t len =256;
		uint32_t Sector_size = 4096;
		uint32_t times = Sector_size / len;
		GlobalUnlock();
		//Write sequential number for testing
		SectorErase(address);

		for(int time = 0; time < times; time++) {
			WriteEnableLatch();
			spi_select(SPI, 0);
			spi_write(SPI, 0x02);
			spi_write(SPI, (address>>16)&0xFF);
			spi_write(SPI, (address>>8)&0xFF);
			spi_write(SPI, address&0xFF);
			for(i=0;i<len;i++)
			{
				uint32_t data;
				int number;
				number = time * 256 + i;
				data = param[number];
				spi_write(SPI, data & 0xFF);

			}
			spi_diselect(SPI, 0);
			address += len;
	        WaitBusy();
		}
		//wait for page progarm done
		WaitBusy();
		GlobalLock();
}

uint8_t* readParamFromFlash(uint32_t address) {
    init();
	uint32_t Sector_size = 4096;
    uint8_t data = 0;
    static uint8_t param[4096];
	for (int i=0;i<Sector_size;i++){
		spi_select(SPI, 0);
		spi_write(SPI, 0x03);
		spi_write(SPI, ((address + i)>>16)&0xFF);
		spi_write(SPI, ((address + i)>>8)&0xFF);
		spi_write(SPI, (address + i)&0xFF);
		param[i] = spi_read(SPI);
		spi_diselect(SPI, 0);
	}

    return param;
}

