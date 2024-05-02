// `timescale 1ps / 1ps
/* verilator lint_off ASCRANGE */
module sub // params: sub: taddr, a val, b val
    (input clk,
    input has_incoming, input [`ROB_QUEUE_BITS-1:0] in_uid, input [2:0][15:0] params,
    output has_outgoing, output [`ROB_QUEUE_BITS-1:0] out_uid, output [15:0] result_val, output [17:0] out_loc
    );

    // does this module even need to be clocked at all (no ?)
    assign out_uid = in_uid;
    assign has_outgoing = has_incoming;
    assign result_val = params[1] - params[2];
    assign out_loc = {2'b0, params[0]}; //high two 0 means register
endmodule
