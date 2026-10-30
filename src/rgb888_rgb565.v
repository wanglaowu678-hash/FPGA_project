module rgb888_rgb565(
input [23:0]rgb888,
output [15:0]rgb565
    );
    assign rgb565[15:11] = rgb888[23:19];
    assign rgb565[10:5] = rgb888[15:10];
    assign rgb565[4:0] = rgb888[7:3];

endmodule
