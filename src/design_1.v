`timescale 1 ps / 1 ps

module design_1(
     input [7:0]OV7725_D,
     input OV7725_HREF,
     input OV7725_PCLK,
     output OV7725_SIOC,
     inout OV7725_SIOD,
     input OV7725_VSYNC,
     output OV7725_XCLK,
     input btn_ColorExrtract,
     input btn_ColorExrtract1,
     input btn_ColorExrtract2,
     input clk100,
     output [11:0] data_display_led,
     input rst,
     input sw_ColorClear,
     output [3:0]vga_blue,
     output [3:0]vga_green,
     output vga_hsync,
     output [3:0]vga_red,
     output vga_vsync,
     output txd_ov7725,//tx
     input SwitchUart,
     output [3:0] an,
     output [7:0] seg,
     output sclk,
     inout sdat,
     input button_eeprom,
     output led
);
     
     wire IICctrl_0_I2C_SCLK;
     wire [7:0]IICctrl_0_LUT_INDEX;
     wire Net;
     wire [7:0]OV7725_D_1;
     wire OV7725_HREF_1;
     wire OV7725_PCLK_1;
     wire OV7725_VSYNC_1;
     wire [15:0]blk_mem_gen_0_doutb;
     wire btn_ColorExrtract_0;
     wire btn_ColorExrtract_1;
     wire btn_ColorExrtract_2;
     wire [16:0]cam_ov7670_ov7725_0_addr;
     wire [15:0]cam_ov7670_ov7725_0_dout;
     wire cam_ov7670_ov7725_0_wclk;
     wire cam_ov7670_ov7725_0_we;
     wire clk100_1;
     wire clk_wiz_0_clk_out1;
     wire clk_wiz_0_clk_out2;
     wire colorDetect_0_Binary_PreProcess;
     wire [23:0]colorDetect_0_RGB24_dis;
     wire [11:0]colorDetect_0_center_h;
     wire [10:0]colorDetect_0_center_v;
     wire [11:0]colorDetect_0_center_h1;
     wire [10:0]colorDetect_0_center_v1;
     wire [11:0]colorDetect_0_center_h2;
     wire [10:0]colorDetect_0_center_v2;
     wire debounce_0_o;
     wire dilate_0_pix_o;
     wire erode_0_pix_o;
     wire [15:0]ov7725_regData_0_LUT_DATA;
     wire [7:0]ov7725_regData_0_Slave_Addr;
     wire [16:0]ram_read_0_address;
     wire [3:0]ram_read_0_vga_blue;
     wire [3:0]ram_read_0_vga_green;
     wire [3:0]ram_read_0_vga_red;
     wire [11:0]region_cut_0_valid_h_cnt;
     wire [10:0]region_cut_0_valid_v_cnt;
     wire [23:0]rgb2hsv_top_0_HSV24;
     wire [23:0]rgb565_rgb888_0_rgb888;
     wire [15:0]rgb888_rgb565_0_rgb565;
     wire rst_1;
     wire sw_ColorClear_1;
     wire [11:0]vga_0_vga_h_cnt;
     wire vga_0_vga_hsync;
     wire [10:0]vga_0_vga_v_cnt;
     wire vga_0_vga_valid;
     wire vga_0_vga_vsync;
     wire [0:0]xlconstant_0_dout;

     wire clk_38400;

     wire txd1;
     
     wire  dilate_0_pix_1;
     wire  erode_0_pix_1;
     wire colorDetect_0_Binary_PreProcess1;

     wire [11:0]counter_h;
     wire [11:0]counter_v;
     wire [11:0]counter_h1;
     wire [11:0]counter_v1;
     wire [11:0]counter_h2;
     wire [11:0]counter_v2;

     wire [11:0]counter_h_0;
     wire [11:0]counter_v_0;
     wire [11:0]counter_h1_0;
     wire [11:0]counter_v1_0;
     wire [11:0]counter_h2_0;
     wire [11:0]counter_v2_0;    

     wire [7:0] angle;
     wire [7:0] uarttemp;
     wire [11:0] uarttemp_bcd;

     wire [3:0] hex3_in;
     assign txd_ov7725 = txd1;

     assign uarttemp = SwitchUart ? angle : counter_v1;
     assign data_display_led = SwitchUart ? angle : counter_v1;
     assign hex3_in = SwitchUart ? 4'ha :4'hc;

     assign OV7725_D_1 = OV7725_D[7:0];
     assign OV7725_HREF_1 = OV7725_HREF;
     assign OV7725_PCLK_1 = OV7725_PCLK;
     assign OV7725_SIOC = IICctrl_0_I2C_SCLK;
     assign OV7725_VSYNC_1 = OV7725_VSYNC;
     assign OV7725_XCLK = clk_wiz_0_clk_out1;
     assign btn_ColorExrtract_0 = btn_ColorExrtract;
     assign btn_ColorExrtract_1 = btn_ColorExrtract1;
     assign btn_ColorExrtract_2 = btn_ColorExrtract2;
     assign clk100_1 = clk100;
     assign counter_h[11:0] = colorDetect_0_center_h;
     assign counter_v[10:0] = colorDetect_0_center_v;
     assign counter_h1[11:0] = colorDetect_0_center_h1;
     assign counter_v1[10:0] = colorDetect_0_center_v1;
     assign counter_h2[11:0] = colorDetect_0_center_h2;
     assign counter_v2[10:0] = colorDetect_0_center_v2;

     assign rst_1 = rst;
     assign sw_ColorClear_1 = sw_ColorClear;
     assign vga_blue[3:0] = ram_read_0_vga_blue;
     assign vga_green[3:0] = ram_read_0_vga_green;
     assign vga_hsync = vga_0_vga_hsync;
     assign vga_red[3:0] = ram_read_0_vga_red;
     assign vga_vsync = vga_0_vga_vsync;

     //IIC����
     IICctrl IICctrl_0(
          .I2C_SCLK(IICctrl_0_I2C_SCLK),
          .I2C_SDAT(OV7725_SIOD),
          .LUT_DATA(ov7725_regData_0_LUT_DATA),
          .LUT_INDEX(IICctrl_0_LUT_INDEX),
          .Slave_Addr(ov7725_regData_0_Slave_Addr),
          .iCLK(clk_wiz_0_clk_out1),
          .rst(debounce_0_o)
     );
     //OV7725�Ĵ�������
     ov7725_regData ov7725_regData_0(
          .LUT_DATA(ov7725_regData_0_LUT_DATA),
          .LUT_INDEX(IICctrl_0_LUT_INDEX),
          .Slave_Addr(ov7725_regData_0_Slave_Addr)
     );

     //��RAM
     blk_mem_gen_0 blk_mem_gen_0(
          .addra(cam_ov7670_ov7725_0_addr),
          .addrb(ram_read_0_address),
          .clka(cam_ov7670_ov7725_0_wclk),
          .clkb(clk_wiz_0_clk_out1),
          .dina(cam_ov7670_ov7725_0_dout),
          .doutb(blk_mem_gen_0_doutb),
          .wea(cam_ov7670_ov7725_0_we)
     );

     //����ͷDVPЭ��
     cam_ov7670_ov7725 cam_ov7670_ov7725_0(
          .addr(cam_ov7670_ov7725_0_addr),
          .d(OV7725_D_1),
          .dout(cam_ov7670_ov7725_0_dout),
          .href(OV7725_HREF_1),
          .pclk(OV7725_PCLK_1),
          .vsync(OV7725_VSYNC_1),
          .wclk(cam_ov7670_ov7725_0_wclk),
          .we(cam_ov7670_ov7725_0_we)
     );

     //PLLʱ�ӷ�Ƶ25MHz
     clk_wiz_0 clk_wiz_0(
          .clk_in1(clk100_1),
          .clk_out1(clk_wiz_0_clk_out1)
     );

     wire [23:0]Switch1;
     wire [23:0]Switch2;
     wire [23:0]Switch3;
     wire [23:0] inSwitch1;
     wire [23:0] inSwitch2;
     wire [23:0] inSwitch3;
     
     //������ʶ����������ȡ
     wire read_flag;
     colorDetect colorDetect_0(
          .HSV24(rgb2hsv_top_0_HSV24),
          .rst_n(~sw_ColorClear),
          .PClk(clk_wiz_0_clk_out1),
          .RGB24(rgb565_rgb888_0_rgb888),
          .RGB24_dis(colorDetect_0_RGB24_dis),
          .VtcHCnt(region_cut_0_valid_h_cnt),
          .VtcVCnt(region_cut_0_valid_v_cnt),
          .sw_ColorClear(sw_ColorClear_1),

          .btn_ColorExtract(btn_ColorExrtract_0),
          .center_h(colorDetect_0_center_h),
          .center_v(colorDetect_0_center_v),
          .Binary_PostProcess(dilate_0_pix_o),
          .Binary_PreProcess(colorDetect_0_Binary_PreProcess),

          .btn_ColorExtract1(btn_ColorExrtract_1),
          .center_h1(colorDetect_0_center_h1),
          .center_v1(colorDetect_0_center_v1),
          .Binary_PostProcess1(dilate_0_pix_1),
          .Binary_PreProcess1(colorDetect_0_Binary_PreProcess1),

          .btn_ColorExtract2(btn_ColorExrtract_2),
          .center_h2(colorDetect_0_center_h2),
          .center_v2(colorDetect_0_center_v2),
          .Binary_PostProcess2(dilate_0_pix_2),
          .Binary_PreProcess2(colorDetect_0_Binary_PreProcess2),

          .indata_on1Switch(Switch1),//���
          .indata_on2Switch(Switch2),//color ->eeprom
          .indata_on3Switch(Switch3),

          .read_flag(read_flag),
          .data_on1Switch(inSwitch1),//����
          .data_on2Switch(inSwitch2),
          .data_on3Switch(inSwitch3)
     );
     wire [7:0]test;
     top_e2prom  #(
          .MAX_BYTE   (9 )   //��д���Ե��ֽڸ���
     ) u_e2prom_top(
          .sys_clk    (clk100 ),  //ϵͳʱ��
          .sys_rst_n  (~sw_ColorClear),  //ϵͳ��λ
          //eeprom interface
          .iic_scl    (sclk  ),  //eeprom��ʱ����scl
          .iic_sda    (sdat  ),  //eeprom��������sda
     
          .on1Switch(btn_ColorExrtract),
          .on2Switch(btn_ColorExrtract1),
          .on3Switch(btn_ColorExrtract2),
          .button_eeprom(button_eeprom),
     
          .indata_on1Switch(Switch1),
          .indata_on2Switch(Switch2),
          .indata_on3Switch(Switch3),
          .read_flag(read_flag),
          .data_on1Switch(inSwitch1),//输出
          .data_on2Switch(inSwitch2),
          .data_on3Switch(inSwitch3),
          .test(test),
          //user interface
          .led     (led  )   //led��ʾ
     );

     

     //��������������ͻ
     debounce debounce_0(
          .clk(clk_wiz_0_clk_out1),
          .clr(xlconstant_0_dout),
          .i(rst_1),
          .o(debounce_0_o)
     );

     //����
     //��ǿ����������
     dilate dilate_0(
          .PCLK(clk_wiz_0_clk_out1),
          .VtcHCnt(region_cut_0_valid_h_cnt),
          .VtcVCnt(region_cut_0_valid_v_cnt),
          .pix_i(erode_0_pix_o),
          .pix_o(dilate_0_pix_o)
     );
     dilate dilate_1(
          .PCLK(clk_wiz_0_clk_out1),
          .VtcHCnt(region_cut_0_valid_h_cnt),
          .VtcVCnt(region_cut_0_valid_v_cnt),
          .pix_i(erode_0_pix_1),
          .pix_o(dilate_0_pix_1)
     );
     dilate dilate_2(
          .PCLK(clk_wiz_0_clk_out1),
          .VtcHCnt(region_cut_0_valid_h_cnt),
          .VtcVCnt(region_cut_0_valid_v_cnt),
          .pix_i(erode_0_pix_2),
          .pix_o(dilate_0_pix_2)
     );
     
     //��ʴ
     //��������С������������塣
     erode erode_0(
          .PCLK(clk_wiz_0_clk_out1),
          .VtcHCnt(region_cut_0_valid_h_cnt),
          .VtcVCnt(region_cut_0_valid_v_cnt),
          .pix_i(colorDetect_0_Binary_PreProcess),
          .pix_o(erode_0_pix_o)
     );
     erode erode_1(
          .PCLK(clk_wiz_0_clk_out1),
          .VtcHCnt(region_cut_0_valid_h_cnt),
          .VtcVCnt(region_cut_0_valid_v_cnt),
          .pix_i(colorDetect_0_Binary_PreProcess1),
          .pix_o(erode_0_pix_1)
     );
     erode erode_2(
          .PCLK(clk_wiz_0_clk_out1),
          .VtcHCnt(region_cut_0_valid_h_cnt),
          .VtcVCnt(region_cut_0_valid_v_cnt),
          .pix_i(colorDetect_0_Binary_PreProcess2),
          .pix_o(erode_0_pix_2)
     );

     //Ϊ���������ȡ��������
     region_cut region_cut_0(
          .valid_h_cnt(region_cut_0_valid_h_cnt),//out
          .valid_v_cnt(region_cut_0_valid_v_cnt),//out
          .vga_h_cnt(vga_0_vga_h_cnt),
          .vga_v_cnt(vga_0_vga_v_cnt)
     );

     //����������������нǶȼ���
     angle_calculation angle_calculation(
          .clk(clk100),
          .rst_n(~debounce_0_o),
          .site_x1(counter_h),
          .site_y1(counter_v),
          .site_x2(counter_h1),
          .site_y2(counter_v1),
          .site_x3(counter_h2),
          .site_y3(counter_v2),
          .angle(angle)// ����Ƕ��������֣�������Ҫ����λ��
     );

     //RAM ��ȡ
     ram_read ram_read_0(
          .address(ram_read_0_address),
          .clk(clk_wiz_0_clk_out1),
          .din(rgb888_rgb565_0_rgb565),
          .valid(vga_0_vga_valid),
          .vga_blue(ram_read_0_vga_blue),
          .vga_green(ram_read_0_vga_green),
          .vga_h_cnt(vga_0_vga_h_cnt),
          .vga_red(ram_read_0_vga_red),
          .vga_v_cnt(vga_0_vga_v_cnt)
     );
     
     //��RGB565ת��RGB888���Ա����RGBתHSV�Ĳ���
     rgb565_rgb888 rgb565_rgb888_0(
          .rgb565(blk_mem_gen_0_doutb),
          .rgb888(rgb565_rgb888_0_rgb888)
     );

     //RGBתHSV
     rgb2hsv_top rgb2hsv_top_0(
          .HSV24(rgb2hsv_top_0_HSV24),
          .RGB24(rgb565_rgb888_0_rgb888),
          .pclk(clk_wiz_0_clk_out1)
     );
     
     //��RGB888ת��RGB565���Ա�VGA��ʾ
     rgb888_rgb565 rgb888_rgb565_0(
          .rgb565(rgb888_rgb565_0_rgb565),
          .rgb888(colorDetect_0_RGB24_dis)
     );

     //vga��ʾ
     vga vga_0(
          .vga_h_cnt(vga_0_vga_h_cnt),
          .vga_hsync(vga_0_vga_hsync),
          .vga_pclk(clk_wiz_0_clk_out1),
          .vga_rst(debounce_0_o),
          .vga_v_cnt(vga_0_vga_v_cnt),
          .vga_valid(vga_0_vga_valid),
          .vga_vsync(vga_0_vga_vsync)
     );

     //���ڷ�Ƶ 
     clk_div clk_uart38400(
          .clk(clk_wiz_0_clk_out1),
          .clk_out(clk_38400)
     );

     //���ڷ���
     uart_tx uart_tx_0(
          .data_o(uarttemp),
          .txd(txd1),
          .clk(clk_38400)
     );

     //��ͼ���������ֵת��ΪBCD��
     bin2bcd # (    
          .WIDTH_BIN(8),
          .WIDTH_BCD(12)
     )bin2bcd_0(
	     .bin(uarttemp),                
	     .bcd(uarttemp_bcd)
     );

     //��ת���õ�BCD����ʾ���������
     scan_led_hex_disp scan_led_hex_disp_0(
          .clk(clk_wiz_0_clk_out1),                     
          .reset(1'b0),
          .hex3(hex3_in),
          .hex2(uarttemp_bcd[11:8]), 
          .hex1(uarttemp_bcd[7:4]),
          .hex0(uarttemp_bcd[3:0]),
          .dp_in(4'b1111),
          .an(an),
          .sseg(seg)
     );
endmodule
