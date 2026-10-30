module colorDetect(
input PClk,
input rst_n,
input btn_ColorExtract,

input sw_ColorClear,

input [11:0] VtcHCnt,
input [10:0] VtcVCnt,
input [23:0] HSV24,RGB24,

output wire [11:0] center_h,
output wire [10:0] center_v,	 

output [23:0] RGB24_dis,
output Binary_PreProcess,

input Binary_PostProcess,
/////////////////////

input btn_ColorExtract1,
output wire [11:0] center_h1,
output wire [10:0] center_v1,	

input Binary_PostProcess1,
output Binary_PreProcess1,

///////////////////
input btn_ColorExtract2,
output wire [11:0] center_h2,
output wire [10:0] center_v2,	

input Binary_PostProcess2,
output Binary_PreProcess2,

input read_flag,

input [23:0]data_on1Switch,
input [23:0]data_on2Switch,
input [23:0]data_on3Switch,

output reg [23:0] indata_on1Switch,
output reg [23:0] indata_on2Switch,
output reg [23:0] indata_on3Switch
);
	 
// Parameters

reg data_on1Switch_changed ;
reg data_on2Switch_changed ;
reg data_on3Switch_changed ;
reg [23:0] prev_data_on1Switch ;
reg [23:0] prev_data_on2Switch ;
reg [23:0] prev_data_on3Switch ;
reg flag1;
reg flag2;
reg flag3;
// 检测输入的变化
always @(posedge PClk or negedge rst_n) begin
	if(!rst_n)begin
		data_on1Switch_changed <=0;
		data_on2Switch_changed <=0;
		data_on3Switch_changed <=0;
		prev_data_on1Switch<=0;
		prev_data_on2Switch <=0;
		prev_data_on3Switch <=0;
		flag1<=0;
		flag2<=0;
		flag3<=0;
	end

    else if (data_on1Switch != prev_data_on1Switch ) begin
        data_on1Switch_changed <= 1;
        prev_data_on1Switch <= data_on1Switch;
    end 

    else if (data_on2Switch != prev_data_on2Switch ) begin
        data_on2Switch_changed <= 1;
        prev_data_on2Switch <= data_on2Switch;
    end 

    else if (data_on3Switch != prev_data_on3Switch ) begin
        data_on3Switch_changed <= 1;
        prev_data_on3Switch <= data_on3Switch;
    end 
end

wire [7:0] HUE;
wire [7:0] SATURATION;
wire [7:0] VALUE;

reg [23:0] HSV_detect;
reg [23:0] HSV_detect1;
reg [23:0] HSV_detect2;
wire [23:0] RGB_render;

/* always @(data_on1Switch,data_on2Switch,data_on3Switch) begin
	HSV_detect <=data_on1Switch;
	HSV_detect1 <=data_on2Switch;
	HSV_detect2 <=data_on3Switch;
end
 */
 
assign HUE = HSV24[23:16];
assign SATURATION = HSV24[15:8];
assign VALUE = HSV24[7:0];

reg [31:0] H_Sum;
reg [31:0] S_Sum;
reg [31:0] V_Sum;
reg [23:0] HSV_out_temp;
//
reg [20:0] Binary_Sum;
//wire [11:0] center_h;
//wire [10:0] center_v;
always@(posedge PClk) begin
	if( VtcVCnt == 1 && VtcHCnt==1) begin // initial
	Binary_Sum<=0;
	end
	if(Binary_PostProcess==1)begin
	Binary_Sum<=Binary_Sum+1;
	end
end
//////////////////////////////////////////////// color detect
always@(posedge PClk) begin
	
	// signal output
////////////////////////////////////////////////btn_ColorExtract
	if(btn_ColorExtract==1) begin
		HSV_detect <= HSV_out_temp;
		indata_on1Switch <=HSV_out_temp;
	end
	else if(data_on1Switch_changed ==1 && read_flag)begin
		HSV_detect <=data_on1Switch;
	end
	else if(sw_ColorClear == 1)begin
	   HSV_detect <= 24'b11111111_11111111_11111111;
	end
	else if( VtcHCnt >=144 && VtcHCnt <176 && VtcVCnt >=104 && VtcVCnt <136 ) begin  // acumulate
		H_Sum <= H_Sum + HUE;
		S_Sum <= S_Sum + SATURATION;
		V_Sum <= V_Sum + VALUE;
		end
	else if( VtcVCnt == 1 ) begin // initial
		H_Sum <= 0;
		S_Sum <= 0;
		V_Sum <= 0;
		end
	else if( VtcVCnt == 239 ) begin // result
			HSV_out_temp[23:16] 	<= H_Sum / 1024;
			HSV_out_temp[15:8] 	<= S_Sum / 1024;
			HSV_out_temp[7:0] 	<= V_Sum / 1024;
		end
end


//
BW RGB2BW(	
	.HSV24(HSV24),
    .HSV_Detect(HSV_detect),
    .Binary_out(Binary_PreProcess)
);


//
render RGBrender(
	.PClk(PClk),
	.RGB24(RGB24),
	.Binary_in(Binary_PostProcess),
	.VtcHCnt(VtcHCnt),  	// 0-639 来自VideoTimmingCtl的HCNT_O
	.VtcVCnt(VtcVCnt), 	// 0-479	来自VideoTimmingCtl的 VCNT_O
	.center_h(center_h), // 0-639,中点横向坐标
	.center_v(center_v), 	// 0-479,中点纵向坐标
	.RGB_render(RGB_render),


	.Binary_in1(Binary_PostProcess1),
	.center_h1(center_h1),
	.center_v1(center_v1),

	.Binary_in2(Binary_PostProcess2),
	.center_h2(center_h2),
	.center_v2(center_v2)
);	 
	
assign RGB24_dis = RGB_render;

wire[3:0] weight;
weight_cal u_weight(
   .PCLK             (PClk),
   .VtcHCnt          (VtcHCnt),
   .VtcVCnt          (VtcVCnt),
    .center_h         (center_h),// 0-639,中点横向坐标
   .center_v         (center_v),// 0-479,中点纵向坐标
   .weight          (weight)//OUT
);

//
center cenCalculate(
    .pclk(PClk),  			// pixel clock
    .din(Binary_PostProcess),  			// 1-bit pixel value, come from BW image buffer
    .Hcnt(VtcHCnt),  	//0-639 来自VideoTimmingCtl的HCNT_O
    .Vcnt(VtcVCnt), 		// 0-479	来自VideoTimmingCtl的 VCNT_O
    .center_h(center_h), // 0-639,中点横向坐标
    .center_v(center_v), 	// 0-479,中点纵向坐标
    .Binary_Sum(Binary_Sum),
    .weight(weight)
);
//////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////

reg [20:0] Binary_Sum1;


always@(posedge PClk) begin
	if( VtcVCnt == 1 && VtcHCnt==1) begin // initial
	Binary_Sum1<=0;
	end
	if(Binary_PostProcess1==1)begin
	Binary_Sum1<=Binary_Sum1+1;
	end
end

always@(posedge PClk) begin
	
	// signal output
	//////////////////////////////////////////////////// btn_ColorExtract
	if(btn_ColorExtract1==1) begin
		HSV_detect1 <= HSV_out_temp;
		indata_on2Switch <=HSV_out_temp;
	end
	else if(data_on2Switch_changed ==1  && read_flag)begin
		HSV_detect1 <=data_on2Switch;
	end
	else if(sw_ColorClear == 1)begin
		HSV_detect1 <= 24'b11111111_11111111_11111111;
	end
	
end

//
BW RGB2BW1(	
	.HSV24(HSV24),
    .HSV_Detect(HSV_detect1),
    .Binary_out(Binary_PreProcess1)
);

wire[3:0] weight1;
weight_cal u_weight1(
	.PCLK             (PClk),
	.VtcHCnt          (VtcHCnt),
	.VtcVCnt          (VtcVCnt),
	.center_h         (center_h1),// 0-639,中点横向坐标
	.center_v         (center_v1),// 0-479,中点纵向坐标
	.weight          (weight1)
);

//
center cenCalculate1(
    .pclk(PClk),  			// pixel clock
    .din(Binary_PostProcess1),  			// 1-bit pixel value, come from BW image buffer
    .Hcnt(VtcHCnt),  	//0-639 来自VideoTimmingCtl的HCNT_O
    .Vcnt(VtcVCnt), 		// 0-479	来自VideoTimmingCtl的 VCNT_O
    .center_h(center_h1), // 0-639,中点横向坐标
    .center_v(center_v1), 	// 0-479,中点纵向坐标
    .Binary_Sum(Binary_Sum1),
    .weight(weight1)//in
);

///////////////////////////////////////////////////////
//////////////////////////////////////////////////

reg [20:0] Binary_Sum2;

always@(posedge PClk) begin
	if( VtcVCnt == 1 && VtcHCnt==1) begin // initial
	Binary_Sum2<=0;
	end
	if(Binary_PostProcess2==1)begin
	Binary_Sum2<=Binary_Sum2+1;
	end
end

always@(posedge PClk) begin
	
	// signal output
	//////////////////////////////////////////////////// btn_ColorExtract
	if(btn_ColorExtract2==1) begin
		HSV_detect2 <= HSV_out_temp;
		indata_on3Switch <=HSV_out_temp;
	end
	else if(data_on3Switch_changed ==1 && read_flag)begin
		HSV_detect2 <=data_on3Switch;
	end
	else if(sw_ColorClear == 1)begin
		HSV_detect2 <= 24'b11111111_11111111_11111111;
	end
	
end

//
BW RGB2BW2(	
	.HSV24(HSV24),
    .HSV_Detect(HSV_detect2),
    .Binary_out(Binary_PreProcess2)
);

wire[3:0] weight2;
weight_cal u_weight2(
	.PCLK             (PClk),
	.VtcHCnt          (VtcHCnt),
	.VtcVCnt          (VtcVCnt),
	.center_h         (center_h2),// 0-639,中点横向坐标
	.center_v          (center_v2),// 0-479,中点纵向坐标
	.weight          (weight2)
);

//
center cenCalculate2(
    .pclk(PClk),  			// pixel clock
    .din(Binary_PostProcess2),  			// 1-bit pixel value, come from BW image buffer
    .Hcnt(VtcHCnt),  	//0-639 来自VideoTimmingCtl的HCNT_O
    .Vcnt(VtcVCnt), 		// 0-479	来自VideoTimmingCtl的 VCNT_O
    .center_h(center_h2), // 0-639,中点横向坐标
    .center_v(center_v2), 	// 0-479,中点纵向坐标
    .Binary_Sum(Binary_Sum2),
    .weight(weight2)//in
);


endmodule