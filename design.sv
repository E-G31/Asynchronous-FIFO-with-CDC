module dual_port_ram #(parameter DATA_WIDTH = 8, parameter ADDR_WIDTH = 4)(
    input  wire wr_clk,
    input  wire wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire rd_clk,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg [DATA_WIDTH-1:0] rd_data);

  reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1]; //reg [7:0] mem [0:15];

    always @(posedge wr_clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    always @(posedge rd_clk) begin
        rd_data <= mem[rd_addr];
    end
endmodule



module gray_counter #(parameter WIDTH = 5)(// Extra MSB distinguishes FULL //from EMPTY after pointer wrap-around.
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    output reg [WIDTH-1:0] bin_out,
    output reg [WIDTH-1:0] gray_out);

    wire [WIDTH-1:0] bin_next = bin_out + (en ? 1'b1 : 1'b0);
    wire [WIDTH-1:0] gray_next = bin_next ^ (bin_next >> 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bin_out  <= 0;
            gray_out <= 0;
        end else begin
            bin_out  <= bin_next;
            gray_out <= gray_next;
        end
    end
endmodule




module async_fifo #(parameter DATA_WIDTH = 8,parameter ADDR_WIDTH = 4)(
    input wire wr_clk,
    input wire wr_rst_n,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output wire full,      // TODO: Day 3

    input wire rd_clk,
    input wire rd_rst_n,
    input wire rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire empty); // TODO: Day 3

    wire [ADDR_WIDTH:0] wptr_bin, wptr_gray;
    wire [ADDR_WIDTH:0] rptr_bin, rptr_gray;

    gray_counter #(.WIDTH(ADDR_WIDTH+1)) u_wptr(
        .clk (wr_clk),
        .rst_n (wr_rst_n),
        .en (wr_en),     // TODO Day 3: gate with !full
        .bin_out (wptr_bin),
        .gray_out (wptr_gray));

    gray_counter #(.WIDTH(ADDR_WIDTH+1)) u_rptr(
        .clk (rd_clk),
        .rst_n (rd_rst_n),
        .en (rd_en),     // TODO Day 3: gate with !empty
        .bin_out (rptr_bin),
        .gray_out (rptr_gray));

    dual_port_ram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem(
        .wr_clk (wr_clk),
        .wr_en (wr_en),
        .wr_addr (wptr_bin[ADDR_WIDTH-1:0]),
        .wr_data (wr_data),
        .rd_clk (rd_clk),
        .rd_addr (rptr_bin[ADDR_WIDTH-1:0]),
        .rd_data (rd_data));

    assign full = 1'b0;   
    assign empty = 1'b0;
endmodule
