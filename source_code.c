/*
Vivado 프로젝트에서 Xilinx IIC IP를 이용하여 CAN 모듈의 SCCB(Serial Camera Control Bus 인터페이스)와 연결,
Xilinx에서는 xilinx IIC IP와 Zynq I2C IP와 호환되는 C 라이브러리를 지원해줌. 
xiic 라이브러리에 있는 C 함수들을(a.k.a API) 사용하여 CAM모듈의 레지스터에 값을 쓸것임.
지원되는 함수 각각에 대한 정보는 다음 사이트를 참고바람
https://xilinx.github.io/embeddedsw.github.io/iic/doc/html/api/group___overview.html#ga0a4d9b646c26bcf932561699d69d52b1 
*/
#include <stdio.h>
#include <unistd.h>
#include "xparameters.h"
#include "xiicps.h"          // PS I2C Driver
#include "xgpiops.h"         // [수정] PS GPIO Driver (AXI GPIO 아님)
#include "xil_printf.h"
#include "xil_io.h"          // Register Access
#include "sleep.h"
#include "CamConfigData.h"   // Camera Config Array

#define IIC_DEVICE_ID      0
#define OV5640_IIC_ADDR    0x78  // 8bit 기준: 0x78=Write, 0x79=Read → 드라이버에는 7bit로 전달: 0x3C(Write) 0x3E(Read)
#define AXI_IIC_ADDRESS    0xA0010000
#define AXI_GPIO_ADDRESS   0xA0000000

#define AXI_KERNEL_BASE   0xA0030000
#define CNN_MODE_REG_ADDR   0xA0020000

XIic Iic;

// SCCB 방식의 레지스터 Write (16bit Address + 8bit Data)
int SCCB_WriteRegister(u16 reg, u8 data) {
    u8 buf[3];
    int Status;

    buf[0] = (reg >> 8) & 0xFF;  // High byte
    buf[1] = reg & 0xFF;         // Low byte
    buf[2] = data;

    Status = XIic_Send(AXI_IIC_ADDRESS, OV5640_IIC_ADDR >> 1, buf, 3, XIIC_STOP);//Xilinx API, 입력 인자들에 대한 정보는 사이트 참고바람
    if (Status != 3) {
        xil_printf("SCCB Write Error: reg=0x%04X, data=0x%02X, Status=%d\r\n", reg, data, Status);
        return XST_FAILURE;
    }

    while (XIic_IsIicBusy(AXI_IIC_ADDRESS));
    return XST_SUCCESS;
}

// OV5640 전체 초기화 시퀀스
int Initialize_OV5640() {
    int status;
    extern const iic_ov5640_t Config[];

    int num_regs = sizeof(Config) / sizeof(Config[0]);;//CamConfigData.h에 있는 데이터 갯수 파악
    for (int i = 0; i < num_regs; i++) {
        status = SCCB_WriteRegister(Config[i].RegOffset, Config[i].RegData);
        if (status != XST_SUCCESS) {
            xil_printf("Failed at index %d, Reg=0x%04X\r\n", i, Config[i].RegOffset);
            return status;
        }
    }

    xil_printf("OV5640 Initialization complete. %d registers written.\r\n", num_regs);
    return XST_SUCCESS;
}



// ============================================================================
// [함수] CNN 모드 변경 (기존 코드 유지)
// ============================================================================
void Set_CNN_Mode(int mode) {
    // AXI Lite Register에 값 쓰기 (Offset 0x00)
    Xil_Out32(CNN_MODE_REG_ADDR, (u32)mode);
    
    xil_printf("\n---> Mode Changed: ");
    switch(mode) {
        case 0: xil_printf("Bypass (Original)\r\n"); break;
        case 1: xil_printf("Sharpen Filter\r\n"); break;
        case 2: xil_printf("Edge Detection (Laplacian)\r\n"); break;
        default: xil_printf("Unknown\r\n"); break;
    }
}

// -----------------------------------------------------------------------------
// [함수] AXI 커널 값 설정 (9개 값 입력)
// -----------------------------------------------------------------------------
void Set_CNN_Kernel(int k0, int k1, int k2, int k3, int k4, int k5, int k6, int k7, int k8) {
    Xil_Out32(AXI_KERNEL_BASE + 0x00, k0);
    Xil_Out32(AXI_KERNEL_BASE + 0x04, k1);
    Xil_Out32(AXI_KERNEL_BASE + 0x08, k2);
    Xil_Out32(AXI_KERNEL_BASE + 0x0C, k3);
    Xil_Out32(AXI_KERNEL_BASE + 0x10, k4); // Center
    Xil_Out32(AXI_KERNEL_BASE + 0x14, k5);
    Xil_Out32(AXI_KERNEL_BASE + 0x18, k6);
    Xil_Out32(AXI_KERNEL_BASE + 0x1C, k7);
    Xil_Out32(AXI_KERNEL_BASE + 0x20, k8);
    
    xil_printf("   Kernel Updated (Center=%d)\r\n", k4);
}


int main() {

    //    unsigned int gpio_val;
    //CAM 모듈의 Resetn과 PWDN 핀 입력, FPGA의 PL GPIO 출력과 연결되어져 있음(Vivado 프로젝트 참고)
    //Resetn이 GPIO의 0번째 비트
    //2번째 비트 추가 : TFT 출력 상하반전.

    *(volatile unsigned int*)(AXI_GPIO_ADDRESS) = 0x2; // GPIO에 값을 쓰기 ; PWDN 1, Resetn : 0
    usleep(1000);//1ms 정도 쉬어준 후, RESET_N핀에 high(1)을 넣어 리셋을 풀어줌. OV5640 데이터시트, figure 2-3 power up timing with internal DVDD 그림 참조바람, 
    *(volatile unsigned int*)(AXI_GPIO_ADDRESS) = 0x1; // GPIO에 값을 쓰기 ; PWDN 0, Resetn : 1
    usleep(20000);//리셋을 풀고 20ms 정도 쉬어준 후 데이터를 쓸 수 있음.

    XIic_Config *IicConfig;//AXI IIC (Vivado Xilinx IP) 개체 호출
    int Status;

    IicConfig = XIic_LookupConfig(IIC_DEVICE_ID);//AXI IIC 내부 레지스터 정보 즉, Vivado 프로젝트에서 설정한 정보들 불러오기 (ex AXI IIC의 Base address, GPIO 의 Width, I2C 동작속도 및 기타 모드 설정값..)
    if (IicConfig == NULL) {
        xil_printf("IIC configuration not found!\r\n");
        return XST_FAILURE;
    }

    Status = XIic_CfgInitialize(&Iic, IicConfig, IicConfig->BaseAddress);//XIiC_LookupConfig함수를 통해 받은 AXI IIC의 데이터를 담긴 포인터로 불러오기
    if (Status != XST_SUCCESS) {
        xil_printf("IIC initialization failed!\r\n");
        return XST_FAILURE;
    }

    
    XIic_Start(&Iic);// Bus master mode 설정
    XIic_SetAddress(&Iic, XII_ADDR_TO_SEND_TYPE, OV5640_IIC_ADDR >> 1);

    // 초기화 시작
    Status = Initialize_OV5640();
    if (Status != XST_SUCCESS) {
        xil_printf("OV5640 configuration failed.\r\n");
        return XST_FAILURE;
    }

    
    // 4. Initial Mode Set
    Set_CNN_Mode(0); // Bypass

    // 5. Main Loop
    while(1) {
        xil_printf("\r\n[Menu] Select Mode:\r\n");
        xil_printf(" '0': Bypass\r\n");
        xil_printf(" '1': Sharpen\r\n");
        xil_printf(" '2': Edge Detect\r\n");
        xil_printf("Cmd > ");

        uart_input = inbyte(); // UART Receive (Blocking)
        xil_printf("%c\r\n", uart_input);

        if (uart_input >= '0' && uart_input <= '2') {
            Set_CNN_Mode(uart_input - '0');
        } else {
            xil_printf("Invalid Command.\r\n");
        }
        
        usleep(200000);
    }


    XIic_Stop(&Iic);
    xil_printf("DONE\r\n");
    return 0;
}

