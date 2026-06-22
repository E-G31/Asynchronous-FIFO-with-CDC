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

module synchronizer #(parameter WIDTH = 5)(
    input wire dest_clk,
    input wire dest_rst_n,
    input wire [WIDTH-1:0] async_in,
    output reg [WIDTH-1:0] sync_out);

  reg [WIDTH-1:0] stage1;//first flip flop

    always @(posedge dest_clk or negedge dest_rst_n) begin
        if (!dest_rst_n) begin
            stage1 <= 0;
            sync_out <= 0;
        end else begin
            stage1 <= async_in;   // 1st flop may go metastable
            sync_out <= stage1;     // 2nd flop gives it time to resolve
        end
    end
endmodule


module async_fifo #(parameter DATA_WIDTH = 8,parameter ADDR_WIDTH = 4)(
    input wire wr_clk,
    input wire wr_rst_n,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output wire full,      

    input wire rd_clk,
    input wire rd_rst_n,
    input wire rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire empty);

    wire [ADDR_WIDTH:0] wptr_bin, wptr_gray;
    wire [ADDR_WIDTH:0] rptr_bin, rptr_gray;
    wire [ADDR_WIDTH:0] wptr_gray_in_rdomain;// write ptr, synced into read clock domain
    wire [ADDR_WIDTH:0] rptr_gray_in_wrdomain;// read ptr, synced into write clock domain
  
    wire wr_en_gated = wr_en && !full;
    wire rd_en_gated = rd_en && !empty;

    gray_counter #(.WIDTH(ADDR_WIDTH+1)) u_wptr(
        .clk (wr_clk),
        .rst_n (wr_rst_n),
        .en (wr_en_gated),
        .bin_out (wptr_bin),
        .gray_out (wptr_gray));

    gray_counter #(.WIDTH(ADDR_WIDTH+1)) u_rptr(
        .clk (rd_clk),
        .rst_n (rd_rst_n),
        .en (rd_en_gated),
        .bin_out (rptr_bin),
        .gray_out (rptr_gray));
  
    synchronizer #(.WIDTH(ADDR_WIDTH+1)) u_sync_w2r(
        .dest_clk (rd_clk),
        .dest_rst_n (rd_rst_n),
        .async_in (wptr_gray),
        .sync_out (wptr_gray_in_rdomain));

    synchronizer #(.WIDTH(ADDR_WIDTH+1)) u_sync_r2w(
        .dest_clk (wr_clk),
        .dest_rst_n (wr_rst_n),
        .async_in (rptr_gray),
        .sync_out (rptr_gray_in_wrdomain));

    dual_port_ram #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem(
        .wr_clk (wr_clk),
        .wr_en (wr_en_gated),
        .wr_addr (wptr_bin[ADDR_WIDTH-1:0]),
        .wr_data (wr_data),
        .rd_clk (rd_clk),
        .rd_addr (rptr_bin[ADDR_WIDTH-1:0]),
        .rd_data (rd_data));

    assign empty = (rptr_gray == wptr_gray_in_rdomain);   
    assign full = (wptr_gray == { ~rptr_gray_in_wrdomain[ADDR_WIDTH:ADDR_WIDTH-1],
                                 rptr_gray_in_wrdomain[ADDR_WIDTH-2:0] });
endmodule
