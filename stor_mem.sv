// `timescale 1ps / 1ps

module stor_mem (
    input clk,
    input [15:1] raddr0_,
    output [15:0] rdata0_,
    
    input wen_,
    input [15:1] waddr_,
    input [15:0] wdata_
    );

    reg [15:0] stor_data[16'h7fff];

    initial begin
        $readmemh("./mem.hex", stor_data);
    end


    // `define wdelay_len 49 NO MORE WRITE DELAY
    `define rdelay_len 50

    // create delay in reading from memory
    // will read the value there was at the moment it was read
    // to not be impacted by future stores (is read before write a thing?)
    reg [15:0] rdata0[0:`rdelay_len];

    assign rdata0_ = rdata0[`rdelay_len - 1];


    integer i;
    integer spec_idx;

    always @(posedge clk) begin
        // if writing at same time as read ? is that problem ?
        // no guarantee the store instruction will actually be before the load so ??

        for (i = 1; i < (`rdelay_len); i++) begin  // shift stuff
            rdata0[i] <= rdata0[i-1];
            //rdata1[i] <= rdata1[i-1];
        end

        if (wen_) begin
            stor_data[waddr_] <= wdata_; // NOTE: no DELAY BETWEEN INPUT AND ACTUAL WRITE. do we want to make this symmetrical?
        end
    end



    // FOR VIEWING THE DELAY ZONE
    wire [15:0] rdata0_0 = rdata0[0];
    wire [15:0] rdata0_1 = rdata0[1];
    // wire [15:1] rdata0_last = rdata0[`wdelay_len];

    //wire [15:0] rdata1_0 = rdata1[0];
    //wire [15:0] rdata1_1 = rdata1[1];
    // wire [15:1] rdata1_last = rdata1[`wdelay_len];

    // LOOKING DIRECTLY INTO MEM SLOTS
    wire [15:0] data_0 = stor_data[0];
    wire [15:0] data_1 = stor_data[1];
    wire [15:0] data_2 = stor_data[2];
    wire [15:0] data_3 = stor_data[3];
    wire [15:0] data_4 = stor_data[4];
    wire [15:0] data_5 = stor_data[5];
    wire [15:0] data_6 = stor_data[6];
    wire [15:0] data_7 = stor_data[7];
    wire [15:0] data_8 = stor_data[8];
    wire [15:0] data_9 = stor_data[9];
    wire [15:0] data_a = stor_data[10];
    wire [15:0] data_b = stor_data[11];
    wire [15:0] data_c = stor_data[12];
    wire [15:0] data_d = stor_data[13];
    wire [15:0] data_e = stor_data[14];
    wire [15:0] data_f = stor_data[15];

endmodule
