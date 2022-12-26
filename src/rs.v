`ifndef macro_rs
`define macro_rs
`include "definition.v"

module RS (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire clr,

    //from issue
    input wire issue_to_rs_enable,
    input wire [`OPENUM_TYPE] issue_to_rs_openum,
    input wire [`ROB_WRAP_POS_TYPE] issue_to_rs_rob_pos,
    input wire [`DATA_TYPE] issue_to_rs_rs1_val,
    input wire [`ROB_WRAP_POS_TYPE] issue_to_rs_rs1_rob_pos,
    input wire [`DATA_TYPE] issue_to_rs_rs2_val,
    input wire [`ROB_WRAP_POS_TYPE] issue_to_rs_rs2_rob_pos,
    input wire [`DATA_TYPE] issue_to_rs_imm,
    input wire [`ADDR_TYPE] issue_to_rs_pc,

    //with ALU
    input wire                      alu_to_rs_result_ready,
    input wire [`ROB_WRAP_POS_TYPE] alu_to_rs_result_rob_pos,
    input wire [        `DATA_TYPE] alu_to_rs_result_val,

    output reg                      rs_to_alu_enable,
    output reg [      `OPENUM_TYPE] rs_to_alu_openum,
    output reg [`ROB_WRAP_POS_TYPE] rs_to_alu_rob_pos,
    output reg [        `DATA_TYPE] rs_to_alu_rs1_val,
    output reg [        `DATA_TYPE] rs_to_alu_rs2_val,
    output reg [        `DATA_TYPE] rs_to_alu_imm,
    output reg [        `ADDR_TYPE] rs_to_alu_pc,

    //with LSB
    input wire                      lsb_load_result_ready,
    input wire [`ROB_WRAP_POS_TYPE] lsb_load_result_rob_pos,
    input wire [        `DATA_TYPE] lsb_load_result_val,

    //RS broadcast
    output reg rs_next_full

);

  reg busy[`RS_SIZE - 1:0];
  reg [`OPENUM_TYPE] openum[`RS_SIZE - 1:0];
  reg [`ROB_WRAP_POS_TYPE] rob_pos[`RS_SIZE - 1:0];
  reg [`DATA_TYPE] rs1_val[`RS_SIZE - 1:0];
  reg [`ROB_WRAP_POS_TYPE] rs1_rob_pos[`RS_SIZE - 1:0];
  reg [`DATA_TYPE] rs2_val[`RS_SIZE - 1:0];
  reg [`ROB_WRAP_POS_TYPE] rs2_rob_pos[`RS_SIZE - 1:0];
  reg [`DATA_TYPE] imm[`RS_SIZE - 1:0];
  reg [`ADDR_TYPE] pc[`RS_SIZE - 1:0];
  reg ready[`RS_SIZE - 1:0];




  wire busy4 = busy[0];
  wire [`OPENUM_TYPE] openum4 = openum[0];
  wire [`ROB_WRAP_POS_TYPE] rob_pos4 = rob_pos[0];
  wire [`DATA_TYPE] rs1_val4 = rs1_val[0];
  wire [`ROB_WRAP_POS_TYPE] rs1_rob_pos4 = rs1_rob_pos[0];
  wire [`DATA_TYPE] rs2_val4 = rs2_val[0];
  wire [`ROB_WRAP_POS_TYPE] rs2_rob_pos4 = rs2_rob_pos[0];
  wire [`DATA_TYPE] imm4 = imm[0];
  wire [`ADDR_TYPE] pc4 = pc[0];
  wire ready4 = ready[0];





  reg [`NUM_TYPE] busy_num;  //31:0
  reg [`NUM_TYPE] max_ready_rs_pos;
  reg [`NUM_TYPE] min_free_rs_pos;

  reg [`NUM_TYPE] next_busy_num;
  //31:0

  integer i;
  `define FLAG_POS 32'd16

  always @(*) begin
    max_ready_rs_pos = `FLAG_POS;
    min_free_rs_pos  = `FLAG_POS;
    //check
    for (i = 0; i < `RS_SIZE; i = i + 1) begin
      if (busy[i] && rs1_rob_pos[i] == 0 && rs2_rob_pos[i] == 0) ready[i] = `TRUE;
      else ready[i] = `FALSE;
    end
    for (i = 0; i < `RS_SIZE; i = i + 1) begin
      if (busy[i] == `FALSE && min_free_rs_pos == `FLAG_POS) min_free_rs_pos = i;
      if (ready[i] == `TRUE) max_ready_rs_pos = i;
    end

    if (rst || clr) next_busy_num = 32'b0;
    else
      next_busy_num = busy_num + (issue_to_rs_enable ? 32'b1 : 32'b0) - (max_ready_rs_pos != `FLAG_POS ? 32'b1 : 32'b0);

    rs_next_full = (next_busy_num == `RS_SIZE);
  end

  always @(posedge clk) begin
    if (rst || clr) begin
      busy_num <= 32'b0;
      for (i = 0; i < `RS_SIZE; i = i + 1) begin
        busy[i] <= `FALSE;
      end
      rs_to_alu_enable <= `FALSE;
    end else if (!rdy) begin
      ;
    end else begin
      rs_to_alu_enable <= `FALSE;
      busy_num <= next_busy_num;
      if (max_ready_rs_pos != `FLAG_POS) begin
        rs_to_alu_enable       <= `TRUE;
        rs_to_alu_openum       <= openum[max_ready_rs_pos];
        rs_to_alu_rob_pos      <= rob_pos[max_ready_rs_pos];
        rs_to_alu_rs1_val      <= rs1_val[max_ready_rs_pos];
        rs_to_alu_rs2_val      <= rs2_val[max_ready_rs_pos];
        rs_to_alu_imm          <= imm[max_ready_rs_pos];
        rs_to_alu_pc           <= pc[max_ready_rs_pos];
        busy[max_ready_rs_pos] <= `FALSE;
      end

      if (alu_to_rs_result_ready) begin
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
          if (rs1_rob_pos[i] != 0 && rs1_rob_pos[i] == alu_to_rs_result_rob_pos) begin
            rs1_val[i]     <= alu_to_rs_result_val;
            rs1_rob_pos[i] <= 0;
          end
          if (rs2_rob_pos[i] != 0 && rs2_rob_pos[i] == alu_to_rs_result_rob_pos) begin
            rs2_val[i]     <= alu_to_rs_result_val;
            rs2_rob_pos[i] <= 0;
          end
        end
      end

      if (lsb_load_result_ready) begin
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
          if (rs1_rob_pos[i] != 0 && rs1_rob_pos[i] == lsb_load_result_rob_pos) begin
            rs1_val[i]     <= lsb_load_result_val;
            rs1_rob_pos[i] <= 0;
          end
          if (rs2_rob_pos[i] != 0 && rs2_rob_pos[i] == lsb_load_result_rob_pos) begin
            rs2_val[i]     <= lsb_load_result_val;
            rs2_rob_pos[i] <= 0;
          end
        end
      end

      if (issue_to_rs_enable) begin
        busy[min_free_rs_pos]        <= `TRUE;
        openum[min_free_rs_pos]      <= issue_to_rs_openum;
        rob_pos[min_free_rs_pos]     <= issue_to_rs_rob_pos;
        rs1_val[min_free_rs_pos]     <= issue_to_rs_rs1_val;
        rs1_rob_pos[min_free_rs_pos] <= issue_to_rs_rs1_rob_pos;
        rs2_val[min_free_rs_pos]     <= issue_to_rs_rs2_val;
        rs2_rob_pos[min_free_rs_pos] <= issue_to_rs_rs2_rob_pos;
        imm[min_free_rs_pos]         <= issue_to_rs_imm;
        pc[min_free_rs_pos]          <= issue_to_rs_pc;
      end
    end
  end

endmodule
`endif