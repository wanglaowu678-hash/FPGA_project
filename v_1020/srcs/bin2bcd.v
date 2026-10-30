`timescale 1ns / 1ps
module bin2bcd # (parameter WIDTH_BIN = 10, WIDTH_BCD = 16)
(
	input   wire	[WIDTH_BIN - 1:0]	bin,
	output	wire	[WIDTH_BCD - 1:0]	bcd
);
	wire		[WIDTH_BIN + WIDTH_BCD - 1:0]	temp [WIDTH_BIN:0];
	genvar		i;
	
	assign temp[0]	= bin;
	
	generate
		for (i = 0; i < WIDTH_BIN - 1; i = i + 1)
			begin : s_a
				shift_adjust # (.WIDTH_BIN(WIDTH_BIN), .WIDTH_BCD(WIDTH_BCD)) shift_adjust_inst(

					.idata					(temp[i]),

					.odata					(temp[i+1])
				);
			end
	endgenerate

	assign temp[WIDTH_BIN] = temp[WIDTH_BIN - 1] << 1;
	assign bcd = temp[WIDTH_BIN][WIDTH_BIN + WIDTH_BCD - 1:WIDTH_BIN];

endmodule 

module shift_adjust # (parameter WIDTH_BIN = 10, WIDTH_BCD = 16)
(
	input   wire		[WIDTH_BIN + WIDTH_BCD - 1:0]		idata,
	output	wire		[WIDTH_BIN + WIDTH_BCD - 1:0]		odata
);

	wire		[WIDTH_BIN + WIDTH_BCD - 1:0]		temp;
	genvar		i;
	assign temp = idata << 1;
	
	generate
		for (i = 0; i < WIDTH_BCD / 4; i = i + 1)
			begin : a
				adjust adjust_inst(

					.idata		(temp[WIDTH_BIN + WIDTH_BCD - 1-4*i : WIDTH_BIN + WIDTH_BCD - 4-4*i]),
					
					.odata		(odata[WIDTH_BIN + WIDTH_BCD - 1-4*i : WIDTH_BIN + WIDTH_BCD - 4-4*i])
				);
			end
	endgenerate
	
	assign odata[WIDTH_BIN - 1:0] = temp[WIDTH_BIN - 1:0];
endmodule 

module adjust(
	input	wire	[3:0]		idata,
	output	wire	[3:0]		odata
);
	assign odata = (idata > 4) ? idata + 3'd3 : idata;
endmodule 


