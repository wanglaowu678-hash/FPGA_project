
module e2prom_rw(
    input                 clk        , //时钟信号
    input                 rst_n      , //复位信号

    //i2c interface
    output   reg          i2c_rh_wl  , //I2C读写控制信号
    output   reg          i2c_exec   , //I2C触发执行信号
    output   reg  [15:0]  i2c_addr   , //I2C器件内地址
    output   reg  [ 7:0]  i2c_data_w , //I2C要写的数据
    input         [ 7:0]  i2c_data_r , //I2C读出的数据
    input                 i2c_done   , //I2C一次操作完成
    input                 i2c_ack    , //I2C应答标志

    //user interface
    output   reg          rw_done    , //E2PROM读写测试完成
    output   reg          rw_result   ,//E2PROM读写测试结果 0:失败 1:成功


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
    output read_flag,
    output  reg [7:0]test
);

/* //输入按键
wire [3:0]switch ;
wire [3:0]debounced_switch;
assign switch ={clearSwitch,on1Switch,on2Switch,on3Switch};
wire [3:0]switch1 ;

delay S1 (
    .clk( clk ),
    .nrst( 1'b1 ),
    .ena( 1'b1 ),

    .in( switch ),
    .out( switch1 )
);


//上升沿检测
reg [3:0]rising_edge1;
reg [3:0]rising_edge2;
initial begin
    rising_edge1 =0;
    rising_edge2 =0;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        rising_edge1 <=0;
        rising_edge2 <=0;
    end
    else begin
        rising_edge1 <=switch1;
        rising_edge2 <=rising_edge1;
    end
end
wire [3:0]rise_detect;
assign rise_detect = rising_edge1 & ~rising_edge2;



//上单1s后delay_1s脉冲置1
wire delay_1s;
wire delay_flag;
wire button_flag;
delay_pulse_generator1s 
#(
    .CLOCK_FREQ(100_000_000)
)
delay_pulse_generator1s(
    .clk(clk),
    .reset(~rst_n),
    .pulse(delay_1s)
); */

//parameter define
//EEPROM写数据需要添加间隔时间,读数据则不需要
parameter      WR_WAIT_TIME = 15'd10000; //写入间隔时间
parameter      MAX_BYTE     = 16'd9 ; //读写测试的字节个数

//reg define
reg   [4:0]    flow_cnt  ; //状态流控制
reg   [14:0]   wait_cnt  ; //延时计数器

reg [7:0] data_storage [8:0];  // 9个元素的数组，每个元素8位宽


reg [15:0] i;  // 用于索引数组
reg [15:0] k;
integer j;

initial begin
    for (j = 0; j < 9; j = j + 1) begin
        data_storage[j] <= 8'b0;
    end
end

//*****************************************************
//**                    main code
//***************************************************re**

// 用于跟踪每个按钮是否被按下过一次
reg [2:0] button_pressed;
reg  button_pressed1;
reg flag; // 触发 EEPROM 写入操作的标志
reg [4:0]flow_cnt1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        button_pressed <= 3'b000; // 重置按钮状态
        button_pressed1 <=0;
        flag <=0;
        test <=0;
    end else begin
        // 检测按钮按下
        if (on1Switch & ~button_pressed[0]) button_pressed[0] <= 1;
        if (on2Switch & ~button_pressed[1]) button_pressed[1] <= 1;
        if (on3Switch & ~button_pressed[2]) button_pressed[2] <= 1;
        if ( button_eeprom & ~button_pressed1)button_pressed1 <=1;
        // 检测是否所有按钮都至少被按下过一次
/*         if (button_pressed == 3'b111 & ~flag) begin
            flag <= 1;
            //flow_cnt <= 10; // 开始 EEPROM 写入过程
            //test <= 8'h11;
        end */
    end
end
/* always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        flow_cnt1 <=0;
        test <=0;
    end
    else if(flow_cnt ==0)begin
        flow_cnt<=flow_cnt1;
        test <= flow_cnt1;
    end
end */

//assign flow_cnt=flow_cnt1;

//assign test = button_pressed;
reg rx_flag;
//EEPROM读写测试,先写后读，并比较读出的值与写入的值是否一致
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        i2c_rh_wl  <= 0;
        i2c_exec   <= 0;
        i2c_addr   <= 0;
        i2c_data_w <= 0;
        wait_cnt   <= 0;
        rw_done    <= 0;
        rw_result  <= 0;
        flow_cnt   <=10;
        rx_flag<=0;
        i<=0;     
        k <=0;   
    end
    else begin
        i2c_exec <= 0;
        if(button_pressed == 3'b111 )begin
            case(flow_cnt)
                10 : begin                                  
                    wait_cnt <= wait_cnt + 1;               //延时计数
                    if(wait_cnt == (WR_WAIT_TIME -1)) begin  //EEPROM写操作延时完成
                        wait_cnt <= 0;
                        if(i2c_addr == MAX_BYTE+1) begin         //字节写入完成

                        end
                        else begin
                            flow_cnt <= flow_cnt + 1;
                            i2c_exec <= 1;
                        end
                    end
                end
                11 : begin
                    if(i2c_done == 1) begin                  //EEPROM单次写入完成
                        flow_cnt   <= 10;
                        i2c_addr   <= i2c_addr + 1;           //地址0~255分别写入
                        case (k)
                            0:i2c_data_w<=indata_on1Switch[23:16];
                            1:i2c_data_w<=indata_on1Switch[15:8];
                            2:i2c_data_w<=indata_on1Switch[7:0];
                            3:i2c_data_w<=indata_on2Switch[23:16];
                            4:i2c_data_w<=indata_on2Switch[15:8];
                            5:i2c_data_w<=indata_on2Switch[7:0];
                            6:i2c_data_w<=indata_on3Switch[23:16];
                            7:i2c_data_w<=indata_on3Switch[15:8];
                            8:i2c_data_w<=indata_on3Switch[7:0];
                            default: i2c_data_w <=0;
                        endcase
                        k <= k+1;
                    end    
                end
                default :;
            endcase 
        end

                if(button_pressed1==1 && !rx_flag)begin
                    flow_cnt <=2;
                    i2c_addr <=1;
                    i2c_rh_wl <=1;
                    rx_flag <=1;
                end

                if(button_pressed1==1 && rx_flag)begin
                case(flow_cnt)
                2 : begin                                   
                    flow_cnt <= flow_cnt + 1;
                    i2c_exec <= 1;
                end    
                3 : begin
                        if(i2c_done == 1) begin                 //EEPROM单次读出完成
                            //读出的值错误或者I2C未应答,读写测试失败
                            if((i2c_ack == 1)) begin
                                rw_done <= 1;
                                rw_result <= 0;
                                flow_cnt <=12;
                            end
                            else if(i2c_addr == (MAX_BYTE +1))begin //读写测试成功
                                rw_done   <= 1;
                                rw_result <= 1;
                                flow_cnt <=13;
                            end    
                            else begin
                                flow_cnt <= 2;
                                i2c_addr <= i2c_addr + 1;
                                i <= i+1;
                                data_storage[i] <= i2c_data_r;
                            end
                        end                 
                    end  
                        default :;
                    endcase 
            end
    end
end    

assign read_flag = (button_pressed1 && rx_flag)?1:0;
assign data_on1Switch =rw_done ? {data_storage[0],data_storage[1],data_storage[2]} : 24'hffffff;
assign data_on2Switch =rw_done ? {data_storage[3],data_storage[4],data_storage[5]} : 24'hffffff;
assign data_on3Switch =rw_done ? {data_storage[6],data_storage[7],data_storage[8]} : 24'hffffff;  


endmodule
