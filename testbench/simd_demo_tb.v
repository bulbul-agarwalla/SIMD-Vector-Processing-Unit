`timescale 1ns/1ps

// Presentation-oriented, self-checking demonstration of the integrated SIMD
// processor. The byte at the right of each displayed vector is lane 0.
module simd_demo_tb;
    reg clk;
    reg reset;
    reg write_enable_a;
    reg write_enable_b;
    reg [63:0] data_in_a;
    reg [63:0] data_in_b;
    reg [2:0] opcode;

    wire [63:0] result;
    wire operation_valid;
    wire [4:0] op_select;
    wire [63:0] vector_a;
    wire [63:0] vector_b;

    integer checks;
    integer lane;

    localparam [2:0] OP_ADD = 3'b000;
    localparam [2:0] OP_SUB = 3'b001;
    localparam [2:0] OP_AND = 3'b010;
    localparam [2:0] OP_OR  = 3'b011;
    localparam [2:0] OP_LT  = 3'b100;

    simd_processor_top dut (
        .clk(clk),
        .reset(reset),
        .write_enable_a(write_enable_a),
        .write_enable_b(write_enable_b),
        .data_in_a(data_in_a),
        .data_in_b(data_in_b),
        .opcode(opcode),
        .result(result),
        .operation_valid(operation_valid),
        .op_select(op_select),
        .vector_a(vector_a),
        .vector_b(vector_b)
    );

    always #5 clk = ~clk;

    function [8*8-1:0] operation_name;
        input [2:0] op;
        begin
            case (op)
                OP_ADD: operation_name = "ADD";
                OP_SUB: operation_name = "SUB";
                OP_AND: operation_name = "AND";
                OP_OR:  operation_name = "OR";
                OP_LT:  operation_name = "LT";
                default: operation_name = "INVALID";
            endcase
        end
    endfunction

    // Independent lane-by-lane reference model, matching the RTL's 8-bit
    // modular ADD/SUB behavior and unsigned less-than result encoding.
    function [63:0] reference_result;
        input [63:0] lhs;
        input [63:0] rhs;
        input [2:0] op;
        integer idx;
        reg [7:0] a_byte;
        reg [7:0] b_byte;
        begin
            reference_result = 64'd0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                a_byte = lhs[idx*8 +: 8];
                b_byte = rhs[idx*8 +: 8];
                case (op)
                    OP_ADD: reference_result[idx*8 +: 8] = a_byte + b_byte;
                    OP_SUB: reference_result[idx*8 +: 8] = a_byte - b_byte;
                    OP_AND: reference_result[idx*8 +: 8] = a_byte & b_byte;
                    OP_OR:  reference_result[idx*8 +: 8] = a_byte | b_byte;
                    OP_LT:  reference_result[idx*8 +: 8] = (a_byte < b_byte) ? 8'd1 : 8'd0;
                    default: reference_result[idx*8 +: 8] = 8'd0;
                endcase
            end
        end
    endfunction

    task load_operands;
        input [63:0] next_a;
        input [63:0] next_b;
        begin
            @(negedge clk);
            reset = 1'b0;
            write_enable_a = 1'b1;
            write_enable_b = 1'b1;
            data_in_a = next_a;
            data_in_b = next_b;
            @(posedge clk);
            #1;
            write_enable_a = 1'b0;
            write_enable_b = 1'b0;
            $display("\n[LOAD] A=%016h  B=%016h", vector_a, vector_b);
        end
    endtask

    task show_lanes;
        input [63:0] packed_result;
        integer idx;
        begin
            $write("  Lane results (L7 .. L0): ");
            for (idx = 7; idx >= 0; idx = idx - 1)
                $write("L%0d=%02h%s", idx, packed_result[idx*8 +: 8],
                       (idx == 0) ? "\n" : "  ");
        end
    endtask

    task demonstrate;
        input [2:0] op;
        reg [63:0] expected;
        reg expected_valid;
        begin
            opcode = op;
            #2; // allow combinational decode and all eight lane ALUs to settle
            expected = reference_result(vector_a, vector_b, op);
            expected_valid = (op <= OP_LT);

            $display("\n============================================================");
            $display("Operation : %0s", operation_name(op));
            $display("Opcode    : %03b   valid=%b   op_select=%05b",
                     opcode, operation_valid, op_select);
            $display("Input A   : %016h", vector_a);
            $display("Input B   : %016h", vector_b);
            $display("Expected  : %016h", expected);
            $display("Actual    : %016h", result);
            show_lanes(result);

            if (operation_valid !== expected_valid || result !== expected) begin
                $display("Status    : FAIL");
                $fatal(1,
                    "SIMD demo mismatch for opcode %03b: valid expected %b got %b; result expected %016h got %016h",
                    op, expected_valid, operation_valid, expected, result);
            end

            checks = checks + 1;
            $display("Status    : PASS");
        end
    endtask

    initial begin
        $dumpfile("results/simd_demo.vcd");
        $dumpvars(0, simd_demo_tb);

        clk = 1'b0;
        reset = 1'b1;
        write_enable_a = 1'b0;
        write_enable_b = 1'b0;
        data_in_a = 64'd0;
        data_in_b = 64'd0;
        opcode = OP_ADD;
        checks = 0;

        $display("============================================================");
        $display("8-LANE SIMD PROCESSOR — RTL SIMULATION DEMONSTRATION");
        $display("Icarus Verilog + GTKWave | 8 parallel unsigned 8-bit lanes");
        $display("============================================================");

        // The actual integrated register uses an active-high synchronous reset.
        repeat (2) @(posedge clk);
        #1;
        if (vector_a !== 64'd0 || vector_b !== 64'd0)
            $fatal(1, "Reset failed to clear both operand registers");
        $display("\n[RESET] Synchronous reset cleared vector_a and vector_b.");

        // Two distinct operand sets. Each contains eight distinct lane values;
        // the packed hex notation lists lane 7 at left and lane 0 at right.
        load_operands(
            {8'hd7, 8'h23, 8'hff, 8'h05, 8'h80, 8'h42, 8'h10, 8'h01},
            {8'h17, 8'h39, 8'h01, 8'hfa, 8'h7f, 8'h42, 8'h20, 8'hff});

        demonstrate(OP_ADD);
        demonstrate(OP_SUB);
        demonstrate(OP_AND);
        demonstrate(OP_OR);
        demonstrate(OP_LT);
        demonstrate(3'b101);

        // Change both registered vectors and repeat the full operation sweep.
        load_operands(
            {8'h00, 8'h01, 8'h02, 8'h03, 8'h7f, 8'h80, 8'hfe, 8'hff},
            {8'hff, 8'hfe, 8'hfd, 8'hfc, 8'h01, 8'h80, 8'h02, 8'h04});

        demonstrate(OP_ADD);
        demonstrate(OP_SUB);
        demonstrate(OP_AND);
        demonstrate(OP_OR);
        demonstrate(OP_LT);
        demonstrate(3'b101);

        $display("\n============================================================");
        $display("SIMD DEMO COMPLETE: %0d operation checks passed", checks);
        $display("Waveform: results/simd_demo.vcd");
        $display("============================================================");
        $finish;
    end
endmodule
