module render(
    input               PClk,
    input [23:0]        RGB24,
    input               Binary_in,
    input [11:0]        VtcHCnt,
    input [10:0]        VtcVCnt,
    input [11:0]        center_h,  	// 0-319 from BW
    input [10:0]        center_v,		// 0-239 from BW
    output reg [23:0]   RGB_render,
//////////////////


    input               Binary_in1,
    input [11:0]        center_h1,  	// 0-319 from BW
    input [10:0]        center_v1,		// 0-239 from BW
///////////////


    input               Binary_in2,
    input [11:0]        center_h2,  	// 0-319 from BW
    input [10:0]        center_v2		// 0-239 from BW

    );

reg [23:0]      RGB_render_temp;

always@(posedge PClk) begin
    if(Binary_in==1 || Binary_in1==1 || Binary_in2 ==1) begin//labeled by green 
        RGB_render_temp[23:16]  <= 0;
        RGB_render_temp[15:8]	<= 255;
        RGB_render_temp[7:0] 	<= 0;
    end
    else begin
        RGB_render_temp[23:16]  <= RGB24[23:16];
        RGB_render_temp[15:8]	<= RGB24[15:8];
        RGB_render_temp[7:0] 	<= RGB24[7:0];
    end
    
    if ((160-16==VtcHCnt||160+16==VtcHCnt) && VtcVCnt>=120-16&&VtcVCnt<=120+16 //show a yellow rectangle
    ||(120-16==VtcVCnt||120+16==VtcVCnt) && VtcHCnt>=160-16&&VtcHCnt<=160+16  )begin
        RGB_render <= 24'b11111111_11111111_00000000;
    end
    else  if(center_h==VtcHCnt | center_v==VtcVCnt | center_h1==VtcHCnt | center_v1==VtcVCnt | center_h2==VtcHCnt | center_v2==VtcVCnt)//label 2 cross line. The intersection point is the ball's center.
        RGB_render <= 24'b11111111_00000000_00000000;
    else
        RGB_render <= RGB_render_temp;

end


endmodule
