
`timescale 1ns / 1ps


module angle_calculation(
    input clk,
    input rst_n,
    input  signed [15:0]site_x1,
    input  signed [15:0]site_y1,
    input  signed [15:0]site_x2,
    input  signed  [15:0]site_y2,
    input  signed [15:0]site_x3,
    input  signed [15:0]site_y3,
    output reg [7:0] angle// 输出角度整数部分，根据需要调整位宽
    );

    reg signed [15:0] x1_minus_x2;
    reg signed [15:0] y1_minus_y2;
    reg signed [15:0] x3_minus_x2;
    reg signed [15:0] y3_minus_y2;

    reg [7:0]angle_last;
    reg [7:0]angle_temp;
    wire signed[15:0]pha;
    wire signed[15:0]pha1;
    // 信号声明
/*     wire s_axis_cartesian_tvalid; */
/*     wire [31:0] s_axis_cartesian_tdata_0;
    wire [31:0] s_axis_cartesian_tdata_1;

    wire m_axis_dout_tvalid_0;
    wire m_axis_dout_tvalid_1; */

/*     wire signed [15:0] m_axis_dout_tdata_0;
    wire signed [15:0] m_axis_dout_tdata_1; */

     // 数据打包: 假设X坐标在高16位，Y坐标在低16位
    //assign s_axis_cartesian_tdata_0 = {y1_minus_y2[15],y1_minus_y2[14:0],x1_minus_x2[15] ,x1_minus_x2[14:0]};//{y1_minus_y2, x1_minus_x2}
/*     assign s_axis_cartesian_tdata_0 ={y1_minus_y2, x1_minus_x2};
    assign s_axis_cartesian_tdata_1 = {y3_minus_y2, x3_minus_x2};
    assign s_axis_cartesian_tvalid = 1'b1;    */

    always @(*) begin

    
/*         // 计算差值
        // (1<<14) / 320= 51.2
        //68 = (1<<14) / 240
        x1_minus_x2 <= (site_x1 - site_x2)<<14;//-20
        y1_minus_y2 <= (site_y1 - site_y2)<<14;//100
        x3_minus_x2 <= (site_x3 - site_x2)<<14;//100
        y3_minus_y2 <= (site_y3 - site_y2)<<14;//0 */
        
        x1_minus_x2 <= (site_x1 - site_x2)*50;//-90 <<30/320
       // x1_minus_x2 <= (site_x1 - site_x2)>=0?(site_x1 - site_x2)*68 :(site_x2 - site_x1)*68 ;

        y1_minus_y2 <= (site_y1 - site_y2)*50;//100
        //y1_minus_y2 <= (site_y1 - site_y2)>=0?(site_y1 - site_y2)*68  :(site_y2 - site_y1)*68 ;
        
        x3_minus_x2 <= (site_x3 - site_x2)*50;//100
        //x3_minus_x2 <=(site_x3 - site_x2)?(site_x3 - site_x2)*68  :(site_x3 - site_x2)*68 ;

        y3_minus_y2 <= (site_y3 - site_y2)*50;//0
        //y3_minus_y2 <=(site_y3 - site_y2)?(site_y3 - site_y2)*68  :(site_y3 - site_y2)*68 ;

        angle <=(pha >= pha1)?(((pha -pha1)*57)>>13) :(((pha1 -pha)*57)>>13);
       // angle_temp <= (angle_last>=angle)?(angle_last -angle) :(angle -nagle_last); 
        //angle <= angle_temp[14]*114 +angle_temp[13]*57 +angle_temp[12] *28 +angle_temp[11] *14 +angle_temp[10] *7 +angle_temp[9] *3 +angle_temp[8] *1 ; 
    end

/*     always @(angle_last) begin
        if(angle_temp >=10 && angle !=0 && angle_last !=0)
            angle <=angle;
        else if(angle_last ==0 || angle ==0)begin
            

            angle <=angle_last;
        end
    end */

//wire m_axis_dout_tvalid;

/* cordic_0 cordic_0 (
  .aclk(clk),                                        // input wire aclk
  .s_axis_cartesian_tvalid(s_axis_cartesian_tvalid),  // input wire s_axis_cartesian_tvalid
  .s_axis_cartesian_tdata(s_axis_cartesian_tdata_0),    // input wire [31 : 0] s_axis_cartesian_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_0),            // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata_0)              // output wire [15 : 0] m_axis_dout_tdata
);

cordic_0 cordic_1 (
  .aclk(clk),                                        // input wire aclk
  .s_axis_cartesian_tvalid(s_axis_cartesian_tvalid),  // input wire s_axis_cartesian_tvalid
  .s_axis_cartesian_tdata(s_axis_cartesian_tdata_1),    // input wire [31 : 0] s_axis_cartesian_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_1),            // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata_1)              // output wire [15 : 0] m_axis_dout_tdata
); */
    wire ready;
    wire done;

    wire [15:0]mag;
    wire  load1 =1;
    wire  load2=1;
    cordic cordic
    (
    .reset_n(rst_n),
    .clock(clk),
    .load(load1),  //输入数据脉冲

    .ready(ready), //cordic计算器空闲电平
    .done(done),  //cordic计算完成脉冲
    .x_in(x1_minus_x2),   //输入数据
    .y_in(y1_minus_y2),    //输入数据
    .pha(pha), //输出角度 -pi——pi  -32768~32767
    .mag(mag)  //输出幅值 比实际的大1.647倍
    );

    wire ready1;
    wire done1;
    wire [15:0]mag1;  
    cordic cordic1
    (
    .reset_n(rst_n),
    .clock(clk),
    .load(load2),  //输入数据脉冲

    .ready(ready1), //cordic计算器空闲电平
    .done(done1),  //cordic计算完成脉冲
    .x_in(x3_minus_x2),   //输入数据
    .y_in(y3_minus_y2),    //输入数据
    .pha(pha1), //输出角度 -pi——pi  -32768~32767
    .mag(mag1)  //输出幅值 比实际的大1.647倍
    );


        
    endmodule


