###### FPGA Configuration Settings
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]

###### 100MHz Oscilator Clock Pins
set_property -dict { PACKAGE_PIN D7 IOSTANDARD LVCMOS18 } [get_ports PL_CLK_100MHZ*]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -hierarchical -filter {NAME =~ "*PL_CLK_100MHZ"}]
create_clock -period 10.000 -name PL_CLK_OSC [get_ports PL_CLK_100MHZ*]

###### Reset Pin (Updated Name to iRstn_0 based on error log)
# 포트 이름 뒤에 _0을 붙이거나 *를 사용하여 매칭시킵니다.
set_property PACKAGE_PIN F8 [get_ports iRstn*]
set_property IOSTANDARD LVCMOS18 [get_ports iRstn*]

###### TFT LCD Control Pins (CHANGED LVCMOS12 -> LVCMOS18)
# Bank 65/66 conflict resolution: All must be 1.8V
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS18 } [get_ports TFT_DCLK*]
set_property -dict { PACKAGE_PIN E4 IOSTANDARD LVCMOS18 } [get_ports TFT_HSYNC*]
set_property -dict { PACKAGE_PIN F1 IOSTANDARD LVCMOS18 } [get_ports TFT_VSYNC*]
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS18 } [get_ports TFT_DE*]
set_property -dict { PACKAGE_PIN E1 IOSTANDARD LVCMOS18 } [get_ports TFT_BACKLIGHT*]

###### TFT LCD RGB Data Pins (CHANGED LVCMOS12 -> LVCMOS18)
set_property -dict { PACKAGE_PIN R3 IOSTANDARD LVCMOS18 } [get_ports TFT_R_DATA*[4]]
set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS18 } [get_ports TFT_R_DATA*[3]]
set_property -dict { PACKAGE_PIN U1 IOSTANDARD LVCMOS18 } [get_ports TFT_R_DATA*[2]]
set_property -dict { PACKAGE_PIN T3 IOSTANDARD LVCMOS18 } [get_ports TFT_R_DATA*[1]]
set_property -dict { PACKAGE_PIN T2 IOSTANDARD LVCMOS18 } [get_ports TFT_R_DATA*[0]]
set_property -dict { PACKAGE_PIN M1 IOSTANDARD LVCMOS18 } [get_ports TFT_G_DATA*[5]]
set_property -dict { PACKAGE_PIN M5 IOSTANDARD LVCMOS18 } [get_ports TFT_G_DATA*[4]]
set_property -dict { PACKAGE_PIN M4 IOSTANDARD LVCMOS18 } [get_ports TFT_G_DATA*[3]]
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS18 } [get_ports TFT_G_DATA*[2]]
set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS18 } [get_ports TFT_G_DATA*[1]]
set_property -dict { PACKAGE_PIN P3 IOSTANDARD LVCMOS18 } [get_ports TFT_G_DATA*[0]]
set_property -dict { PACKAGE_PIN N2 IOSTANDARD LVCMOS18 } [get_ports TFT_B_DATA*[4]]
set_property -dict { PACKAGE_PIN P1 IOSTANDARD LVCMOS18 } [get_ports TFT_B_DATA*[3]]
set_property -dict { PACKAGE_PIN N5 IOSTANDARD LVCMOS18 } [get_ports TFT_B_DATA*[2]]
set_property -dict { PACKAGE_PIN N4 IOSTANDARD LVCMOS18 } [get_ports TFT_B_DATA*[1]]
set_property -dict { PACKAGE_PIN M2 IOSTANDARD LVCMOS18 } [get_ports TFT_B_DATA*[0]]

###### OV5640 CIS Camera Pins
set_property -dict { PACKAGE_PIN G5 IOSTANDARD LVCMOS18 } [get_ports CAMERA_PCLK*]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -hierarchical -filter {NAME =~ "*CAMERA_PCLK"}]

set_property -dict { PACKAGE_PIN A7 IOSTANDARD LVCMOS18 } [get_ports *tri_o*[1]] ;#CAMERA_PWDN
set_property -dict { PACKAGE_PIN A6 IOSTANDARD LVCMOS18 } [get_ports *tri_o*[0]] ;#CAMERA_RESETn

# SCCB (I2C) Pins - Updated to match generic names better or include _0
# 기존 설정에서 *scl*로 잡히지 않는다면 정확한 이름을 명시해야 합니다.
# 아래는 에러 로그 기반으로 _0을 포함하거나 와일드카드를 넓게 잡은 것입니다.
set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS18 } [get_ports *CAMERA_SCCB_SCL*]
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS18 } [get_ports *CAMERA_SCCB_SDA*]

set_property -dict { PACKAGE_PIN F7 IOSTANDARD LVCMOS18 } [get_ports CAMERA_HSYNC*]
set_property -dict { PACKAGE_PIN G7 IOSTANDARD LVCMOS18 } [get_ports CAMERA_VSYNC*]
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS18 } [get_ports CAMERA_MCLK*]
set_property -dict { PACKAGE_PIN E5 IOSTANDARD LVCMOS18 } [get_ports CAMERA_DATA*[0]]
set_property -dict { PACKAGE_PIN D6 IOSTANDARD LVCMOS18 } [get_ports CAMERA_DATA*[1]]
set_property -dict { PACKAGE_PIN D5 IOSTANDARD LVCMOS18 } [get_ports CAMERA_DATA*[2]]
set_property -dict { PACKAGE_PIN C7 IOSTANDARD LVCMOS18 } [get_ports CAMERA_DATA*[3]]
set_property -dict { PACKAGE_PIN B6 IOSTANDARD LVCMOS18 } [get_ports CAMERA_DATA*[4]]
set_property -dict { PACKAGE_PIN C5 IOSTANDARD LVCMOS18 } [get_ports CAMERA_DATA*[5]]
set_property -dict { PACKAGE_PIN E8 IOSTANDARD LVCMOS18 } [get_ports CAMERA_DATA*[6]]
set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS18 } [get_ports CAMERA_DATA*[7]]