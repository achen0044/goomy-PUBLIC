// `timescale 1ps / 1ps

module movh
    // movh (3): 0 taddr, 1 i, 2 tval
    (input clk,
    input has_incoming, input [`ROB_QUEUE_BITS-1:0] in_uid, input [2:0][15:0] params,
    output has_outgoing, output [`ROB_QUEUE_BITS-1:0] out_uid, output [15:0] result_val, output [17:0] out_loc
    );

    // does this module even need to be clocked at all (no ?)
    assign out_uid = in_uid;
    assign has_outgoing = has_incoming;
    assign result_val = {params[1][7:0], params[2][7:0]};
    assign out_loc = {2'b0, params[0]};

endmodule
