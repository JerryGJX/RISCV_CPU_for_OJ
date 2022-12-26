`ifndef macro_rob
`define macro_rob
// `define DEBUG

`include "definition.v"

module rob (
    input wire clk,
    input wire rst,
    input wire rdy,

    output wire rob_next_full,

    //false predict & rst
    //check
    output reg clr,



    //issue to rob
    input wire                 issue_to_rob_enable,
    input wire [   `ADDR_TYPE] issue_to_rob_pc,
    input wire [`REG_POS_TYPE] issue_to_rob_rd,
    input wire [ `OPENUM_TYPE] issue_to_rob_openum,
    input wire                 issue_to_rob_pred_jump,
    input wire                 issue_to_rob_ready,
    //from predictor,if jump, the flag is positive

    //commit
    output reg [`ROB_WRAP_POS_TYPE] commit_rob_pos,

    //rob to register
    output reg                 rob_to_reg_enable,
    output reg [`REG_POS_TYPE] rob_to_reg_rd,
    output reg [   `DATA_TYPE] rob_to_reg_val,

    //rob to lsb
    output reg                       rob_to_lsb_st_commit_enable,
    output wire [`ROB_WRAP_POS_TYPE] rob_to_lsb_head_rob_pos,
    //lsb to rob
    input  wire                      lsb_to_rob_ld_ready,
    input  wire [`ROB_WRAP_POS_TYPE] lsb_to_rob_ld_rob_pos,
    input  wire [        `DATA_TYPE] lsb_to_rob_ld_val,

    //rob to if
    output reg              rob_to_if_br_commit_enable,
    output reg              rob_to_if_br_real_jump,
    output reg              rob_to_if_set_pc_enable,
    output reg [`ADDR_TYPE] rob_to_if_target_pc,
    //output reg [`ADDR_TYPE] br_pc,

    //alu to rob, alu broadcast
    input wire                      alu_to_rob_result_ready,
    input wire [`ROB_WRAP_POS_TYPE] alu_to_rob_result_rob_pos,
    input wire [        `DATA_TYPE] alu_to_rob_result_val,
    input wire                      alu_to_rob_result_jump,
    input wire [        `ADDR_TYPE] alu_to_rob_result_pc,

    //decoder to rob
    input  wire [`ROB_WRAP_POS_TYPE] dc_to_rob_rs1_pos,
    input  wire [`ROB_WRAP_POS_TYPE] dc_to_rob_rs2_pos,
    output wire                      rob_to_dc_rs1_ready,
    output wire                      rob_to_dc_rs2_ready,
    output wire [        `DATA_TYPE] rob_to_dc_rs1_val,
    output wire [        `DATA_TYPE] rob_to_dc_rs2_val,
    output wire [`ROB_WRAP_POS_TYPE] rob_to_dc_next_rob_pos

    //todo

);
  reg [`ROB_SIZE-1:0 ] ready;
  reg [`REG_POS_TYPE]  rd        [`ROB_SIZE-1:0];
  reg [   `DATA_TYPE]  val       [`ROB_SIZE-1:0];
  reg [   `ADDR_TYPE]  pc        [`ROB_SIZE-1:0];
  reg [ `OPENUM_TYPE]  opEnum    [`ROB_SIZE-1:0];
  reg [`ROB_SIZE-1:0 ] pred_jump;
  reg [`ROB_SIZE-1:0 ] real_jump;
  reg [   `ADDR_TYPE]  dest_pc   [`ROB_SIZE-1:0];

  reg [`ROB_POS_TYPE] loop_head, loop_tail;  //[loop_head,loop_tail)
  reg [`NUM_TYPE] ele_num;
  reg [`NUM_TYPE] next_num;
  reg commit_enable;
  reg input_load_enable;

  wire head_is_br = opEnum[loop_head] == `OPENUM_BEQ ||
        opEnum[loop_head] == `OPENUM_BNE ||
        opEnum[loop_head] == `OPENUM_BLT ||
        opEnum[loop_head] == `OPENUM_BGE ||
        opEnum[loop_head] == `OPENUM_BLTU||
        opEnum[loop_head] == `OPENUM_BGEU;

  wire head_is_store = opEnum[loop_head] == `OPENUM_SB|| 
        opEnum[loop_head] == `OPENUM_SH|| 
        opEnum[loop_head] == `OPENUM_SW;

  wire head_is_load = opEnum[loop_head] == `OPENUM_LB||
        opEnum[loop_head] == `OPENUM_LH||
        opEnum[loop_head] == `OPENUM_LW||
        opEnum[loop_head] == `OPENUM_LBU||
        opEnum[loop_head] == `OPENUM_LHU;

  //check
  assign rob_next_full           = (next_num == `ROB_SIZE);
  //form decoder
  assign rob_to_dc_rs1_ready     = ready[dc_to_rob_rs1_pos[`ROB_POS_TYPE]];
  assign rob_to_dc_rs2_ready     = ready[dc_to_rob_rs2_pos[`ROB_POS_TYPE]];
  assign rob_to_dc_rs1_val       = val[dc_to_rob_rs1_pos[`ROB_POS_TYPE]];
  assign rob_to_dc_rs2_val       = val[dc_to_rob_rs2_pos[`ROB_POS_TYPE]];
  assign rob_to_dc_next_rob_pos  = {1'b1, loop_tail};
  assign rob_to_lsb_head_rob_pos = {1'b1, loop_head};

  //  wire [  `ADDR_TYPE] head_pc = pc[loop_head];
  //fuck
  //  wire [`OPENUM_TYPE] head_openum = opEnum[loop_head];




  always @(*) begin
    commit_enable = (!clr) && (ele_num > 0) && (ready[loop_head] == `TRUE);
    input_load_enable = (!clr) && (ele_num > 0) && head_is_load && pc[loop_head] == `IO_ADDR;
    if (rst || clr) next_num = 32'b0;
    else
      next_num = ele_num + (issue_to_rob_enable ? 32'b1 : 32'b0) - (commit_enable ? 32'b1 : 32'b0);
  end


  integer i;

  always @(posedge clk) begin
    commit_rob_pos              <= 0;
    rob_to_reg_enable           <= `FALSE;
    rob_to_lsb_st_commit_enable <= `FALSE;
    rob_to_if_br_commit_enable  <= `FALSE;
    rob_to_reg_rd               <= 0;
    rob_to_reg_val              <= 0;


    if (rst || clr) begin
      loop_head               <= 0;
      loop_tail               <= 0;
      ele_num                 <= 0;
      // rob_to_dc_next_rob_pos <= 0;
      clr                     <= 0;
      rob_to_if_set_pc_enable <= 0;
      rob_to_if_target_pc     <= 0;
      for (i = 0; i < `ROB_SIZE; i = i + 1) begin
        ready[i]     <= 0;
        rd[i]        <= 0;
        val[i]       <= 0;
        pc[i]        <= 0;
        opEnum[i]    <= 0;
        pred_jump[i] <= 0;
        //may be empty
        real_jump[i] <= 0;
        dest_pc[i]   <= 0;
      end
    end else if (!rdy) begin
      ;
    end else begin
      ele_num <= next_num;
      if (issue_to_rob_enable) begin
        ready[loop_tail]     <= issue_to_rob_ready;
        rd[loop_tail]        <= issue_to_rob_rd;
        opEnum[loop_tail]    <= issue_to_rob_openum;
        pc[loop_tail]        <= issue_to_rob_pc;
        pred_jump[loop_tail] <= issue_to_rob_pred_jump;
        loop_tail            <= loop_tail + 1;
      end

      if (lsb_to_rob_ld_ready) begin
        ready[lsb_to_rob_ld_rob_pos[`ROB_POS_TYPE]] <= `TRUE;
        val[lsb_to_rob_ld_rob_pos[`ROB_POS_TYPE]]   <= lsb_to_rob_ld_val;
      end

      if (alu_to_rob_result_ready) begin
        ready[alu_to_rob_result_rob_pos[`ROB_POS_TYPE]]     <= `TRUE;
        val[alu_to_rob_result_rob_pos[`ROB_POS_TYPE]]       <= alu_to_rob_result_val;
        real_jump[alu_to_rob_result_rob_pos[`ROB_POS_TYPE]] <= alu_to_rob_result_jump;
        dest_pc[alu_to_rob_result_rob_pos[`ROB_POS_TYPE]]   <= alu_to_rob_result_pc;
      end

      // if (input_load_enable) begin
      //   rob_to_lsb_input_ld_enable  <= `TRUE;
      //   rob_to_lsb_input_ld_rob_pos <= {1'b1, loop_head};
      // end

      if (commit_enable) begin
`ifdef DEBUG
        $fdisplay(logfile, "Commit ROB #%X (%d)", loop_head, commit_cnt);
        commit_cnt++;
        $fdisplay(logfile, "  pc:%X, rd:%X, val:%X, jump:%b, respc:%X, rollback:%b", pc[loop_head],
                  rd[loop_head], val[loop_head], real_jump[loop_head], dest_pc[loop_head],
                  pred_jump[loop_head] != real_jump[loop_head]);

        // $fdisplay(logfile, "rob_pos:%X", loop_head);
`endif

        ready[loop_head]     <= `FALSE;
        rd[loop_head]        <= 0;
        val[loop_head]       <= 0;
        pc[loop_head]        <= 0;
        opEnum[loop_head]    <= 0;
        pred_jump[loop_head] <= 0;
        real_jump[loop_head] <= 0;
        dest_pc[loop_head]   <= 0;



        commit_rob_pos       <= {1'b1, loop_head};
        if (head_is_store) begin
          rob_to_lsb_st_commit_enable <= `TRUE;


        end else if (!head_is_br) begin
          rob_to_reg_enable <= `TRUE;
          rob_to_reg_rd     <= rd[loop_head];
          rob_to_reg_val    <= val[loop_head];
        end

        if (head_is_br) begin
          rob_to_if_br_commit_enable <= `TRUE;
          rob_to_if_br_real_jump     <= real_jump[loop_head];
          if (pred_jump[loop_head] != real_jump[loop_head]) begin
            clr                     <= `TRUE;
            rob_to_if_set_pc_enable <= `TRUE;
            rob_to_if_target_pc     <= dest_pc[loop_head];
          end
        end

        if (opEnum[loop_head] == `OPENUM_JALR) begin
          if (pred_jump[loop_head] != real_jump[loop_head]) begin
            clr                     <= `TRUE;
            rob_to_if_set_pc_enable <= `TRUE;
            rob_to_if_target_pc     <= dest_pc[loop_head];
          end
        end
        loop_head <= loop_head + 1;
      end
    end
  end

`ifdef DEBUG
  integer logfile;
  integer commit_cnt;
  initial begin
    logfile = $fopen("rob.log", "w");
    commit_cnt = 0;
  end
`endif



endmodule
`endif
