`ifndef macro_decoder
`define macro_decoder 

`include "definition.v"

module decoder (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clr,


    //from ifetch
    input wire                if_to_dc_enable,
    input wire [  `INST_TYPE] if_to_dc_inst_val,
    input wire [`OPENUM_TYPE] if_to_dc_openum,
    input wire [  `ADDR_TYPE] if_to_dc_pc,
    input wire                if_to_dc_pred_jump,
    input wire                if_to_dc_lsb_enable,
    input wire                if_to_dc_rs_enable,


    //issue
    output reg                      issue_enable,
    //controlled by ifetch
    output reg [      `OPENUM_TYPE] issue_openum,
    output reg [     `REG_POS_TYPE] issue_rd,
    output reg [        `DATA_TYPE] issue_rs1_val,
    output reg [`ROB_WRAP_POS_TYPE] issue_rs1_rob_pos,
    output reg [        `DATA_TYPE] issue_rs2_val,
    output reg [`ROB_WRAP_POS_TYPE] issue_rs2_rob_pos,
    output reg [        `DATA_TYPE] issue_imm,
    output reg [        `ADDR_TYPE] issue_pc,
    output reg                      issue_pred_jump,
    output reg                      issue_ready_inst,
    //for load
    output reg [`ROB_WRAP_POS_TYPE] issue_rob_pos,

    //with regfile
    output wire [     `REG_POS_TYPE] dc_to_reg_rs1_reg_pos,
    output wire [     `REG_POS_TYPE] dc_to_reg_rs2_reg_pos,
    input  wire [        `DATA_TYPE] reg_to_dc_rs1_val,
    input  wire [`ROB_WRAP_POS_TYPE] reg_to_dc_rs1_rob_pos,
    input  wire [        `DATA_TYPE] reg_to_dc_rs2_val,
    input  wire [`ROB_WRAP_POS_TYPE] reg_to_dc_rs2_rob_pos,

    //with rob
    output wire [`ROB_WRAP_POS_TYPE] dc_to_rob_rs1_pos,
    input  wire                      rob_to_dc_rs1_ready,
    input  wire [        `DATA_TYPE] rob_to_dc_rs1_val,
    output wire [`ROB_WRAP_POS_TYPE] dc_to_rob_rs2_pos,
    input  wire                      rob_to_dc_rs2_ready,
    input  wire [        `DATA_TYPE] rob_to_dc_rs2_val,
    input  wire [`ROB_WRAP_POS_TYPE] rob_to_dc_next_rob_pos,

    //with alu
    input wire                      alu_result_ready,
    input wire [`ROB_WRAP_POS_TYPE] alu_result_rob_pos,
    input wire [        `DATA_TYPE] alu_result_val,

    //with lsb
    input wire                      lsb_load_result_ready,    //this will be true 
    input wire [`ROB_WRAP_POS_TYPE] lsb_load_result_rob_pos,
    input wire [        `DATA_TYPE] lsb_load_result_val,

    //out control
    output reg rs_enable,
    output reg lsb_enable
);

  assign dc_to_reg_rs1_reg_pos = if_to_dc_inst_val[`RS1_RANGE];
  assign dc_to_reg_rs2_reg_pos = if_to_dc_inst_val[`RS2_RANGE];
  assign dc_to_rob_rs1_pos = reg_to_dc_rs1_rob_pos;
  assign dc_to_rob_rs2_pos = reg_to_dc_rs2_rob_pos;

  always @(*) begin
    issue_enable      = `FALSE;
    issue_openum      = if_to_dc_openum;
    issue_rd          = if_to_dc_inst_val[`RD_RANGE];
    issue_rs1_val     = 0;
    issue_rs2_val     = 0;
    issue_rs1_rob_pos = 0;
    issue_rs2_rob_pos = 0;
    issue_imm         = 0;
    issue_pc          = if_to_dc_pc;
    issue_pred_jump   = if_to_dc_pred_jump;
    issue_ready_inst  = `FALSE;
    issue_rob_pos     = rob_to_dc_next_rob_pos;
    rs_enable         = `FALSE;
    lsb_enable        = `FALSE;

    if (rst || !if_to_dc_enable || clr) begin
      issue_enable = `FALSE;
    end else if (!rdy) begin
      ;
    end else begin
      issue_enable = `TRUE;
      rs_enable    = if_to_dc_rs_enable;
      lsb_enable   = if_to_dc_lsb_enable;
      if (reg_to_dc_rs1_rob_pos == 0) begin
        issue_rs1_val = reg_to_dc_rs1_val;
      end else if (rob_to_dc_rs1_ready) begin
        issue_rs1_val = rob_to_dc_rs1_val;
      end else if (alu_result_ready && alu_result_rob_pos == reg_to_dc_rs1_rob_pos) begin
        issue_rs1_val = alu_result_val;
      end else if (lsb_load_result_ready && lsb_load_result_rob_pos == reg_to_dc_rs1_rob_pos) begin
        issue_rs1_val = lsb_load_result_val;
      end else begin
        issue_rs1_val = 0;
        issue_rs1_rob_pos = reg_to_dc_rs1_rob_pos;
      end

      // issue_rs2_rob_pos = 0;
      if (reg_to_dc_rs2_rob_pos == 0) begin
        issue_rs2_val = reg_to_dc_rs2_val;
      end else if (rob_to_dc_rs2_ready) begin
        issue_rs2_val = rob_to_dc_rs2_val;
      end else if (alu_result_ready && alu_result_rob_pos == reg_to_dc_rs2_rob_pos) begin
        issue_rs2_val = alu_result_val;
      end else if (lsb_load_result_ready && lsb_load_result_rob_pos == reg_to_dc_rs2_rob_pos) begin
        issue_rs2_val = lsb_load_result_val;
      end else begin
        issue_rs2_val = 0;
        issue_rs2_rob_pos = reg_to_dc_rs2_rob_pos;
      end

      case (if_to_dc_inst_val[`OPCODE_RANGE])

        `OPCODE_RC: begin
        end

        `OPCODE_RI: begin
          issue_rs2_rob_pos = 0;
          issue_rs2_val = 0;
          issue_imm = {{21{if_to_dc_inst_val[31]}}, if_to_dc_inst_val[30:20]};

        end

        `OPCODE_LD: begin
          issue_rs2_rob_pos = 0;
          issue_rs2_val = 0;
          issue_imm = {{21{if_to_dc_inst_val[31]}}, if_to_dc_inst_val[30:20]};
        end

        `OPCODE_ST: begin
          issue_rd = 0;
          issue_ready_inst = `TRUE;
          issue_imm = {
            {21{if_to_dc_inst_val[31]}}, if_to_dc_inst_val[30:25], if_to_dc_inst_val[11:7]
          };
        end

        `OPCODE_BR: begin
          issue_rd = 0;
          issue_imm = {
            {20{if_to_dc_inst_val[31]}},
            if_to_dc_inst_val[7],
            if_to_dc_inst_val[30:25],
            if_to_dc_inst_val[11:8],
            1'b0
          };
        end

        `OPCODE_JAL: begin
          issue_rs1_rob_pos = 0;
          issue_rs1_val = 0;
          issue_rs2_rob_pos = 0;
          issue_rs2_val = 0;
          issue_imm = {
            {12{if_to_dc_inst_val[31]}},
            if_to_dc_inst_val[19:12],
            if_to_dc_inst_val[20],
            if_to_dc_inst_val[30:21],
            1'b0
          };
        end

        `OPCODE_JALR: begin
          issue_rs2_rob_pos = 0;
          issue_rs2_val = 0;
          issue_imm = {{21{if_to_dc_inst_val[31]}}, if_to_dc_inst_val[30:20]};
        end

        `OPCODE_LUI: begin
          issue_rs1_rob_pos = 0;
          issue_rs1_val = 0;
          issue_rs2_rob_pos = 0;
          issue_rs2_val = 0;
          issue_imm = {if_to_dc_inst_val[31:12], 12'b0};
        end

        `OPCODE_AUIPC: begin
          issue_rs1_rob_pos = 0;
          issue_rs1_val = 0;
          issue_rs2_rob_pos = 0;
          issue_rs2_val = 0;
          issue_imm = {if_to_dc_inst_val[31:12], 12'b0};
        end
        default;
      endcase
    end
  end




endmodule
`endif
