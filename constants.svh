`ifndef CONSTANTS_H
    `define CONSTANTS_H
    `define ROB_QUEUE_SIZE 256
    `define ROB_QUEUE_BITS $clog2(`ROB_QUEUE_SIZE)
    `define MAX_FINISH_SIZE 16
    `define INST_COUNT 4


    typedef struct packed {
        bit finishing_instr;
        bit [`ROB_QUEUE_BITS - 1:0] uid;
        bit [15:0] val;
        bit [17:0] loc;
    } WB_entry_t;

    typedef struct packed {
        bit [15:0] pc;
        bit [17:0] loc; // bit 16 1 indicates a store,
                        // bit 17 1 indicates a jump,
                        // both 1s indicates we don't know (halt)
                        // both 0 means write to reg
        bit [15:0] val;
        bit done;
    } ROB_entry_t;

    typedef struct packed {
        bit [3:0] data_waddr;
        bit [15:0] new_data;
        bit [`ROB_QUEUE_BITS - 1:0] writer_uid;
    } reg_writer_t;

`endif // CONSTANTS_H
