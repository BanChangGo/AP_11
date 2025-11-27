# ----------------------------------------------------------------------------
# TFT LCD Control Pins
# ----------------------------------------------------------------------------
# 만약 Top 모듈에서 LCD Clock을 내보내는 포트 이름이 LCD_clk_o 라면 아래 주석을 풀고 사용하세요.
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS12} [get_ports lcd_clk]

set_property -dict {PACKAGE_PIN E4 IOSTANDARD LVCMOS12} [get_ports LCD_hsync_o]
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS12} [get_ports LCD_vsync_o]

# LCD_de_o 포트가 Top 모듈에 있다면 아래 주석을 풀고 사용하세요 (Data Enable)
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS12} [get_ports LCD_de_o]
set_property PACKAGE_PIN E1 [get_ports TFT_BACKLIGHT]
set_property IOSTANDARD LVCMOS12 [get_ports TFT_BACKLIGHT]
# ----------------------------------------------------------------------------
# TFT LCD RGB Data Pins
# ----------------------------------------------------------------------------

# Red (5 bits: 4 downto 0)
set_property -dict {PACKAGE_PIN R3 IOSTANDARD LVCMOS12} [get_ports {LCD_R_o[4]}]
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS12} [get_ports {LCD_R_o[3]}]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD LVCMOS12} [get_ports {LCD_R_o[2]}]
set_property -dict {PACKAGE_PIN T3 IOSTANDARD LVCMOS12} [get_ports {LCD_R_o[1]}]
set_property -dict {PACKAGE_PIN T2 IOSTANDARD LVCMOS12} [get_ports {LCD_R_o[0]}]

# Green (6 bits: 5 downto 0)
set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS12} [get_ports {LCD_G_o[5]}]
set_property -dict {PACKAGE_PIN M5 IOSTANDARD LVCMOS12} [get_ports {LCD_G_o[4]}]
set_property -dict {PACKAGE_PIN M4 IOSTANDARD LVCMOS12} [get_ports {LCD_G_o[3]}]
set_property -dict {PACKAGE_PIN L2 IOSTANDARD LVCMOS12} [get_ports {LCD_G_o[2]}]
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS12} [get_ports {LCD_G_o[1]}]
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS12} [get_ports {LCD_G_o[0]}]

# Blue (5 bits: 4 downto 0)
set_property -dict {PACKAGE_PIN N2 IOSTANDARD LVCMOS12} [get_ports {LCD_B_o[4]}]
set_property -dict {PACKAGE_PIN P1 IOSTANDARD LVCMOS12} [get_ports {LCD_B_o[3]}]
set_property -dict {PACKAGE_PIN N5 IOSTANDARD LVCMOS12} [get_ports {LCD_B_o[2]}]
set_property -dict {PACKAGE_PIN N4 IOSTANDARD LVCMOS12} [get_ports {LCD_B_o[1]}]
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS12} [get_ports {LCD_B_o[0]}]

# LCD_de_o 포트 연결 (Data Enable)
# 핀 번호(E3)는 보드 매뉴얼에 따라 다를 수 있으니 확인 필요 (아까 주신 정보 기준 E3)
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS12} [get_ports LCD_de_o]

set_property PACKAGE_PIN F8 [get_ports iRstn]
set_property PACKAGE_PIN D7 [get_ports iClk_100]
set_property IOSTANDARD LVCMOS18 [get_ports iClk_100]
set_property IOSTANDARD LVCMOS18 [get_ports iRstn]
