`ifndef macro_lsb
`define macro_lsb

// `define DEBUG

`include "definition.v"

module lsb (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clr,

    //from issue
    input wire                      issue_to_lsb_enable,
    input wire [      `OPENUM_TYPE] issue_to_lsb_openum,
    input wire [`ROB_WRAP_POS_TYPE] issue_to_lsb_rob_pos,
    input wire [        `DATA_TYPE] issue_to_lsb_rs1_val,
    input wire [`ROB_WRAP_POS_TYPE] issue_to_lsb_rs1_rob_pos,
    input wire [        `DATA_TYPE] issue_to_lsb_rs2_val,
    input wire [`ROB_WRAP_POS_TYPE] issue_to_lsb_rs2_rob_pos,
    input wire [        `DATA_TYPE] issue_to_lsb_imm,

    //with memCtrl
    input  wire              mc_to_lsb_st_done,
    input  wire              mc_to_lsb_ld_done,
    input  wire [`DATA_TYPE] mc_to_lsb_ld_val,
    output reg               lsb_to_mc_enable,
    output reg               lsb_to_mc_wr,
    output reg  [  `LS_TYPE] lsb_to_mc_ls_type,
    output reg  [`ADDR_TYPE] lsb_to_mc_addr,
    output reg  [`DATA_TYPE] lsb_to_mc_st_val,

    //with rob
    input wire                      rob_to_lsb_st_commit,
    input wire [`ROB_WRAP_POS_TYPE] rob_to_lsb_st_rob_pos,
    input wire [`ROB_WRAP_POS_TYPE] rob_to_lsb_head_rob_pos,

    //lsb broadcast
    output wire                      lsb_broadcast_next_full,
    output reg                       lsb_broadcast_ld_done,
    // output reg                       lsb_broadcast_st_done,
    output reg  [`ROB_WRAP_POS_TYPE] lsb_broadcast_ld_rob_pos,
    output reg  [        `DATA_TYPE] lsb_broadcast_ld_val,

    //receive ALU broadcast
    input wire                      alu_result_ready,
    input wire [`ROB_WRAP_POS_TYPE] alu_result_rob_pos,
    input wire [        `DATA_TYPE] alu_result_val,

    //receive LSB broadcast
    input wire                      lsb_load_result_ready,
    input wire [`ROB_WRAP_POS_TYPE] lsb_load_result_rob_pos,
    input wire [        `DATA_TYPE] lsb_load_result_val

);


  reg [   `LSB_SIZE - 1:0 ] busy;
  reg [      `OPENUM_TYPE]  openum     [`LSB_SIZE - 1:0];
  reg [`ROB_WRAP_POS_TYPE]  rob_pos    [`LSB_SIZE - 1:0];
  reg [        `DATA_TYPE]  rs1_val    [`LSB_SIZE - 1:0];
  reg [`ROB_WRAP_POS_TYPE]  rs1_rob_pos[`LSB_SIZE - 1:0];
  reg [        `DATA_TYPE]  rs2_val    [`LSB_SIZE - 1:0];
  reg [`ROB_WRAP_POS_TYPE]  rs2_rob_pos[`LSB_SIZE - 1:0];
  reg [        `DATA_TYPE]  imm        [`LSB_SIZE - 1:0];
  reg [   `LSB_SIZE - 1:0 ] commit;

  parameter STATUS_IDLE = 0, STATUS_WAIT = 1;

  reg [`LSB_POS_TYPE] loop_head;
  reg [`LSB_POS_TYPE] loop_tail;
  reg [    `NUM_TYPE] ele_num;
  reg [    `NUM_TYPE] next_ele_num;
  reg [    `NUM_TYPE] commit_ele_num;
  reg [    `NUM_TYPE] next_commit_ele_num;

  reg [ `STATUS_TYPE] head_status;

  assign lsb_broadcast_next_full = (next_ele_num == `LSB_SIZE);


  wire [`ADDR_TYPE] head_addr = rs1_val[loop_head] + imm[loop_head];
  wire head_is_io = head_addr[17:16] == 2'b11;
  wire head_load_type = (openum[loop_head] == `OPENUM_LB) || (openum[loop_head] == `OPENUM_LH) || (openum[loop_head] == `OPENUM_LW) || (openum[loop_head] == `OPENUM_LBU) || (openum[loop_head] == `OPENUM_LHU);
  wire head_pop = (head_status == STATUS_WAIT) && (mc_to_lsb_st_done || mc_to_lsb_ld_done);
  wire head_excutable = ele_num != 0 && rs1_rob_pos[loop_head] == 0 && rs2_rob_pos[loop_head] == 0 && ((head_load_type && !clr && (!head_is_io || rob_pos[loop_head] == rob_to_lsb_head_rob_pos))|| commit[loop_head]);

  always @(*) begin
    if (rst) begin
      next_ele_num = 0;
      next_commit_ele_num = 0;
    end else if (clr) begin
      next_ele_num = commit_ele_num - (head_pop ? 32'd1 : 32'd0);
      next_commit_ele_num = commit_ele_num - (head_pop && mc_to_lsb_st_done ? 32'd1 : 32'd0);
    end else begin
      next_ele_num = ele_num - (head_pop ? 32'd1 : 32'd0) + (issue_to_lsb_enable ? 32'd1 : 32'd0);
      next_commit_ele_num = commit_ele_num - (head_pop && mc_to_lsb_st_done ? 32'd1 : 32'd0) + (rob_to_lsb_st_commit ? 32'd1 : 32'd0);
    end
  end


  integer i;

  always @(posedge clk) begin

    if (rst || (clr && commit_ele_num == 0)) begin
      ele_num           <= 0;
      commit_ele_num    <= 0;
      loop_head         <= 0;
      loop_tail         <= 0;
      head_status       <= STATUS_IDLE;

      lsb_to_mc_enable  <= 0;
      lsb_to_mc_wr      <= `MEM_READ;
      lsb_to_mc_ls_type <= `BYTE_TYPE;
      lsb_to_mc_addr    <= 0;
      lsb_to_mc_st_val  <= 0;
      for (i = 0; i < `LSB_SIZE; i = i + 1) begin
        busy[i]        <= `FALSE;
        openum[i]      <= `OPENUM_NOP;
        rob_pos[i]     <= 0;
        rs1_val[i]     <= 0;
        rs1_rob_pos[i] <= 0;
        rs2_val[i]     <= 0;
        rs2_rob_pos[i] <= 0;
        imm[i]         <= 0;
        commit[i]      <= `FALSE;
      end
    end else if (!rdy) begin
      ;
    end else if (clr) begin
      loop_tail <= loop_head + commit_ele_num[`LSB_POS_TYPE];
      for (i = 0; i < `LSB_SIZE; i = i + 1) begin
        if (!commit[i]) begin
          busy[i]        <= `FALSE;
          openum[i]      <= `OPENUM_NOP;
          rob_pos[i]     <= 0;
          rs1_val[i]     <= 0;
          rs1_rob_pos[i] <= 0;
          rs2_val[i]     <= 0;
          rs2_rob_pos[i] <= 0;
          imm[i]         <= 0;
          commit[i]      <= `FALSE;
        end
      end
      if (head_status == STATUS_WAIT && (mc_to_lsb_st_done||mc_to_lsb_ld_done)) begin  //there will not be a committed load at head pos
        lsb_to_mc_enable  <= 0;
        lsb_to_mc_wr      <= `MEM_READ;
        lsb_to_mc_ls_type <= `BYTE_TYPE;
        lsb_to_mc_addr    <= 0;
        lsb_to_mc_st_val  <= 0;

        busy[loop_head]   <= `FALSE;
        commit[loop_head] <= `FALSE;
        head_status       <= STATUS_IDLE;
        if (mc_to_lsb_st_done) begin
          loop_head        <= loop_head + 1;
          ele_num          <= commit_ele_num - 1;
          commit_ele_num   <= commit_ele_num - 1;
          lsb_to_mc_enable <= `FALSE;

        end else begin
          ele_num        <= 0;
          commit_ele_num <= 0;
          loop_head      <= 0;
          loop_tail      <= 0;
          head_status    <= STATUS_IDLE;
        end
      end else begin
        ele_num        <= commit_ele_num;
        commit_ele_num <= commit_ele_num;
      end


    end else begin
      lsb_broadcast_ld_done    <= `FALSE;
      lsb_broadcast_ld_rob_pos <= 0;
      lsb_broadcast_ld_val     <= 0;
      commit_ele_num           <= next_commit_ele_num;

      if (head_status == STATUS_WAIT) begin
        if (mc_to_lsb_ld_done || mc_to_lsb_st_done) begin

          lsb_to_mc_enable  <= 0;
          lsb_to_mc_wr      <= `MEM_READ;
          lsb_to_mc_ls_type <= `BYTE_TYPE;
          lsb_to_mc_addr    <= 0;
          lsb_to_mc_st_val  <= 0;

          busy[loop_head]   <= `FALSE;
          commit[loop_head] <= `FALSE;
          lsb_to_mc_enable  <= `FALSE;
          lsb_to_mc_addr    <= 0;
          lsb_to_mc_st_val  <= 0;
          loop_head         <= loop_head + 1;
          ele_num           <= next_ele_num;
          head_status       <= STATUS_IDLE;

          if (head_load_type) begin
            lsb_broadcast_ld_done    <= `TRUE;
            lsb_broadcast_ld_rob_pos <= rob_pos[loop_head];
            case (openum[loop_head])
              `OPENUM_LB:
              lsb_broadcast_ld_val <= {{24{mc_to_lsb_ld_val[7]}}, mc_to_lsb_ld_val[7:0]};
              `OPENUM_LBU: lsb_broadcast_ld_val <= {24'b0, mc_to_lsb_ld_val[7:0]};
              `OPENUM_LH:
              lsb_broadcast_ld_val <= {{16{mc_to_lsb_ld_val[15]}}, mc_to_lsb_ld_val[15:0]};
              `OPENUM_LHU: lsb_broadcast_ld_val <= {16'b0, mc_to_lsb_ld_val[15:0]};
              `OPENUM_LW: lsb_broadcast_ld_val <= mc_to_lsb_ld_val;
              default;
            endcase
          end
        end
      end else begin
        lsb_to_mc_enable  <= 0;
        lsb_to_mc_wr      <= `MEM_READ;
        lsb_to_mc_ls_type <= `BYTE_TYPE;
        lsb_to_mc_addr    <= 0;
        lsb_to_mc_st_val  <= 0;
        if (head_excutable) begin
`ifdef DEBUG
          $fdisplay(logfile, "will Exec %s", head_load_type ? "L" : "S");
          $fdisplay(logfile, "  addr:%X, w:%X, rob_pos:%X", head_addr, rs2_val[loop_head],
                    (rob_pos[loop_head][`ROB_POS_TYPE]));
`endif

          lsb_to_mc_enable <= `TRUE;
          lsb_to_mc_addr   <= head_addr;
          case (openum[loop_head])
            `OPENUM_SB, `OPENUM_LB, `OPENUM_LBU: lsb_to_mc_ls_type <= `BYTE_TYPE;
            `OPENUM_SH, `OPENUM_LH, `OPENUM_LHU: lsb_to_mc_ls_type <= `HALF_TYPE;
            `OPENUM_SW, `OPENUM_LW:              lsb_to_mc_ls_type <= `WORD_TYPE;
            default;
          endcase

          if (head_load_type) lsb_to_mc_wr <= `MEM_READ;
          else begin
            lsb_to_mc_wr <= `MEM_WRITE;
            lsb_to_mc_st_val <= rs2_val[loop_head];
          end

          head_status <= STATUS_WAIT;
        end
      end

      if (issue_to_lsb_enable) begin
        busy[loop_tail]        <= `TRUE;
        openum[loop_tail]      <= issue_to_lsb_openum;
        rob_pos[loop_tail]     <= issue_to_lsb_rob_pos;
        rs1_val[loop_tail]     <= issue_to_lsb_rs1_val;
        rs1_rob_pos[loop_tail] <= issue_to_lsb_rs1_rob_pos;
        rs2_val[loop_tail]     <= issue_to_lsb_rs2_val;
        rs2_rob_pos[loop_tail] <= issue_to_lsb_rs2_rob_pos;
        imm[loop_tail]         <= issue_to_lsb_imm;
        commit[loop_tail]      <= `FALSE;
        loop_tail              <= loop_tail + 1;
        ele_num                <= next_ele_num;

      end



      if (rob_to_lsb_st_commit) begin
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
          if (busy[i] && rob_pos[i] == rob_to_lsb_st_rob_pos && commit[i] == `FALSE) begin
            commit[i] <= `TRUE;
          end
        end
      end

      //deal with broadcast
      if (alu_result_ready) begin
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
          if (busy[i] && rs1_rob_pos[i] == alu_result_rob_pos) begin
            rs1_val[i] <= alu_result_val;
            rs1_rob_pos[i] <= 0;
          end
          if (busy[i] && rs2_rob_pos[i] == alu_result_rob_pos) begin
            rs2_val[i] <= alu_result_val;
            rs2_rob_pos[i] <= 0;
          end
        end
      end

      if (lsb_load_result_ready) begin
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
          if (busy[i] && rs1_rob_pos[i] == lsb_load_result_rob_pos) begin
            rs1_val[i] <= lsb_load_result_val;
            rs1_rob_pos[i] <= 0;
          end
          if (busy[i] && rs2_rob_pos[i] == lsb_load_result_rob_pos) begin
            rs2_val[i] <= lsb_load_result_val;
            rs2_rob_pos[i] <= 0;
          end
        end
      end
    end
  end



`ifdef DEBUG
  integer logfile;
  initial begin
    logfile = $fopen("lsb.log", "w");
  end
`endif



endmodule
`endif
