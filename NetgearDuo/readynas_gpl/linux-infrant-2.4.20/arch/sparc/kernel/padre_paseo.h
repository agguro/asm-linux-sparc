/*
 *  Hardware support for paseo board on PADRE system
 * 
 *  Infrant Technologies, Inc. Proprietary and Confidential
 *          Copyright (c) 2001, INFRANT
 *          All Rights Reserved
 *  
 *  (C) Copryright Infrant Technologies, Inc.  2001-
 *  Author: Bin Zhang
 */

#ifdef CONFIG_PADRE_PASEO

/* padre gpio */
#define PADRE_PASEO_GPIO_ACFAIL		0			// I
#define PADRE_PASEO_GPIO_EPHYIRQ	1			// I
#define PADRE_PASEO_GPIO_HWMONIRQ	2			// I
#define PADRE_PASEO_GPIO_RTC		3			// I
#define PADRE_PASEO_GPIO_POWERSW	4			// I
#define PADRE_PASEO_GPIO_PSON		5			// O active low
#define PADRE_PASEO_GPIO_GPIO6		6			// I/O
#define PADRE_PASEO_GPIO_GPIOINT	7			// I


/* I2C device ID pin 45,46,47 hardwired to 0 00101000 */
#define PADRE_PASEO_WB83782D		0x28
/* RTC device ID */
#define PADRE_PASEO_DS1337			0x68
/* winbond 83601 */
#define PADRE_PASEO_W83601			0x18
#define PADRE_PASEO_W83601_1			0x19
#define PADRE_PASEO_W83601_2			0x1a
#define PADRE_PASEO_W83601_3			0x1b
#define PADRE_PASEO_W83601_4			0x1c
#define PADRE_PASEO_W83601_5			0x1d
#define PADRE_PASEO_W83601_6			0x1e
#define PADRE_PASEO_W83601_7			0x1f // bridge to LCD
/* Fintek GPIO Expander */
#define PADRE_PASEO_F75111			0x4e
/* ICS device ID */
#define PADRE_PASEO_ICS				0x69

#define PADRE_PASEO_POWER_LED			9
#define PADRE_PASEO_POWER_LED_OFF		0xFD
#define PADRE_PASEO_POWER_LED_ON		0x8D
#define PADRE_PASEO_POWER_LED_BLINK		0xED

#define PADRE_PASEO_SYSTEMP			38			// VTIN3
#define PADRE_PASEO_THERMISTER1		39			// VTIN2
#define PADRE_PASEO_THERMISTER2		40			// VTIN1
#define PADRE_PASEO_VTT				36			// VCOREA
#define PADRE_PASEO_33V				34			// 3.3V
#define PADRE_PASEO_25V				31			// -12V
#define PADRE_PASEO_15V				29			// 5VSB
#define PADRE_PASEO_FAN1IO			20
#define PADRE_PASEO_FAN2IO			19
#define PADRE_PASEO_FAN3IO			18
#define PADRE_PASEO_PWMOUT1			23

// Windbond 83782D
#define WBMONITOR_CONFIG_REG			0x40
 #define WBMONITOR_CONFIG_REG_INIT		0x8
 #define WBMONITOR_CONFIG_REG_START		0x1

#define WBMONITOR_STATUS1_REG			0x41
#define WBMONITOR_STATUS2_REG			0x42
#define WBMONITOR_SMIMASK1_REG			0x43
#define WBMONITOR_SMIMASK2_REG			0x44
#define WBMONITOR_CHASCLR_REG			0x46
#define WBMONITOR_DIVSOR_REG			0x47
#define WBMONITOR_ADDR_REG				0x48
#define WBMONITOR_VIDID_REG				0x49
#define WBMONITOR_ADDR1_REG				0x4a
#define WBMONITOR_PINCTL_REG			0x4b
#define WBMONITOR_SELECT_REG			0x4c
#define WBMONITOR_FANCTL_REG			0x4d
#define WBMONITOR_BANK_REG				0x4e
 #define BMONITOR_BANK_HBACS			0x80
 #define BMONITOR_BANK_BANK0			0x00
 #define BMONITOR_BANK_BANK1			0x01
 #define BMONITOR_BANK_BANK2			0x02
 #define BMONITOR_BANK_BANK3			0x03
 #define BMONITOR_BANK_BANK4			0x04
 #define BMONITOR_BANK_BANK5			0x05

#define WBMONITOR_VENDOR_REG			0x4f
 #define WBMONITOR_VENDOR_ID			0x5ca3

#define WBMONITOR_THERMISTER1			0x27
#define WBMONITOR_THERMISTER2_HI		0x50
#define WBMONITOR_THERMISTER2_LO		0x51
#define WBMONITOR_THERMISTER3_HI		0x50
#define WBMONITOR_THERMISTER3_LO		0x51
#define WBMONITOR_VCOREA				0x20
#define WBMONITOR_V33					0x22
#define HWMONITOR_V5					0x23
#define WBMONITOR_V_12					0x25
#define WBMONITOR_BANK5					5
#define WBMONITOR_V5VSB					0x50
#define WBMONITOR_FAN1					0x28
#define WBMONITOR_FAN2					0x29
#define WBMONITOR_FAN3					0x2a

#define WBMONITOR_BANK0					0
#define WBMONITOR_FANDIV				0x5d
#define WBMONITOR_PWMOUT1_CTRL			0x5b
#define WBMONITOR_PWMOUT12_CLK			0x5c

#define WBMONITOR_DIODE_SELECT			0x59
  #define WBMONITOR_DIODE_SELECT_PII	0x70
  #define WBMONITOR_DIODE_SELECT_2N		0x00



#endif
