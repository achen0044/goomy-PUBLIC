`include "constants.svh"

module load_store // param order: taddr, aval, tval, action inst_type
    (input clk,
    input has_incoming, input [`ROB_QUEUE_BITS-1:0] in_uid, input [3:0][15:0] params,
    output has_outgoing, output [`ROB_QUEUE_BITS-1:0] out_uid, output [15:0] result_val, output [17:0] out_loc,
    output [15:1] out_ld_raddr,
    output [15:1] mem_raddr,
    input [15:0] mem_rval
    );

    typedef struct packed {
        bit valid;
        bit inst_type;
        bit [`ROB_QUEUE_BITS-1:0] uid;
        bit [17:0] loc;
        bit [15:0] val;
    } transit_entry_t;

    localparam rdelay = 50;
    transit_entry_t rtransit_queue[0:rdelay-1]; // NOTE if we want multi-send-from-res-sta may need to make into a 2D array perhaps

    initial begin
        for (i = 0; i < rdelay; i++) begin
            rtransit_queue[i] = 0;
        end
    end

reg saved_has_outgoing = 0;
    reg [`ROB_QUEUE_BITS-1:0] saved_out_uid = 0;
    reg [15:0] saved_result_val = 0;
    reg [17:0] saved_out_loc = 0;
    assign has_outgoing = saved_has_outgoing;
    assign out_uid = saved_out_uid;
    assign result_val = saved_result_val;
    assign out_loc = saved_out_loc;
    
    reg [15:1] saved_mem_raddr = 0;
    assign mem_raddr = saved_mem_raddr;

    reg [15:1] saved_out_ld_raddr = 0;
    assign out_ld_raddr = saved_out_ld_raddr;

    integer i;
    integer stbuf_idx;
    always @(posedge clk) begin
        // ==== EXIT ITEMS FROM QUEUE
        transit_entry_t exiting_entry = rtransit_queue[rdelay-1];
        if (rtransit_queue[rdelay-1].valid & (exiting_entry.inst_type==0)) begin
            // THE INCOMING MEM READ VAL SHOULD CORRESPOND TO THIS ONE!
            saved_out_ld_raddr = exiting_entry.val[15:1];
            for (stbuf_idx = 0; stbuf_idx < `ROB_QUEUE_BITS; stbuf_idx++) begin
                bit forwarding_from_stbuf = 0;
                bit [15:0] forwarded_rval = 0;
                bit [`ROB_QUEUE_BITS:0] forwarded_writer = 0;
                if (st_buffer[stbuf_idx].waddr == saved_out_ld_raddr) begin
                    if (!forwarding_from_stbuf) || (forwarding_from_stbuf && ((exiting_entry.uid - st_buffer[stbuf_idx].uid) > 0) &&
                        ((exiting_entry.uid - st_buffer[stbuf_idx].uid)<(exiting_entry.uid - forwarded_writer))) begin // already a val; check for which takes precedence
                        // update forwarded content
                        forwarding_from_stbuf = 1'b1;
                        forwarded_rval = st_buffer[stbuf_idx].val;
                        forwarded_writer = st_buffer[stbuf_idx].waddr;

                    end

                end
            end
            exiting_entry.val = (forwarding_from_stbuf) ? forwarded_rval : mem_rval;
        end
        
        // send the value on its way
        saved_has_outgoing <= exiting_entry.valid;
        saved_out_uid <= exiting_entry.uid;
        saved_result_val <= exiting_entry.val;
        saved_out_loc <= exiting_entry.loc;


        // ==== SCOOTCH "QUEUE" ALONG // NOTE may need to adjust timing a little :3
        for (i = 1; i < rdelay; i++) begin
            rtransit_queue[i] <= rtransit_queue[i-1];
        end

        // ==== ENTER ITEMS INTO QUEUE
        if (has_incoming) begin // will only have one incoming at a time, on clock
            
            transit_entry_t entry;

            entry.valid = 1'b1;
            entry.inst_type = params[3][0];
            entry.uid = in_uid;
            if (!params[3][0]) begin //ld (action inst_type=0)
                entry.val = params[1]; // WILL BE OVERWRITTEN AT EXIT OF QUEUE
                entry.loc = {2'b00, params[0]}; // taddr; write to reg
                saved_mem_raddr = params[1][15:1];
                rtransit_queue[0] <= entry;
            end
            else begin //st = 1
            //immediately output, nothing to do here
                saved_has_outgoing <= 1'b1;
                saved_out_uid <= in_uid;
                saved_result_val <= params[1];
                saved_out_loc <= {2'b01, params[2]};
            end
        end
        else begin
            rtransit_queue[0] <= 0;
        end
    end

    // ===============================
    // ==== STORE BUFFER ZONE ========
    typedef struct packed {
        bit valid;
        bit [`ROB_QUEUE_BITS-1:0] uid;
        bit [17:0] loc;
        bit [15:0] val;
        bit [5:0] write_countdown; // count down from 50 to wait for mem write delay. on 0, item is destroyed from st buffer
    } stbuf_entry_t;
    stbuf_entry_t st_buffer[0:`ROB_QUEUE_SIZE]; // NOTE !! FIX THE "OLDER/NEWER" CHECK; RN IT RELIES ON UID WHICH CAN WRAP AROUND
    reg [`ROB_QUEUE_BITS:0] head = 0;
    reg [`ROB_QUEUE_BITS:0] tail = 0;
    // ADD TO ST_BUFFER ON FINISH
    // done in the big always block!

    if (has_incoming & params[3][0]) begin //is a store
        st_buffer[tail].valid <= 1'b1;
        st_buffer[tail].uid <= in_uid;
        st_buffer[tail].loc <= {2'b01, params[2]};
        st_buffer[tail].val <= params[1];
        st_buffer[tail].write_countdown = 50;
        tail <= tail + 1;
    end

    // REMOVE FROM ST_BUFFER ON COMMIT
        
    
    // ==== STORE BUFFER ZONE ========
    // ===============================


endmodule
