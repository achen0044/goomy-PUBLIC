// RESERVATION STATION BABEYYY
`include "constants.svh"
// `timescale 1ps/1ps

// - PARAM ORDER FOR RES STA
//     sub (3): taddr, aval, bval
//     movl (2): taddr, i
//     movh (3): taddr, i, tval
//     ALL jump (3): tval, aval, jump type
//     ld/st (4): taddr, aval, tval, action type

module res_sta #(parameter int PARAM_COUNT = 3)
    (input clk,
        input has_in, input [`ROB_QUEUE_BITS-1:0] in_uid,
        input [15:0] in_params [PARAM_COUNT], input [`ROB_QUEUE_BITS:0] in_writers [PARAM_COUNT],
        input finishing_instr_queue[$:`MAX_FINISH_SIZE], // get broadcasts from all finishing instrs
        input ROB_entry_t entire_rob[`ROB_QUEUE_SIZE],
        output has_out, output [`ROB_QUEUE_BITS-1:0] out_uid, output [PARAM_COUNT-1:0] [15:0] out_params
    );

    localparam QUEUE_SIZE = 16;
    `define QUEUE_BITS $clog2(QUEUE_SIZE) // takes log base 2


    typedef struct packed {
        bit [`ROB_QUEUE_BITS-1:0] uids;
        bit [PARAM_COUNT-1:0] [15:0] params; // NOTE keep note that it's descending
        bit [PARAM_COUNT-1:0] [`ROB_QUEUE_BITS:0] writers;
        bit [PARAM_COUNT-1:0] has_writers;
        bit valid;
    } entry_t;

    entry_t queue [QUEUE_SIZE];


    integer q;
    initial begin
        for (q = 0; q < QUEUE_SIZE; q++) begin
            queue[q] = 0;
        end
    end

    bit [`QUEUE_BITS-1:0] tail = 0;
    bit [`QUEUE_BITS-1:0] head = 0;

    bit exec_once = 1;

    integer i;
    integer j;
    integer k;
    integer l;


    WB_entry_t temp[$:`MAX_FINISH_SIZE];
    assign temp = finishing_instr_queue;
    reg instantly_resolved = 0;
    reg normally_resolved = 0;

    integer instant_resolve = 1;
    integer a;
    integer b;
    always @(posedge clk) begin
        instantly_resolved <= 0;
        normally_resolved <= 0;
        saved_has_out = 0;
        exec_once <= 1;
        if (has_in) begin
            // check if instantly resolve
            for (a = 0; a < PARAM_COUNT; a++) begin
                if (in_writers[a][`ROB_QUEUE_BITS] == 0) begin
                    instant_resolve = 0;
                end
            end
            // IF INSTANTLY RESOLVE:
            if (instant_resolve == 1) begin //send off ready entries
                instantly_resolved <= 1;
                saved_out_uid <= in_uid;
                for (b = 0; b < PARAM_COUNT; b++) begin
                    saved_out_params[b] <= in_params[b];
                end
                saved_has_out = 1;
                exec_once <= 0;
            end
            else begin
                queue[tail].uids <= in_uid;
                for (j = 0; j < PARAM_COUNT; j++) begin
                    queue[tail].params[j] <= in_params[j];
                    queue[tail].writers[j] <= in_writers[j];
                    queue[tail].has_writers[j] <= in_writers[j][`ROB_QUEUE_BITS];
                    queue[tail].valid <= 1;
                end
                tail <= tail + 1; // NOTE do we ever want to worry about the tail running into the head
            end
        end

        // should we go from i = head until i = tail instead of looping through absolutely everything
        // we can think about efficiency later
        if (!has_in | (instant_resolve != 1)) begin
            /*verilator unroll_full*/
            for (i = 0; i < QUEUE_SIZE; i++) begin
                //only do stuff if entry is valid
                if (queue[i].valid) begin
                    /*verilator unroll_full*/
                    for (l = 0; l < `MAX_FINISH_SIZE; l++) begin // update readiness
                        if (l < temp.size()) begin
                            for (k = 0; k < PARAM_COUNT; k++) begin
                                // 0 as top bit means someone is writing
                                if (queue[i].writers[k] == {1'b0, temp[l].uid}) begin
                                    queue[i].writers[k] <= 1 << (`ROB_QUEUE_BITS); // want top bit 1
                                    queue[i].params[k] <= temp[l].val;
                                    // change bit to signify that no one is writing to this param
                                    queue[i].has_writers[k] <= 1'b1;
                                end

                            end
                        end
                    end

                    for (k = 0; k < PARAM_COUNT; k++) begin
                        if ((queue[i].has_writers[k] == 0) & entire_rob[queue[i].writers[k][`ROB_QUEUE_BITS-1:0]].done) begin
                            queue[i].writers[k] <= 1 << `ROB_QUEUE_BITS;
                            queue[i].params[k] <= entire_rob[queue[i].writers[k][`ROB_QUEUE_BITS-1:0]].val;
                            queue[i].has_writers[k] <= 1'b1;
                        end
                    end

                    // check if has_writers is all ones (means no writers)
                    if ((queue[i].has_writers == {PARAM_COUNT{1'b1}}) & exec_once) begin //send off ready entries
                        queue[i].valid <= 0;
                        saved_out_uid <= queue[i].uids;
                        saved_out_params <= queue[i].params;
                        normally_resolved <= 1;
                        saved_has_out = 1;
                        exec_once <= 0;
                        //if ({{(32 - `QUEUE_BITS){1'b0}}, head} == i) begin
                        //    head <= head + 1;
                        //end
                    end
                    
                    if (saved_has_out) begin
                        queue[i] <= queue[i+1]; //shift things up the queue
                    end
                end
            end
        end
        exec_once <= 1; // hope this works
    end

    reg [`ROB_QUEUE_BITS-1:0] saved_out_uid;
    reg [PARAM_COUNT-1:0] [15:0] saved_out_params;
    reg saved_has_out = 0;

    assign out_params = saved_out_params;
    assign out_uid = saved_out_uid;
    assign has_out = saved_has_out;

    // DEBUG DISPLAY WIRES TIMEEEE
    entry_t q0 = queue[0];
    bit [`ROB_QUEUE_BITS-1:0] q0_uid = q0.uids;
    bit [PARAM_COUNT-1:0] [15:0] q0_params = q0.params;
    bit [PARAM_COUNT-1:0] [`ROB_QUEUE_BITS:0] q0_writers = q0.writers;
    bit [PARAM_COUNT-1:0] q0_has_writers = q0.has_writers;
    bit q0_valid = q0.valid;
    entry_t q1 = queue[1];
    bit [`ROB_QUEUE_BITS-1:0] q1_uid = q1.uids;
    bit [PARAM_COUNT-1:0] [15:0] q1_params = q1.params;
    bit [PARAM_COUNT-1:0] [`ROB_QUEUE_BITS:0] q1_writers = q1.writers;
    bit [PARAM_COUNT-1:0] q1_has_writers = q1.has_writers;
    bit q1_valid = q1.valid;
    entry_t q2 = queue[2];
    bit [`ROB_QUEUE_BITS-1:0] q2_uid = q2.uids;
    bit [PARAM_COUNT-1:0] [15:0] q2_params = q2.params;
    bit [PARAM_COUNT-1:0] [`ROB_QUEUE_BITS:0] q2_writers = q2.writers;
    bit [PARAM_COUNT-1:0] q2_has_writers = q2.has_writers;
    bit q2_valid = q2.valid;

    int bcast_size = finishing_instr_queue.size();
    //entry_t queue2 = queue[2];
    //entry_t queue3 = queue[3];
    //entry_t queue4 = queue[4];
    //entry_t queue5 = queue[5];
    //entry_t queue6 = queue[6];
    //entry_t queue7 = queue[7];
    //entry_t queue8 = queue[8];
    //entry_t queue9 = queue[9];
    //entry_t queue10 = queue[10];
    //entry_t queue11 = queue[11];
    //entry_t queue12 = queue[12];
    //entry_t queue13 = queue[13];
    //entry_t queue14 = queue[14];
    //entry_t queue15 = queue[15];

endmodule
