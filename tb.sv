`timescale 1ns/1ps

module tb_day4;

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH = 1 << ADDR_WIDTH;   // 16

    reg wr_clk = 0;
    reg wr_rst_n = 0;
    reg wr_en = 0;
    reg [DATA_WIDTH-1:0] wr_data = 0;
    wire full;

    reg rd_clk = 0;
    reg rd_rst_n = 0;
    reg rd_en = 0;
    wire [DATA_WIDTH-1:0] rd_data;
    wire empty;

    always #3 wr_clk = ~wr_clk;
    always #5 rd_clk = ~rd_clk;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
      .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_en(wr_en), .wr_data(wr_data), .full(full), .rd_clk(rd_clk), .rd_rst_n(rd_rst_n), .rd_en(rd_en),.rd_data(rd_data), .empty(empty));

    reg [DATA_WIDTH-1:0] ref_mem [0:DEPTH-1];
    integer ref_wr_ptr = 0;
    integer ref_rd_ptr = 0;

    reg [DATA_WIDTH-1:0] expected_pipe;
    reg expected_valid;

    integer total_writes = 0;
    integer total_reads = 0;
    integer error_count = 0;
    integer saw_full = 0;
    integer saw_empty = 0;

    always @(posedge wr_clk) begin
        if (wr_en && !full) begin
            ref_mem[ref_wr_ptr] <= wr_data;
            ref_wr_ptr <= (ref_wr_ptr + 1) % DEPTH;
            total_writes <= total_writes + 1;
        end
        if (full) saw_full <= 1;
    end

    always @(posedge rd_clk) begin
        if (rd_en && !empty) begin
            expected_pipe <= ref_mem[ref_rd_ptr];
            expected_valid <= 1'b1;
            ref_rd_ptr <= (ref_rd_ptr + 1) % DEPTH;
        end else begin
            expected_valid <= 1'b0;
        end
        if (empty) saw_empty <= 1;
    end

    always @(posedge rd_clk) begin
        if (expected_valid) begin
            total_reads <= total_reads + 1;
            if (rd_data !== expected_pipe) begin
                error_count <= error_count + 1;
                $display("t=%0t  MISMATCH!  got=%h  expected=%h", $time, rd_data, expected_pipe);
            end
        end
    end

    reg alarm_fired = 0;
    always @(posedge rd_clk) begin
        if (!alarm_fired && total_reads > total_writes) begin
            alarm_fired = 1;
            $display("########################################");
            $display("ALARM at t=%0t: reads(%0d) > writes(%0d)", $time, total_reads, total_writes);
            $display("  empty=%b  rptr_gray=%b  wptr_gray_in_rdomain=%b",
                       empty, dut.rptr_gray, dut.wptr_gray_in_rdomain);
            $display("  full=%b   wptr_gray=%b  rptr_gray_in_wrdomain=%b",
                       full, dut.wptr_gray, dut.rptr_gray_in_wrdomain);
            $display("########################################");
        end
    end


    initial begin
        wr_en = 0;
        wait (wr_rst_n);
        repeat (300) begin
            @(posedge wr_clk);
            #1;
            wr_en = $random & 1;
            if (wr_en) wr_data = $random;
        end
        wr_en = 0;
    end

    
    initial begin
        rd_en = 0;
        wait (rd_rst_n);
        repeat (300) begin
            @(posedge rd_clk);
            #1;
            rd_en = $random & 1;
        end
        rd_en = 0;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_day4);

        wr_rst_n = 0; rd_rst_n = 0;
        #20;
        wr_rst_n = 1; rd_rst_n = 1;

        #6000;

        $display("Total writes : %0d", total_writes);
        $display("Total reads  : %0d", total_reads);
        $display("Errors       : %0d", error_count);
        $display("Hit FULL?    : %0s", saw_full  ? "yes" : "no");
        $display("Hit EMPTY?   : %0s", saw_empty ? "yes" : "no");
        if (error_count == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $finish;
    end

endmodule
