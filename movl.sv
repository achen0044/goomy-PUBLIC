// `timescale 1ps / 1ps

module movl // params order: taddr, i
    (input clk,
    input has_incoming, input [`ROB_QUEUE_BITS-1:0] in_uid, input [1:0][15:0] params,
    output has_outgoing, output [`ROB_QUEUE_BITS-1:0] out_uid, output [15:0] result_val, output [17:0] out_loc
    );

    // does this module even need to be clocked at all (no ?)
    assign out_uid = in_uid;
    assign has_outgoing = has_incoming;
    assign result_val = {{8{params[1][7]}}, params[1][7:0]};
    assign out_loc = {2'b0, params[0]}; //high two 0 means register
endmodule
