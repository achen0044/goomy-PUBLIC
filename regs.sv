// `timescale 1ps / 1ps
`include "constants.svh"

module regs
    (input clk,
    input [3:0] raddr0_,
    output [15:0] rdata0, output [`ROB_QUEUE_BITS:0] rwriter0,
    input [3:0] raddr1_,
    output [15:0] rdata1, output [`ROB_QUEUE_BITS:0] rwriter1,
    input change_writer, input [3:0] writer_waddr, input [`ROB_QUEUE_BITS-1:0] new_writer,
    input reg_writer_t all_reg_writes[$:`ROB_QUEUE_SIZE],
    input flush_all
    );

    reg [15:0] data[15];
    reg [`ROB_QUEUE_BITS:0] writer[15];

    integer i;
    initial begin
        data [0] = 0;
        for (i = 0; i < 16; i++) begin
            writer[i] = 1 << (`ROB_QUEUE_BITS);
        end
    end

    reg [3:0] raddr0;
    reg [3:0] raddr1;

    assign rdata0 = data[raddr0];
    assign rdata1 = data[raddr1];
    assign rwriter0 = writer[raddr0];
    assign rwriter1 = writer[raddr1];


    integer j;
    always @(posedge clk) begin
        raddr0 <= raddr0_;
        raddr1 <= raddr1_;
        //if (change_data & data_waddr != 0) begin
        //    data[data_waddr] <= new_data;
        //    if ((data_writer == writer[data_waddr][`ROB_QUEUE_BITS - 1: 0])) begin //check if this is the inst is to write at all
        //        // recall: top bit 1 if no writer
        //        writer[data_waddr][`ROB_QUEUE_BITS] <= 1'b1;
        //    end
        //end
        /*verilator unroll_full*/
        for (i = 0; i < `ROB_QUEUE_SIZE; i++) begin
            if (i < all_reg_writes.size()) begin
                data[all_reg_writes[i].data_waddr] <= all_reg_writes[i].new_data;
                if (all_reg_writes[i].writer_uid == writer[all_reg_writes[i].data_waddr][`ROB_QUEUE_BITS - 1: 0]) begin
                    writer[all_reg_writes[i].data_waddr][`ROB_QUEUE_BITS] <= 1'b1;
                end
            end
        end
        if (change_writer & writer_waddr != 0) begin
            writer[writer_waddr] <= {1'b0, new_writer}; // just overwrite
        end

        if (flush_all) begin
            for (j = 0; j < 16; j++) begin
                writer[j] <= 1 << (`ROB_QUEUE_BITS); // nothing has a writer now
                                    // NOTE should we clear out the values as well? otherwise a following inst might read and assume its been committed when should be invalid
                                    // I think we assume that the values that've been committed are correct?
            end
        end
    end

    // debug display wire yiopaet
    wire [31:0] reg_write_size = all_reg_writes.size();
    reg_writer_t all_writes0 = all_reg_writes[0];
    bit [3:0] aw0_waddr = all_writes0.data_waddr;
    bit [15:0] aw0_data = all_writes0.new_data;
    bit [`ROB_QUEUE_BITS-1:0] aw0_uid = all_writes0.writer_uid;
    reg_writer_t all_writes1 = all_reg_writes[1];
    bit [3:0] aw1_waddr = all_writes1.data_waddr;
    bit [15:0] aw1_data = all_writes1.new_data;
    bit [`ROB_QUEUE_BITS-1:0] aw1_uid = all_writes1.writer_uid;

endmodule
