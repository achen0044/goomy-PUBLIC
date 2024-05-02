module unit_tester();

    initial begin
        $dumpfile("unit_tester.vcd");
        $dumpvars(0,main);
    end

    // clock
    wire clk;
    clock c0(clk);

    wire [15:1] raddr0_ = 15'h0000;
    wire [15:1] raddr1_ = 15'h0002;

    reg[32:0] counter = 0;

    wire wen = (counter == 0 | counter == 1)? 1 : 0;
    reg [15:1] waddr = 0;
    wire[15:0] wdata = (counter == 0) ? 16'h0032 : 16'h0030;

    always @(posedge clk) begin
        if (counter >= 1000) begin
            $finish;
        end

        counter <= counter+1;
        waddr <= 15'h0002;

        if (counter == 50) begin
            $display("rdata0: ", rdata0_);
        end
        if (counter == 51) begin
            $display("rdata1: ", rdata1_);
        end
    end

    wire[15:0] rdata0_;
    wire[15:0] rdata1_;

    stor_mem stor_mem(clk,
    raddr0_, rdata0_,
    raddr1_, rdata1_,
    wen, waddr, wdata);

    // vv NEW SIGNATURE vv
    // module regs(input clk,
    // input [3:0]raddr0_, output [15:0]rdata0, output [`ROB_QUEUE_BITS:0]rwriter0,
    // input [3:0]raddr1_, output [15:0]rdata1, output [`ROB_QUEUE_BITS:0]rwriter1,
    // input change_writer, input[3:0]writer_waddr, input [`ROB_QUEUE_BITS:0]new_writer,
    // input change_data, input [3:0]data_waddr, input [15:0]new_data, input[`ROB_QUEUE_BITS:0]data_writer);

endmodule
