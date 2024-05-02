`include "constants.svh"

module cpu();
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0,cpu);
    end

    // clock
    wire clk;
    clock c0(clk);
    wire halt = ROB_has_outgoing & WB_halt;
    counter ctr(halt,clk);


// =====================================================================================
// ==== READ INST STAGE ================================================================

    // PC
    reg [15:0]RI_pc = 16'h0000;

    //mem just with program instructions (can't write, no need for multiple reads)
    //gets initialized on startup (makefile)
    inst_mem inst_mem(
        .clk(clk),
        .raddr0_(RI_pc[15:1]),
        .rdata0_(DC_inst) //TODO increase number of outs once we get it working
    );


// ==== READ INST STAGE ================================================================
// =====================================================================================

    reg[15:0]RI_saved_pc;
    reg RI_valid = 1'b1;

    always @(posedge clk) begin
        RI_saved_pc <= RI_pc;
        RI_pc <= (WB_flush_all) ? //indicates a jump
                WB_jump_loc :
                    RI_pc + 2; // update the PC!
    end

// =======================================================================================
// ==== PASSTHROUGH STAGE ================================================================

    //nothing to do here except hang out

// ==== PASSTHROUGH STAGE ================================================================
// =======================================================================================

    reg[15:0]PT_saved_pc;
    reg PT_valid= 1'b0;

    always @(posedge clk) begin
        PT_saved_pc <= RI_saved_pc;
    end

// ===================================================================================
// ==== DECODER STAGE ================================================================
    typedef enum bit [3:0] {SUB, MOVL, MOVH, JZ, JNZ, JS, JNS, LD, ST, HALT} inst_type_t;

    wire [15:0]DC_inst; //will come from memory yay it works now
    `define a_addr 11:8 //raw parameters
    `define b_addr 7:4
    `define t_addr 3:0
    `define i_immd 11:4

    //try case statements?
    inst_type_t DC_inst_type;

    assign DC_inst_type =
        (DC_inst[15:12]==4'b1000) ? MOVL :
        (DC_inst[15:12]==4'b1001) ? MOVH :
        (DC_inst[15:12]==4'b0000) ? SUB :
        (DC_inst[15:12]==4'b1110) ? // might be a jump
            (DC_inst[7:4]==4'b0000) ? JZ :
            (DC_inst[7:4]==4'b0001) ? JNZ :
            (DC_inst[7:4]==4'b0010) ? JS :
            (DC_inst[7:4]==4'b0011) ? JNS :
            HALT : //wasn't actually a jump
        (DC_inst[15:12]== 4'b1111) ? // might be a load or store
            (DC_inst[7:4]==4'b0000) ? LD :
            (DC_inst[7:4]==4'b0001) ? ST :
            HALT : //wasn't actually a load or store
        HALT;

    wire [3:0] reg_raddr_1 = (DC_inst_type == SUB) ? DC_inst[`b_addr] : DC_inst[`t_addr];

// ==== DECODER STAGE ================================================================
// ===================================================================================

    reg [15:0] DC_saved_inst;
    inst_type_t DC_saved_inst_type;
    reg [15:0] DC_saved_pc;
    reg DC_valid = 1'b0;

    always @(posedge clk) begin
        DC_saved_inst <= DC_inst;
        DC_saved_inst_type <= DC_inst_type;
        DC_saved_pc <= PT_saved_pc;
    end

    // make reg read requests in decode! not TA!!!
    // vv these all for the registers! vv
    wire [3:0] DC_param_loc0; // for an initial inst dependncy and/or lack thereof check
    wire [3:0] DC_param_loc1;
    assign DC_param_loc0 = DC_inst[`a_addr];
    assign DC_param_loc1 = (DC_inst_type==SUB) ? DC_inst[`b_addr] : DC_inst[`t_addr];

// ====================================================================================
// ==== TASK ALLOCATOR ================================================================

    wire [15:0] TA_inst = DC_saved_inst;
    inst_type_t TA_inst_type = DC_saved_inst_type;
    wire [15:0] TA_pc = DC_saved_pc;
    // NOTE kind of useless for the ones that don't use the value at t like ld or movl; but think about this later

    wire TA_change_writer;
    wire [3:0] TA_change_writer_addr;
    wire [`ROB_QUEUE_BITS-1:0] TA_change_new_writer;

    wire TA_inst_writes_to_reg = (TA_inst_type==SUB) || (TA_inst_type==MOVL) || (TA_inst_type==MOVH) || (TA_inst_type==LD);
    // NOTE i swear there was a wire for this already but i can't find it
    assign TA_change_writer = TA_valid & TA_inst_writes_to_reg; // why do we create a separate wire
    assign TA_change_writer_addr = TA_inst[`t_addr];
    assign TA_change_new_writer = ROB_out_uid; // NOTE !! check temporality. what if items in queue?
    // ^^ thus concludes the register inputs. ^^


    // vv these all for ROB-logging and "sending" (the "is this relevant to me" check is done res sta-side) to the relevant res sta! vv
    // outputs from reg
    wire [15:0] TA_param_val0;
    wire [`ROB_QUEUE_BITS:0] TA_param_writer0; // if top bit==1, then no one is writing.
    wire [15:0] TA_param_val1;
    wire [`ROB_QUEUE_BITS:0] TA_param_writer1; // we only need two (2) reg dependencies max for canonical funsemmbly
    // NOTE these will be useful once we like.... do any other inst aside from movl

    // ^^ thus concludes the logging/sending section ^^.

// ==== TASK ALLOCATOR ================================================================
// ====================================================================================

    reg TA_valid = 1'b0;

    // always @(posedge clk) begin

    // end

// ==========================================================================================
// ==== WRITEBACK STAGE =====================================================================
    typedef struct packed {
        // Bus broadcast. To be sent from an FXU
        bit finishing_instr; // NOTE is this bit even needed
        bit [`ROB_QUEUE_BITS-1:0] uid;
        bit [15:0] val;
        bit [17:0] loc; // same bit encoding as ROB location
    } WB_entry_t;

    //this is for instr which are in rob waiting to be in commit after they finish
    WB_entry_t WB_rob_queue [$:`MAX_FINISH_SIZE-1]; //bounded queue

    WB_entry_t movl_WB_rob_entry;
    assign movl_WB_rob_entry.finishing_instr = MOVL_has_outgoing;
    assign movl_WB_rob_entry.uid = MOVL_out_uid;
    assign movl_WB_rob_entry.val = MOVL_result_val;
    assign movl_WB_rob_entry.loc = MOVL_out_loc;

    WB_entry_t halt_WB_rob_entry;
    assign halt_WB_rob_entry.finishing_instr = (TA_inst_type == HALT);
    assign halt_WB_rob_entry.uid = ROB_out_uid;
    assign halt_WB_rob_entry.val = 0;
    assign halt_WB_rob_entry.loc = 18'b110000000000000000; //top two bits 0 for halt

    WB_entry_t sub_WB_rob_entry;
    assign sub_WB_rob_entry.finishing_instr = SUB_has_outgoing;
    assign sub_WB_rob_entry.uid = SUB_out_uid;
    assign sub_WB_rob_entry.val = SUB_result_val;
    assign sub_WB_rob_entry.loc = SUB_out_loc;

    WB_entry_t branch_WB_rob_entry;
    assign branch_WB_rob_entry.finishing_instr = BRANCH_has_outgoing;
    assign branch_WB_rob_entry.uid = BRANCH_out_uid;
    assign branch_WB_rob_entry.val = BRANCH_result_val;
    assign branch_WB_rob_entry.loc = BRANCH_out_loc;

    WB_entry_t movh_WB_rob_entry;
    assign movh_WB_rob_entry.finishing_instr = MOVH_has_outgoing;
    assign movh_WB_rob_entry.uid = MOVH_out_uid;
    assign movh_WB_rob_entry.val = MOVH_result_val;
    assign movh_WB_rob_entry.loc = MOVH_out_loc;
WB_entry_t ldst_WB_rob_entry;
    assign ldst_WB_rob_entry.finishing_instr = LDST_has_outgoing;
    assign ldst_WB_rob_entry.uid = LDST_out_uid;
    assign ldst_WB_rob_entry.val = LDST_result_val;
    assign ldst_WB_rob_entry.loc = LDST_out_loc;
  
    WB_entry_t ld_buffer_WB_rob_entry;
    assign ld_buffer_WB_rob_entry.finishing_instr = ld_really_done;
    assign ld_buffer_WB_rob_entry.uid = ld_new_uid;
    assign ld_buffer_WB_rob_entry.val = LD_buffer_result_val;
    assign ld_buffer_WB_rob_entry.loc = LD_buffer_out_loc;

    //make wires for this
    wire [15:0] LD_buffer_result_val;
    wire [17:0] LD_buffer_out_loc;


    WB_entry_t WB_popped_entry;
    always @(posedge clk) begin // https://www.chipverify.com/systemverilog/systemverilog-queue << for queueus
        // check if each module has an outgoing instr, if it does add to the ROB queue
        WB_rob_queue.delete();

        if (MOVL_has_outgoing) begin
            WB_rob_queue.push_back(movl_WB_rob_entry);
        end
        if (MOVH_has_outgoing) begin
            WB_rob_queue.push_back(movh_WB_rob_entry);
        end
        if (SUB_has_outgoing) begin
            WB_rob_queue.push_back(sub_WB_rob_entry);
        end
        if (BRANCH_has_outgoing) begin
            WB_rob_queue.push_back(branch_WB_rob_entry);
        end
        if (LDST_has_outgoing & LDST_out_loc[16]) begin //is a store
            WB_rob_queue.push_back(ldst_WB_rob_entry);
        end
        if (LD_buffer_has_outgoing) begin
            WB_rob_queue.push_back(ld_buffer_WB_rob_entry);
        end // TODO

        if (TA_inst_type == HALT) begin
            WB_rob_queue.push_back(halt_WB_rob_entry);
        end

        if (WB_flush_all) begin
            //WB_jumping = 0;
            WB_rob_queue.delete(); //will delete entire queue
        end
    end

    wire ROB_has_outgoing; // announcements after an item is committed to the ROB
    wire [`ROB_QUEUE_BITS-1:0] ROB_out_uid;


    // help how do we do this with multiple commits per cycle
    // section for jumping!
    wire WB_flush_all = WB_jumping;
        // for jump to legal
    wire WB_halt = WB_halting; // unknown but done = halt

    reg WB_jumping = 0;
    reg [15:0] WB_jump_loc = 0;
    reg WB_halting = 0;

    reg_writer_t all_reg_writes [$:`ROB_QUEUE_SIZE];
    reg_writer_t inst_writing_reg;

    //wire is_printing = ROB_has_committing & (ROB_commit_loc == 0);
    // DISPLAY OUTPUT
    integer i;
    always @(posedge clk) begin
        WB_jumping = 0;
        WB_halting = 0;
        for (i = 0; i < committing_insts.size(); i++) begin
            //is a print
            if (committing_insts[i].loc == 0 & !WB_jumping & !WB_halting) begin
                $write("%c", committing_insts[i].val[7:0]);
            end
            //check for jumping
            if (!WB_flush_all & !WB_halting & committing_insts[i].loc[17] & committing_insts[i].loc[0]) begin
                WB_jumping = 1;
                WB_jump_loc <= committing_insts[i].val;
            end
            //check for halting
            if (!WB_jumping & committing_insts[i].loc[17:16] == 2'b11) begin
                WB_halting = 1;
            end
            //check for reg writing
            if (!WB_jumping & ! WB_halting & (committing_insts[i].loc[17:16] == 0) & (committing_insts[i].loc != 0)) begin
                inst_writing_reg.data_waddr = committing_insts[i].loc[3:0];
                inst_writing_reg.new_data = committing_insts[i].val;
                inst_writing_reg.writer_uid = committing_insts[i].uid;
                all_reg_writes.push_back(inst_writing_reg);
            end
            //check for mem writing

            //check for storing
             if (committing_insts[i].loc[16] == 1) begin //yay commiting instr is a store
                mem_wen_reg <= 1;
                w_data_reg <= committing_insts[i].val;
                w_loc_reg <= committing_insts[i].loc;
            end
            else begin
                mem_wen_reg <= 0;
            end
        end
        //test
        //$display("DC_inst_type: ", DC_inst_type.name());
    end

    ROB_entry_t entire_rob [`ROB_QUEUE_SIZE];
    WB_entry_t committing_insts [$:`ROB_QUEUE_SIZE];
    rob rob ( .clk(clk),
        .has_incoming(DC_valid), .in_pc(DC_saved_pc), // corresponds to thing being added to ROB
        .finishing_instr_queue(WB_rob_queue),
        .has_outgoing(ROB_has_outgoing), .out_uid(ROB_out_uid), // corresponds to UID to give to task allocator
        .committing_insts(committing_insts),
        .entire_rob(entire_rob),
        .flush_all(WB_flush_all)
    );


    
// ==== WRITEBACK STAGE ================================================================
// =====================================================================================

    always @(posedge clk) begin
        if (!WB_flush_all) begin
            PT_valid <= RI_valid;
            DC_valid <= PT_valid;
            TA_valid <= DC_valid;
            // WB_valid controlled ROB-side
        end
        else begin
            PT_valid <= 0;
            DC_valid <= 0;
            TA_valid <= 0;
        end
    end

// =================================================================================
// ==== MODULE ZONE ================================================================

    // have to create all the reservation stations
    // one each for sub, movh, movl
    // one for jumps
    // one for LSU

    // =========================
    // ==== MOVH MODULE ========
    wire MOVL_rs_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] MOVL_rs_uid_out;
    wire [1:0] [15:0] MOVL_rs_params_out;
    res_sta #(.PARAM_COUNT(2)) movl_res_sta
    ( .clk(clk),
        .has_in(TA_inst_type==MOVL & ROB_has_outgoing), .in_uid(ROB_out_uid), // NOTE check on that "has in" temporality
        .in_params('{{12'b0,TA_inst[`t_addr]}, {8'b0, TA_inst[`i_immd]}}), .in_writers('{1 << (`ROB_QUEUE_BITS), 1 << (`ROB_QUEUE_BITS)}),
        .entire_rob(entire_rob),
        .finishing_instr_queue(WB_rob_queue), //movl has no broadcast
        .has_out(MOVL_rs_has_outgoing), .out_uid(MOVL_rs_uid_out), .out_params(MOVL_rs_params_out)
    );
    movl movl ( .clk(clk),
        .has_incoming(MOVL_rs_has_outgoing), .in_uid(MOVL_rs_uid_out), .params(MOVL_rs_params_out),
        .has_outgoing(MOVL_has_outgoing), .out_uid(MOVL_out_uid), .result_val(MOVL_result_val), .out_loc(MOVL_out_loc)
    );

    //outputs for movl unit
    wire MOVL_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] MOVL_out_uid;
    wire [15:0] MOVL_result_val;
    wire [17:0] MOVL_out_loc;
    // ==== MOVH MODULE ========
    // =========================

    // =========================
    // ==== MOVH MODULE ========
    wire MOVH_rs_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] MOVH_rs_uid_out;
    wire [2:0] [15:0] MOVH_rs_params_out;
    res_sta #(.PARAM_COUNT(3)) movh_res_sta
    ( .clk(clk),
        .has_in(TA_inst_type==MOVH & ROB_has_outgoing), .in_uid(ROB_out_uid), // NOTE check on that "has in" temporality
        .in_params('{{12'b0,TA_inst[`t_addr]}, {8'b0, TA_inst[`i_immd]}, TA_param_val1}), .in_writers('{1 << (`ROB_QUEUE_BITS), 1 << (`ROB_QUEUE_BITS), TA_param_writer1}), // NOTE check on the register return temporality
        .finishing_instr_queue(WB_rob_queue),
        .entire_rob(entire_rob),
        .has_out(MOVH_rs_has_outgoing), .out_uid(MOVH_rs_uid_out), .out_params(MOVH_rs_params_out)
    );
    movh movh ( .clk(clk),
        .has_incoming(MOVH_rs_has_outgoing), .in_uid(MOVH_rs_uid_out), .params(MOVH_rs_params_out),
        .has_outgoing(MOVH_has_outgoing), .out_uid(MOVH_out_uid), .result_val(MOVH_result_val), .out_loc(MOVH_out_loc)
    );

    //outputs for movh unit
    wire MOVH_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] MOVH_out_uid;
    wire [15:0] MOVH_result_val;
    wire [17:0] MOVH_out_loc;
    // ==== MOVH MODULE ========
    // =========================

    // ==============================
    // ==== BRANCHING MODULE ========
    /////Branch RES_STA + MODule
    wire branch_rs_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] branch_rs_uid_out;
    wire [2:0] [15:0] branch_rs_params_out;

    //branch stuffies
    res_sta #(.PARAM_COUNT(3)) branch_res_sta
    ( .clk(clk),
        .has_in((TA_inst_type == JZ | TA_inst_type == JNZ | TA_inst_type == JS | TA_inst_type == JNS) & ROB_has_outgoing), .in_uid(ROB_out_uid), // NOTE check on that "has in" temporality
        .in_params('{TA_param_val1, TA_param_val0, {12'b0, TA_inst[7:4]} /*should have encoding 0, 1, 2, or 3*/}), .in_writers('{TA_param_writer1, TA_param_writer0, 1 << (`ROB_QUEUE_BITS)}), // NOTE check on the register return temporality
        .finishing_instr_queue(WB_rob_queue),
        .entire_rob(entire_rob),
        .has_out(branch_rs_has_outgoing), .out_uid(branch_rs_uid_out), .out_params(branch_rs_params_out)
    );
    branch branch ( .clk(clk),
        .has_incoming(branch_rs_has_outgoing), .in_uid(branch_rs_uid_out), .params(branch_rs_params_out),
        .has_outgoing(BRANCH_has_outgoing), .out_uid(BRANCH_out_uid), .result_val(BRANCH_result_val), .out_loc(BRANCH_out_loc)
    );

    //outputs for branch unit
    wire BRANCH_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] BRANCH_out_uid;
    wire [15:0] BRANCH_result_val;
    wire [17:0] BRANCH_out_loc;
    // ==== BRANCHING MODULE ========
    // ==============================

    // ========================
    // ==== SUB MODULE ========
    wire SUB_rs_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] SUB_rs_uid_out;
    wire [2:0] [15:0] SUB_rs_params_out;

    //sub res_sta
    res_sta #(.PARAM_COUNT(3)) sub_res_sta
    ( .clk(clk),
        .has_in((TA_inst_type == SUB) & ROB_has_outgoing), .in_uid(ROB_out_uid), // NOTE check on that "has in" temporality
        .in_params('{{12'b0, TA_inst[`t_addr]}, TA_param_val0, TA_param_val1}), .in_writers('{1 << (`ROB_QUEUE_BITS), TA_param_writer0, TA_param_writer1}), // NOTE check on the register return temporality
        .finishing_instr_queue(WB_rob_queue),
        .entire_rob(entire_rob),
        .has_out(SUB_rs_has_outgoing), .out_uid(SUB_rs_uid_out), .out_params(SUB_rs_params_out)
    );
    sub sub ( .clk(clk),
        .has_incoming(SUB_rs_has_outgoing), .in_uid(SUB_rs_uid_out), .params(SUB_rs_params_out),
        .has_outgoing(SUB_has_outgoing), .out_uid(SUB_out_uid), .result_val(SUB_result_val), .out_loc(SUB_out_loc)
    );

    //outputs for sub unit
    wire SUB_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] SUB_out_uid;
    wire [15:0] SUB_result_val;
    wire [17:0] SUB_out_loc;
    // ==== SUB MODULE ========
    // ========================

    // ==========================
    // ==== LD/ST MODULE ========
    wire LDST_rs_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] LDST_rs_uid_out;
    wire [3:0] [15:0] LDST_rs_params_out;

    //ldst res_sta
    res_sta #(.PARAM_COUNT(4)) ldst_res_sta
    ( .clk(clk),
        .has_in(((TA_inst_type == LD) | (TA_inst_type == ST)) & ROB_has_outgoing), .in_uid(ROB_out_uid),
        .in_params('{{12'b0, TA_inst[`t_addr]}, TA_param_val0, TA_param_val1, {12'b0, TA_inst[7:4]}}), 
        .in_writers('{1 << (`ROB_QUEUE_BITS), TA_param_writer0, (TA_inst_type == LD)? 1 << `ROB_QUEUE_BITS : TA_param_writer1, 1 << (`ROB_QUEUE_BITS)}),

        .finishing_instr_queue(WB_rob_queue),
        .entire_rob(entire_rob),
        .has_out(LDST_rs_has_outgoing), .out_uid(LDST_rs_uid_out), .out_params(LDST_rs_params_out)
    );
    
    load_store ldst ( .clk(clk),
        .has_incoming(LDST_rs_has_outgoing), .in_uid(LDST_rs_uid_out), .params(LDST_rs_params_out),
        .has_outgoing(LDST_has_outgoing), .out_uid(LDST_out_uid), .result_val(LDST_result_val), .out_loc(LDST_out_loc),
        .out_ld_raddr(LDST_ld_raddr),
        .mem_raddr(mem_raddr), .mem_rval(mem_rval)
    );

    //outputs for ldst unit
    wire LDST_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] LDST_out_uid;
    wire [15:0] LDST_result_val;
    wire [17:0] LDST_out_loc;
    wire [15:1] mem_raddr;
    wire [15:0] mem_rval;
    wire [15:1] LDST_ld_raddr;


    wire LDST_buffer_has_outgoing;
    wire [`ROB_QUEUE_BITS-1:0] LDST_buffer_out_uid;
    wire [15:0] LDST_buffer_result_val;
    wire [17:0] LDST_buffer_out_loc;
    // ==== LD/ST MODULE ========
    // ==========================

    // ===============================
    // ==== STORE BUFFER ZONE ========
    typedef struct packed {
        bit valid;
        bit [`ROB_QUEUE_BITS-1:0] uid;
        bit [15:1] raddr;
        bit [15:0] val;
    } ld_completion_list_t;
    ld_completion_list_t maybe_done_lds [`ROB_QUEUE_SIZE];

    typedef struct packed {
        bit valid;
        bit [`ROB_QUEUE_BITS-1:0] uid; // get waddr/loc by indexing into rob
    } st_list_t;
    st_list_t st_uid_list [`ROB_QUEUE_SIZE];

    integer ld_list_tail;
    integer st_list_tail;
    bit add_to_ld_list = 1;
    integer st_list_i = 0;
    integer ld_list_i = 0;
    integer st_i_2 = 0;
    integer scoot_idx = 0;
    bit ld_really_done = 0;
    reg [`ROB_QUEUE_BITS-1:0] ld_new_uid;
    wire LD_buffer_has_outgoing = ld_really_done;

    always @(posedge clk) begin
        if ((TA_inst_type == ST) & ROB_has_outgoing) begin // add even incoming insts to list of sts
            st_uid_list[st_list_tail].uid <= ROB_out_uid;
            st_uid_list[st_list_tail].valid <= 1'b1;
            st_list_tail = st_list_tail + 1;
        end

        if (LDST_has_outgoing & (LDST_out_loc[17:16] == 0)) begin //loads that think they're finished
            add_to_ld_list = 0;
            for (st_list_i = 0; st_list_i < `ROB_QUEUE_SIZE; st_list_i++) begin // see if need to update LD list
                if (st_uid_list[st_list_i].valid
                    & !entire_rob[st_uid_list[st_list_i].uid].done // check for earlier STs that aren't done yet
                    & (st_uid_list[st_list_i].uid < LDST_out_uid)) begin
                    add_to_ld_list = 1;
                end
            end
            if (add_to_ld_list) begin
                maybe_done_lds[ld_list_tail].uid <= LDST_out_uid;
                maybe_done_lds[ld_list_tail].raddr <= LDST_ld_raddr;
                maybe_done_lds[ld_list_tail].valid <= 1'b1;
                ld_list_tail = ld_list_tail + 1;
            end
            else begin
                ld_really_done = 1'b1;
            end
        end

        if (ld_really_done) begin
            WB_rob_queue.push_back(ldst_WB_rob_entry);
        end

        //see if ld values need overwriting
        if (LDST_has_outgoing & (LDST_out_loc[16])) begin //store finishing
            for (ld_list_i = 0; ld_list_i < `ROB_QUEUE_SIZE; ld_list_i++) begin
                // VALUE FIXING CHECK HERE (LD AFTER ST FORWARDING)
                if ((maybe_done_lds[ld_list_i].raddr[15:1] == LDST_out_loc[15:1]) & //lding from st loc
                    (maybe_done_lds[ld_list_i].uid > LDST_out_uid)) begin //ld is after the st
                    maybe_done_lds[ld_list_i].val = LDST_result_val; //forward strd value
                end

                // DONENESS CHECK HERE
                if ( (maybe_done_lds[ld_list_i].uid > st_uid_list[0].uid) & // if the ld has has its temporal dependencies done
                    (maybe_done_lds[ld_list_i].uid < st_uid_list[1].uid) ) begin
                    // mark as done in rob
                    ld_really_done = 1'b1;
                    ld_new_uid = maybe_done_lds[ld_list_i].uid;


                    // remove from list, scooch everything above it down
                    maybe_done_lds[ld_list_i].valid = 1'b0;
                    for (scoot_idx = (ld_list_i); scoot_idx < (`ROB_QUEUE_SIZE-1); scoot_idx++) begin
                        maybe_done_lds[scoot_idx] = maybe_done_lds[scoot_idx+1];
                    end
                end
            end       
        end
    end
    // ==== STORE BUFFER ZONE ========
    // ===============================

    ////////////////////////////
    //yaya write enable
    wire mem_wen = mem_wen_reg;
    reg mem_wen_reg = 0;

    //data to be written, done above
    wire[15:0] w_data_wire = w_data_reg;
    reg[15:0] w_data_reg = 0;
    
    //data writen location, done above
    wire[15:1] w_loc_wire = w_loc_reg[15:1]; //this should be store address
    reg[17:0] w_loc_reg = 0;

    ///////////////////////////
    stor_mem stor_mem(
        .clk(clk),
        .raddr0_(mem_raddr),
        .rdata0_(mem_rval),
        // .raddr1_(),
        // .rdata1_(),
        .wen_(mem_wen), //has committing instr and instr is a store
        .waddr_(w_loc_wire), //should come from loc 
        .wdata_(w_data_wire)
    );

    ///////////////////////////
    regs regs (.clk(clk),
    .raddr0_(DC_param_loc0),
    .rdata0(TA_param_val0), .rwriter0(TA_param_writer0),
    .raddr1_(DC_param_loc1),
    .rdata1(TA_param_val1), .rwriter1(TA_param_writer1),
    .change_writer(TA_change_writer), .writer_waddr(TA_change_writer_addr), .new_writer(TA_change_new_writer),
    .all_reg_writes(all_reg_writes),

    .flush_all(WB_flush_all)
    );


// ==== MODULE ZONE ================================================================
// =================================================================================


// DEBUG DISPLAY WIRE TIME YIPEI
    WB_entry_t WHY = WB_rob_queue[16];
    bit WHY_finishing_instr = WHY.finishing_instr;
    bit [`ROB_QUEUE_BITS-1:0] WHY_uid = WHY.uid;
    bit [15:0] WHY_val = WHY.val;
    bit [17:0] WHY_loc = WHY.loc;

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

endmodule
