// `timescale 1ps / 1ps
`include "constants.svh"

module rob (
    input clk,
    input has_incoming, input [15:0] in_pc, // corresponds to thing being added to ROB
    input finishing_instr_queue[$:`MAX_FINISH_SIZE],
    output has_outgoing, output [`ROB_QUEUE_BITS-1:0] out_uid, // corresponds to UID to give to task allocator
    output WB_entry_t committing_insts [$:`ROB_QUEUE_SIZE], // corresponds to instruction commited
    output ROB_entry_t entire_rob[`ROB_QUEUE_SIZE],
    input flush_all
    );

    reg [`ROB_QUEUE_BITS-1:0] head = 0;
    reg [`ROB_QUEUE_BITS-1:0] tail = 0;

    typedef struct packed {
        bit [15:0] pc;
        bit [17:0] loc; // bit 16 1 indicates a store,
                        // bit 17 1 indicates a jump,
                        // both 1s indicates we don't know (halt)
                        // both 0 means write to reg
        bit [15:0] val;
        bit done;
    } ROB_entry_t;

    ROB_entry_t queue [`ROB_QUEUE_SIZE];
    assign entire_rob = queue;

    integer i;
    initial begin
        for (i = 0; i < `ROB_QUEUE_SIZE-1; i++) begin
            queue[i].pc = 16'b0;
            queue[i].loc = 18'b0;
            queue[i].val = 16'b0;
            queue[i].done = 1'b0;
        end
    end


    WB_entry_t temp[$:`MAX_FINISH_SIZE];
    assign temp = finishing_instr_queue;

    reg saved_has_outgoing = 1'b0;
    reg [`ROB_QUEUE_BITS-1:0] saved_out_uid;
    assign has_outgoing = saved_has_outgoing;
    assign out_uid = saved_out_uid;

    integer j;
    always @(posedge clk) begin
        if (!flush_all) begin
            if (has_incoming) begin
                queue[tail].pc <= in_pc;
                queue[tail].done <= 1'b0;
                queue[tail].loc <= 18'b110000000000000000;
                saved_out_uid <= tail;
                tail <= tail + 1;
            end
            saved_has_outgoing <= has_incoming;

            /*verilator unroll_full*/
            for (j = 0; j < `MAX_FINISH_SIZE; j++) begin
                if (j < temp.size()) begin
                    queue[temp[j].uid].done <= 1'b1;
                    queue[temp[j].uid].val <= temp[j].val;
                    queue[temp[j].uid].loc <= temp[j].loc;
                end
            end
        end
    end

    WB_entry_t committing_inst;

    WB_entry_t committing_inst_0 = committing_insts[0];
    bit ci0_finishing_inst = committing_inst_0.finishing_instr;
    bit [`ROB_QUEUE_BITS - 1:0] ci0_uid = committing_inst_0.uid;
    bit [15:0] ci0_val = committing_inst_0.val;
    bit [17:0] ci0_loc = committing_inst_0.loc;
    WB_entry_t committing_inst_1 = committing_insts[1];
    bit ci1_finishing_inst = committing_inst_1.finishing_instr;
    bit [`ROB_QUEUE_BITS - 1:0] ci1_uid = committing_inst_1.uid;
    bit [15:0] ci1_val = committing_inst_1.val;
    bit [17:0] ci1_loc = committing_inst_1.loc;

    integer c1_q_size = committing_insts.size();

    // WB_entry_t committing_inst_queue [$:`ROB_QUEUE_SIZE];

    always @(posedge clk) begin
        if (!flush_all) begin
            committing_insts.delete();
            while (queue[head].done) begin // COMMIT TIME
                committing_inst.finishing_instr = 1;
                committing_inst.uid = head;
                committing_inst.val = queue[head].val;
                committing_inst.loc = queue[head].loc;
                committing_insts.push_back(committing_inst);
                head = head + 1;
            end
        end
    end

    always @(posedge clk) begin // flush_all BEHAVIOUR HERE
        if (flush_all) begin
            committing_insts.delete();
            /*verilator unroll_full*/
            for (i = 0; i < `ROB_QUEUE_SIZE-1; i++) begin // NOTE copied in from the init block
                queue[i].pc <= 16'b0;
                queue[i].loc <= 18'b0;
                queue[i].val <= 16'b0;
                queue[i].done <= 1'b0;
            end
            head = 0;
            tail <= 0;
            saved_has_outgoing <= 0;
        end
    end


    // DEBUG DISPLAY WIRES YIIPEEE

    wire [15:0] pc_0 = queue[0].pc;
    wire [17:0] loc_0 = queue[0].loc;
    wire [15:0] val_0 = queue[0].val;
    wire done_0 = queue[0].done;
    wire [15:0] pc_1 = queue[1].pc;
    wire [17:0] loc_1 = queue[1].loc;
    wire [15:0] val_1 = queue[1].val;
    wire done_1 = queue[1].done;
    wire [15:0] pc_2 = queue[2].pc;
    wire [17:0] loc_2 = queue[2].loc;
    wire [15:0] val_2 = queue[2].val;
    wire done_2 = queue[2].done;
    wire [15:0] pc_3 = queue[3].pc;
    wire [17:0] loc_3 = queue[3].loc;
    wire [15:0] val_3 = queue[3].val;
    wire done_3 = queue[3].done;
    wire [15:0] pc_4 = queue[4].pc;
    wire [17:0] loc_4 = queue[4].loc;
    wire [15:0] val_4 = queue[4].val;
    wire done_4 = queue[4].done;
    wire [15:0] pc_5 = queue[5].pc;
    wire [17:0] loc_5 = queue[5].loc;
    wire [15:0] val_5 = queue[5].val;
    wire done_5 = queue[5].done;
    wire [15:0] pc_6 = queue[6].pc;
    wire [17:0] loc_6 = queue[6].loc;
    wire [15:0] val_6 = queue[6].val;
    wire done_6 = queue[6].done;
    wire [15:0] pc_7 = queue[7].pc;
    wire [17:0] loc_7 = queue[7].loc;
    wire [15:0] val_7 = queue[7].val;
    wire done_7 = queue[7].done;

    //more debug display wires (for finishing queue)
    int finish_size = temp.size();
endmodule
