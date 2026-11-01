`timescale 1ns/1ps

module operator_permission(
    input wire [1:0] role,
    input wire [2:0] opcode,kind,
    input wire drill,
    output wire allowed
);
    assign allowed=(role==2&&opcode<=5)||
        (role==1&&((opcode==0&&(kind==2||(drill&&kind!=3)))||
        ((opcode==1||opcode==2)&&drill&&kind!=3)));
endmodule
