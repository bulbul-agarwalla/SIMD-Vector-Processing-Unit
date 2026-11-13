
module alu_tb;

reg [7:0] A, B;
reg [2:0] opcode;
wire [7:0] result;

alu uut (
    .A(A),
    .B(B),
    .opcode(opcode),
    .result(result)
);

initial begin

    $dumpfile("alu.vcd");
    $dumpvars(0, alu_tb);

    A = 10;
    B = 5;

    opcode = 3'b000;
    #10;
    $display("ADD: %d", result);

    opcode = 3'b001;
    #10;
    $display("SUB: %d", result);

    opcode = 3'b010;
    #10;
    $display("AND: %d", result);

    opcode = 3'b011;
    #10;
    $display("OR: %d", result);

    opcode = 3'b100;
    #10;
    $display("LESS THAN: %d", result);

    $finish;

end

endmodule
