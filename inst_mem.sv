// `timescale 1ps / 1ps

module inst_mem (
    input clk,
    input [15:1] raddr0_,
    output [15:0] rdata0_
    );  //READ ONLY

    reg [15:0] inst_data[16'h7fff];

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("./inst.hex", inst_data);
    end

    reg [15:1] raddr0;
    reg [15:0] rdata0;

    assign rdata0_ = rdata0;

    integer i;
    always @(posedge clk) begin
        raddr0 <= raddr0_;
        //for (i = 0; i < `INST_COUNT; i++) begin
        //    rdata0[i] <= inst_data[raddr0 + i];
        //end
        rdata0 <= inst_data[raddr0];
    end


    // DEBUG / TEST DISPLAY WIRES
    wire [15:0] data0 = inst_data[0];
    wire [15:0] data1 = inst_data[1];
    wire [15:0] data2 = inst_data[2];
    wire [15:0] data3 = inst_data[3];
    wire [15:0] data4 = inst_data[4];
    wire [15:0] data5 = inst_data[5];
    wire [15:0] data6 = inst_data[6];
    wire [15:0] data7 = inst_data[7];
    wire [15:0] data8 = inst_data[8];
    wire [15:0] data9 = inst_data[9];
    wire [15:0] dataa = inst_data[10];
    wire [15:0] datab = inst_data[11];
    wire [15:0] datac = inst_data[12];
    wire [15:0] datad = inst_data[13];
    wire [15:0] datae = inst_data[14];
    wire [15:0] dataf = inst_data[15];

endmodule
