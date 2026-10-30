

module top_e2prom(
    input               sys_clk    ,      //ϵͳʱ��
    input               sys_rst_n  ,      //ϵͳ��λ
    //eeprom interface
    output              iic_scl    ,      //eeprom��ʱ����scl
    inout               iic_sda    ,      //eeprom��������sda

    input  on1Switch,
    input  on2Switch,
    input  on3Switch,
    input  button_eeprom,

    input  [23:0] indata_on1Switch,
    input  [23:0] indata_on2Switch,
    input  [23:0] indata_on3Switch,

    output  [23:0] data_on1Switch,
    output  [23:0] data_on2Switch,
    output  [23:0] data_on3Switch,
    output [7:0]test,
    output read_flag,
    //user interface
    output              led               //led��ʾeeprom��д���Խ��
);

//parameter define
parameter    SLAVE_ADDR = 7'b1010000     ; //������ַ(SLAVE_ADDR)
parameter    BIT_CTRL   = 1'b1           ; //�ֵ�ַλ���Ʋ���(16b/8b)
parameter    CLK_FREQ   = 27'd100_000_000 ; //i2c_driģ�������ʱ��Ƶ��(CLK_FREQ)
parameter    I2C_FREQ   = 18'd250_000    ; //I2C��SCLʱ��Ƶ��
parameter    L_TIME     = 17'd125_000    ; //led��˸ʱ�����
parameter    MAX_BYTE   = 16'd9        ; //��д���Ե��ֽڸ���

//wire define
wire           dri_clk   ; //I2C����ʱ��
wire           i2c_exec  ; //I2C��������
wire   [15:0]  i2c_addr  ; //I2C������ַ
wire   [ 7:0]  i2c_data_w; //I2Cд�������
wire           i2c_done  ; //I2C����������־
wire           i2c_ack   ; //I2CӦ���־ 0:Ӧ�� 1:δӦ��
wire           i2c_rh_wl ; //I2C��д����
wire   [ 7:0]  i2c_data_r; //I2C����������
wire           rw_done   ; //E2PROM��д�������
wire           rw_result ; //E2PROM��д���Խ�� 0:ʧ�� 1:�ɹ� 
//*****************************************************
//**                    main code
//*****************************************************


/* reg on1Switch;
reg on2Switch;
reg on3Switch;  */

/* reg on1Switch;
reg on2Switch;
reg on3Switch;  */

//e2prom��д����ģ��
e2prom_rw u_e2prom_rw(
    .clk         (dri_clk   ),  //ʱ���ź�
    .rst_n       (sys_rst_n ),  //��λ�ź�
    //i2c interface
    .i2c_exec    (i2c_exec  ),  //I2C����ִ���ź�
    .i2c_rh_wl   (i2c_rh_wl ),  //I2C��д�����ź�
    .i2c_addr    (i2c_addr  ),  //I2C�����ڵ�ַ
    .i2c_data_w  (i2c_data_w),  //I2CҪд������
    .i2c_data_r  (i2c_data_r),  //I2C����������
    .i2c_done    (i2c_done  ),  //I2Cһ�β������
    .i2c_ack     (i2c_ack   ),  //I2CӦ���־ 

    .on1Switch(on1Switch),
    .on2Switch(on2Switch),
    .on3Switch(on3Switch),
    .button_eeprom(button_eeprom),

    .indata_on1Switch(indata_on1Switch),
    .indata_on2Switch(indata_on2Switch),
    .indata_on3Switch(indata_on3Switch),

    .data_on1Switch(data_on1Switch),
    .data_on2Switch(data_on2Switch),
    .data_on3Switch(data_on3Switch), 

    .read_flag(read_flag),
    //user interface
    .rw_done     (rw_done   ),  //E2PROM��д�������
    .rw_result   (rw_result ),   //E2PROM��д���Խ�� 0:ʧ�� 1:�ɹ�
    .test(test)

);


//i2c����ģ��
i2c_dri #(
    .SLAVE_ADDR  (SLAVE_ADDR),  //EEPROM�ӻ���ַ
    .CLK_FREQ    (CLK_FREQ  ),  //ģ�������ʱ��Ƶ��
    .I2C_FREQ    (I2C_FREQ  )   //IIC_SCL��ʱ��Ƶ��
) u_i2c_dri(
    .clk         (sys_clk   ),  
    .rst_n       (sys_rst_n ),  
    //i2c interface
    .i2c_exec    (i2c_exec  ),  //I2C����ִ���ź�
    .bit_ctrl    (BIT_CTRL  ),  //������ַλ����(16b/8b)
    .i2c_rh_wl   (i2c_rh_wl ),  //I2C��д�����ź�
    .i2c_addr    (i2c_addr  ),  //I2C�����ڵ�ַ
    .i2c_data_w  (i2c_data_w),  //I2CҪд������
    .i2c_data_r  (i2c_data_r),  //I2C����������
    .i2c_done    (i2c_done  ),  //I2Cһ�β������
    .i2c_ack     (i2c_ack   ),  //I2CӦ���־
    .scl         (iic_scl   ),  //I2C��SCLʱ���ź�
    .sda         (iic_sda   ),  //I2C��SDA�ź�
    //user interface
    .dri_clk     (dri_clk   )   //I2C����ʱ��
);

//ledָʾģ��
rw_result_led #(.L_TIME(L_TIME  )   //����led��˸ʱ��
) u_rw_result_led(
    .clk         (dri_clk   ),  
    .rst_n       (sys_rst_n ), 
    
    .rw_done     (rw_done   ),  
    .rw_result   (rw_result ),
    .led         (led       )    
);

endmodule
