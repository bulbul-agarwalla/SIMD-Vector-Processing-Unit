// Self-checking testbench for vector_register.
//
// Inputs are driven on the falling edge and outputs are sampled 1 ns after
// the rising edge, so there are no races. Every check compares all eight
// 8-bit lanes of both vectors and stops the simulation with $fatal on the
// first mismatch.

`timescale 1ns / 1ps

module register_tb;

reg         clk;
reg         reset;
reg         write_enable_a;
reg         write_enable_b;
reg  [63:0] data_in_a;
reg  [63:0] data_in_b;
wire [63:0] vector_a;
wire [63:0] vector_b;

vector_register uut (
    .clk(clk),
    .reset(reset),
    .write_enable_a(write_enable_a),
    .write_enable_b(write_enable_b),
    .data_in_a(data_in_a),
    .data_in_b(data_in_b),
    .vector_a(vector_a),
    .vector_b(vector_b)
);

// 100 MHz clock
initial clk = 1'b0;
always #5 clk = ~clk;

integer checks = 0;
integer k;
integer cycle;
reg [63:0] exp_a, exp_b;   // reference model for the random test
reg [7:0]  pat;

// Drive new inputs on the falling edge.
task drive(input r, input wa, input wb, input [63:0] da, input [63:0] db);
begin
    @(negedge clk);
    reset          = r;
    write_enable_a = wa;
    write_enable_b = wb;
    data_in_a      = da;
    data_in_b      = db;
end
endtask

// Let one rising edge happen, then sample.
task tick;
begin
    @(posedge clk);
    #1;
end
endtask

// Compare both vectors lane by lane against the expected values.
task check(input [8*40-1:0] name, input [63:0] ea, input [63:0] eb, input quiet);
    integer lane;
begin
    checks = checks + 1;
    for (lane = 0; lane < 8; lane = lane + 1) begin
        if (vector_a[lane*8 +: 8] !== ea[lane*8 +: 8])
            $fatal(1, "[FAIL] %0s: vector_a lane %0d expected %h got %h (full exp=%h got=%h) at %0t",
                   name, lane, ea[lane*8 +: 8], vector_a[lane*8 +: 8], ea, vector_a, $time);
        if (vector_b[lane*8 +: 8] !== eb[lane*8 +: 8])
            $fatal(1, "[FAIL] %0s: vector_b lane %0d expected %h got %h (full exp=%h got=%h) at %0t",
                   name, lane, eb[lane*8 +: 8], vector_b[lane*8 +: 8], eb, vector_b, $time);
    end
    if (!quiet)
        $display("[PASS] %-28s | A exp=%h got=%h | B exp=%h got=%h",
                 name, ea, vector_a, eb, vector_b);
end
endtask

initial begin
    $dumpfile("register.vcd");
    $dumpvars(0, register_tb);

    reset = 1'b0; write_enable_a = 1'b0; write_enable_b = 1'b0;
    data_in_a = 64'd0; data_in_b = 64'd0;

    $display("=== vector_register testbench ===");

    // T1: reset clears both registers, and wins over active write enables.
    drive(1, 1, 1, 64'hFFFF_FFFF_FFFF_FFFF, 64'hFFFF_FFFF_FFFF_FFFF);
    tick;
    check("T1 reset (enables high)", 64'd0, 64'd0, 0);

    // T2: write Vector A only; B must stay at 0 despite data on data_in_b.
    drive(0, 1, 0, 64'h0123_4567_89AB_CDEF, 64'h1111_2222_3333_4444);
    tick;
    check("T2 write A only", 64'h0123_4567_89AB_CDEF, 64'd0, 0);

    // T3: write Vector B only; A must hold although data_in_a changed.
    drive(0, 0, 1, 64'h5555_5555_5555_5555, 64'hFEDC_BA98_7654_3210);
    tick;
    check("T3 write B only", 64'h0123_4567_89AB_CDEF, 64'hFEDC_BA98_7654_3210, 0);

    // T4: write both at once with different values.
    drive(0, 1, 1, 64'hDEAD_BEEF_CAFE_F00D, 64'h8040_2010_0804_0201);
    tick;
    check("T4 write A and B together", 64'hDEAD_BEEF_CAFE_F00D, 64'h8040_2010_0804_0201, 0);

    // T5: enables low for 5 cycles while the data inputs keep changing.
    for (k = 0; k < 5; k = k + 1) begin
        pat = 8'h11 * (k + 1);
        drive(0, 0, 0, {8{pat}}, ~{8{pat}});
        tick;
        check("T5 hold (enables low)", 64'hDEAD_BEEF_CAFE_F00D, 64'h8040_2010_0804_0201, k != 4);
    end

    // T6: one distinct value per lane (lane 7 .. lane 0), as simd_tb uses.
    drive(0, 1, 1, {8'd10, 8'd20, 8'd30, 8'd40, 8'd50, 8'd60, 8'd70, 8'd80},
                   {8'd1,  8'd2,  8'd3,  8'd4,  8'd5,  8'd6,  8'd7,  8'd8});
    tick;
    check("T6 distinct value per lane",
          {8'd10, 8'd20, 8'd30, 8'd40, 8'd50, 8'd60, 8'd70, 8'd80},
          {8'd1,  8'd2,  8'd3,  8'd4,  8'd5,  8'd6,  8'd7,  8'd8}, 0);

    // T7: walking lane - only lane k is 0xFF (A) / 0x5A (B), all others 0.
    // Catches swapped, merged or stuck lanes.
    for (k = 0; k < 8; k = k + 1) begin
        drive(0, 1, 1, 64'hFF << (k * 8), 64'h5A << (k * 8));
        tick;
        check("T7 walking lane", 64'hFF << (k * 8), 64'h5A << (k * 8), k != 7);
    end
    $display("[PASS] T7 walking lane: lanes 0-7 each isolated");

    // T8: boundary patterns.
    drive(0, 1, 1, 64'hFFFF_FFFF_FFFF_FFFF, 64'hAAAA_AAAA_AAAA_AAAA);
    tick;
    check("T8 all-ones / 0xAA", 64'hFFFF_FFFF_FFFF_FFFF, 64'hAAAA_AAAA_AAAA_AAAA, 0);
    drive(0, 1, 1, 64'h5555_5555_5555_5555, 64'hFFFF_FFFF_FFFF_FFFF);
    tick;
    check("T8 0x55 / all-ones", 64'h5555_5555_5555_5555, 64'hFFFF_FFFF_FFFF_FFFF, 0);

    // T9: reset is synchronous - asserting it between edges changes nothing
    // until the next rising edge.
    drive(1, 0, 0, 64'd0, 64'd0);
    #2;
    check("T9 reset mid-cycle, no edge", 64'h5555_5555_5555_5555, 64'hFFFF_FFFF_FFFF_FFFF, 0);
    tick;
    check("T9 reset after data written", 64'd0, 64'd0, 0);

    // T10: registers accept writes again after reset is released.
    drive(0, 1, 1, 64'hA5A5_5A5A_0F0F_F0F0, 64'h0011_2233_4455_6677);
    tick;
    check("T10 write after reset", 64'hA5A5_5A5A_0F0F_F0F0, 64'h0011_2233_4455_6677, 0);

    // T11: 1000 random cycles against a reference model
    // (random data, random enables, reset asserted ~1 in 16 cycles).
    exp_a = vector_a;
    exp_b = vector_b;
    for (cycle = 0; cycle < 1000; cycle = cycle + 1) begin
        drive(($urandom % 16) == 0, $urandom % 2, $urandom % 2,
              {$urandom, $urandom}, {$urandom, $urandom});
        if (reset) begin
            exp_a = 64'd0;
            exp_b = 64'd0;
        end else begin
            if (write_enable_a) exp_a = data_in_a;
            if (write_enable_b) exp_b = data_in_b;
        end
        tick;
        check("T11 random", exp_a, exp_b, 1);
    end
    $display("[PASS] T11 random: 1000 cycles match the reference model");

    $display("=== ALL TESTS PASSED: %0d checks, 0 failures ===", checks);
    $finish;
end

endmodule
