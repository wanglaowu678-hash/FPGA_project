`timescale 1ns / 1ps




module cordic
#
(
    parameter DATA_WIDTH = 16,
    parameter CALC_ORDER = 16
    
)
(
    input                  reset_n,
    input                  clock,
    input                  load,  //输入数据脉冲
    output reg                ready, //cordic计算器空闲电平
    output reg                done,  //cordic计算完成脉冲
    input  [DATA_WIDTH-1:0]x_in,   //输入数据
    input [DATA_WIDTH-1:0]y_in,    //输入数据
    output reg[DATA_WIDTH-1:0]pha, //输出角度 -pi——pi  -32768~32767
    output reg[DATA_WIDTH+1:0]mag  //输出幅值 比实际的大1.647倍
);



wire [4 :0]shift_w[31:0];
wire [31:0]theta_w[31:0];
wire [31:0]theta_pi;

wire [1 :0]quadrant;

assign shift_w[ 0] = 5'b00000;
assign shift_w[ 1] = 5'b00001;
assign shift_w[ 2] = 5'b00010;
assign shift_w[ 3] = 5'b00011;
assign shift_w[ 4] = 5'b00100;
assign shift_w[ 5] = 5'b00101;
assign shift_w[ 6] = 5'b00110;
assign shift_w[ 7] = 5'b00111;
assign shift_w[ 8] = 5'b01000;
assign shift_w[ 9] = 5'b01001;
assign shift_w[10] = 5'b01010;
assign shift_w[11] = 5'b01011;
assign shift_w[12] = 5'b01100;
assign shift_w[13] = 5'b01101;
assign shift_w[14] = 5'b01110;
assign shift_w[15] = 5'b01111;
assign shift_w[16] = 5'b10000;
assign shift_w[17] = 5'b10001;
assign shift_w[18] = 5'b10010;
assign shift_w[19] = 5'b10011;
assign shift_w[20] = 5'b10100;
assign shift_w[21] = 5'b10101;
assign shift_w[22] = 5'b10110;
assign shift_w[23] = 5'b10111;
assign shift_w[24] = 5'b11000;
assign shift_w[25] = 5'b11001;
assign shift_w[26] = 5'b11010;
assign shift_w[27] = 5'b11011;
assign shift_w[28] = 5'b11100;
assign shift_w[29] = 5'b11101;
assign shift_w[30] = 5'b11110;
assign shift_w[31] = 5'b11111;


assign theta_pi    = 32'd1686629713;
//角度定点查找表 45°，26.6°------------ 45°-->0.7854 format(000.000000000)
assign theta_w[ 0] = 32'd421657428; //32'h0001_1001_0010_0001_1111_1011_0101_0100;
assign theta_w[ 1] = 32'd248918915;
assign theta_w[ 2] = 32'd131521918;
assign theta_w[ 3] = 32'd66762579;
assign theta_w[ 4] = 32'd33510843;
assign theta_w[ 5] = 32'd16771758;
assign theta_w[ 6] = 32'd8387925;
assign theta_w[ 7] = 32'd4194219;
assign theta_w[ 8] = 32'd2097141;
assign theta_w[ 9] = 32'd1048575;
assign theta_w[10] = 32'd524288;
assign theta_w[11] = 32'd262144;
assign theta_w[12] = 32'd131072;
assign theta_w[13] = 32'd65536;
assign theta_w[14] = 32'd32768;
assign theta_w[15] = 32'd16384;
assign theta_w[16] = 32'd8192;
assign theta_w[17] = 32'd4096;
assign theta_w[18] = 32'd2048;
assign theta_w[19] = 32'd1024;
assign theta_w[20] = 32'd512;
assign theta_w[21] = 32'd256;
assign theta_w[22] = 32'd128;
assign theta_w[23] = 32'd64;
assign theta_w[24] = 32'd32;
assign theta_w[25] = 32'd16;
assign theta_w[26] = 32'd8;
assign theta_w[27] = 32'd4;
assign theta_w[28] = 32'd2;
assign theta_w[29] = 32'd1;
assign theta_w[30] = 32'd1;
assign theta_w[31] = 32'd0;


reg [2:0]state=0;
reg [5:0]rot_cnt=0;
reg [4:0]shift;
reg [DATA_WIDTH-1:0]theta;
reg	signed[DATA_WIDTH+1:0]xin ; //扩位2
reg	signed[DATA_WIDTH+1:0]yin ;
reg	signed[DATA_WIDTH-1:0]zin ; //不需扩位
wire signed[DATA_WIDTH+1:0]xout ;
wire signed[DATA_WIDTH+1:0]yout ;
wire signed[DATA_WIDTH-1:0]zout ;

always @ (posedge clock or negedge reset_n) begin
    if (!reset_n) begin
            state<=0;
            shift <= 0;
            theta <= 0;
            xin <= 0;
            yin <= 0;
            zin <= 0;	
            rot_cnt <=0;	
            ready <= 1;	
    end
    else
        case(state)  //load and convert
            0:
                if(load == 1'b1)
                    begin
                        state <= state + 1;
                        shift <= shift_w[0];
                        theta <= theta_w[0][31:32-DATA_WIDTH];
                        rot_cnt <=0;
                        ready <= 0;
                        if(x_in[DATA_WIDTH-1] )begin //判断为1,4象限还是2,3象限，2，3象限则幅度取反
                            xin <= -{x_in[DATA_WIDTH-1],x_in[DATA_WIDTH-1],x_in}; //扩位，计算的过程中可能会溢出
                            yin <= -{y_in[DATA_WIDTH-1],y_in[DATA_WIDTH-1],y_in};
                            if(y_in[DATA_WIDTH-1])  
                                zin <= -theta_pi[31:32-DATA_WIDTH];	 //-pi //第3象限 
                            else
                                zin <=  theta_pi[31:32-DATA_WIDTH];  //+pi //第4象限
                        end
                        else
                            begin
                                xin <= {x_in[DATA_WIDTH-1],x_in[DATA_WIDTH-1],x_in};
                                yin <= {y_in[DATA_WIDTH-1],y_in[DATA_WIDTH-1],y_in};
                                zin <= 0;
                            end
                end
        1:if(rot_cnt == CALC_ORDER) //迭代次数达到
                begin
                    state <= state + 1;
                    mag <= xout; //输出幅度
                     pha <= zout; //输出角度
                    done <= 1'b1; // assert 'done'
                    rot_cnt <= 0;
                end
            else
                begin
                    rot_cnt = rot_cnt  + 1;
                    shift <= shift_w[rot_cnt];
                    theta <= theta_w[rot_cnt][31:32-DATA_WIDTH];
                    xin <= xout; //迭代
                    yin <= yout;
                    zin <= zout;
                end
        2:begin
                state <= 0;
                done <= 0;
                ready <= 1;
        end
    endcase
end
            
//迭代主体
wire signed [DATA_WIDTH+1:0]x_w;
wire signed [DATA_WIDTH+1:0]y_w;

wire  signed [DATA_WIDTH+1  :0]x_r;
wire  signed [DATA_WIDTH+1  :0]y_r;
wire  signed [DATA_WIDTH-1:0]z_r;

assign x_w = xin >>> shift;
assign y_w = yin >>> shift;

assign x_r = (yin[DATA_WIDTH+1] == 0) ? xin + y_w   : xin - y_w;
assign y_r = (yin[DATA_WIDTH+1] == 0) ? yin - x_w   : yin + x_w;
assign z_r = (yin[DATA_WIDTH+1] == 0) ? zin + theta : zin - theta;

assign xout = x_r[DATA_WIDTH+1:0]; 
assign yout = y_r[DATA_WIDTH+1:0];

assign zout = z_r;

endmodule