module rgb565_rgb888(
input [15:0]rgb565,
output[23:0]rgb888
    );
    
    assign rgb888[23:16] = {rgb565[15:11],3'b000};
    assign rgb888[15:8] = {rgb565[10:5],2'b00};
    assign rgb888[7:0] = {rgb565[4:0],3'b000};

endmodule
