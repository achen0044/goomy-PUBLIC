module branch
    //     ALL jump (3): tval, aval, jump type
    (input clk,
    input has_incoming, input [`ROB_QUEUE_BITS-1:0] in_uid, input [2:0][15:0] params,
    output has_outgoing, output [`ROB_QUEUE_BITS-1:0] out_uid, output [15:0] result_val, output [17:0] out_loc
    );

    assign out_uid = in_uid;
    assign has_outgoing = has_incoming;

    //read register and record branch location
    assign result_val = params[0];

    //ternary here to determine branch
    //branches
    wire branch =
        (params[2]== 0  & params[1] == 0) |
        (params[2]== 1 & params[1] != 0) |
        (params[2]== 2 & $signed(params[1]) < 0) |
        (params[2]== 3 & $signed(params[1]) >= 0);

    assign out_loc = {17'b10000000000000000, branch}; //not load or store, not going anywhere

endmodule
