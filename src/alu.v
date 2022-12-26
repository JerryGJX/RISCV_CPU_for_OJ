`ifndef macro_alu
`define macro_alu
`include "definition.v"

module ALU (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire clr,

    //from rs
    input wire                      rs_to_alu_enable,
    input wire [      `OPENUM_TYPE] rs_to_alu_openum,
    input wire [`ROB_WRAP_POS_TYPE] rs_to_alu_rob_pos,
    input wire [        `DATA_TYPE] rs_to_alu_rs1_val,
    input wire [        `DATA_TYPE] rs_to_alu_rs2_val,
    input wire [        `DATA_TYPE] rs_to_alu_imm,
    input wire [        `ADDR_TYPE] rs_to_alu_pc,

    //alu broadcast
    output reg                      alu_broadcast_enable,
    output reg [`ROB_WRAP_POS_TYPE] alu_broadcast_rob_pos,
    output reg [        `DATA_TYPE] alu_broadcast_val,
    output reg                      alu_broadcast_jump,
    output reg [        `ADDR_TYPE] alu_broadcast_pc
);

  reg [`DATA_TYPE] alu_result;
  reg jump;
  wire br_inst = (rs_to_alu_openum == `OPENUM_BEQ) || (rs_to_alu_openum == `OPENUM_BNE) || (rs_to_alu_openum == `OPENUM_BLT) || (rs_to_alu_openum == `OPENUM_BGE) || (rs_to_alu_openum == `OPENUM_BLTU) || (rs_to_alu_openum == `OPENUM_BGEU);




  always @(*) begin
    jump = `FALSE;
    alu_result = 0;
    case (rs_to_alu_openum)
      `OPENUM_ADD: alu_result = rs_to_alu_rs1_val + rs_to_alu_rs2_val;
      `OPENUM_SUB: alu_result = rs_to_alu_rs1_val - rs_to_alu_rs2_val;
      `OPENUM_XOR: alu_result = rs_to_alu_rs1_val ^ rs_to_alu_rs2_val;
      `OPENUM_OR: alu_result = rs_to_alu_rs1_val | rs_to_alu_rs2_val;
      `OPENUM_AND: alu_result = rs_to_alu_rs1_val & rs_to_alu_rs2_val;
      `OPENUM_SLL: alu_result = rs_to_alu_rs1_val << rs_to_alu_rs2_val[5:0];
      `OPENUM_SRL: alu_result = rs_to_alu_rs1_val >> rs_to_alu_rs2_val[5:0];
      `OPENUM_SRA: alu_result = (rs_to_alu_rs1_val) >>> rs_to_alu_rs2_val[5:0];  //check >>>
      `OPENUM_SLT: alu_result = ($signed(rs_to_alu_rs1_val) < $signed(rs_to_alu_rs2_val)) ? 1 : 0;
      `OPENUM_SLTU: alu_result = (rs_to_alu_rs1_val < rs_to_alu_rs2_val) ? 1 : 0;
      `OPENUM_ADDI: alu_result = rs_to_alu_rs1_val + rs_to_alu_imm;
      `OPENUM_XORI: alu_result = rs_to_alu_rs1_val ^ rs_to_alu_imm;
      `OPENUM_ORI: alu_result = rs_to_alu_rs1_val | rs_to_alu_imm;
      `OPENUM_ANDI: alu_result = rs_to_alu_rs1_val & rs_to_alu_imm;
      `OPENUM_SLLI: alu_result = rs_to_alu_rs1_val << rs_to_alu_imm[5:0];
      `OPENUM_SRLI: alu_result = rs_to_alu_rs1_val >> rs_to_alu_imm[5:0];
      `OPENUM_SRAI: alu_result = (rs_to_alu_rs1_val) >>> rs_to_alu_imm[5:0];  //check >>>
      `OPENUM_SLTI: alu_result = ($signed(rs_to_alu_rs1_val) < $signed(rs_to_alu_imm)) ? 1 : 0;
      `OPENUM_SLTIU: alu_result = (rs_to_alu_rs1_val < rs_to_alu_imm) ? 1 : 0;

      `OPENUM_BEQ: jump = (rs_to_alu_rs1_val == rs_to_alu_rs2_val) ? `TRUE : `FALSE;
      `OPENUM_BNE: jump = (rs_to_alu_rs1_val != rs_to_alu_rs2_val) ? `TRUE : `FALSE;
      `OPENUM_BLT:
      jump = ($signed(rs_to_alu_rs1_val) < $signed(rs_to_alu_rs2_val)) ? `TRUE : `FALSE;
      `OPENUM_BGE:
      jump = ($signed(rs_to_alu_rs1_val) >= $signed(rs_to_alu_rs2_val)) ? `TRUE : `FALSE;
      `OPENUM_BLTU: jump = (rs_to_alu_rs1_val < rs_to_alu_rs2_val) ? `TRUE : `FALSE;
      `OPENUM_BGEU: jump = (rs_to_alu_rs1_val >= rs_to_alu_rs2_val) ? `TRUE : `FALSE;
      default;
    endcase
  end

  always @(posedge clk) begin
    if (rst || clr) begin
      alu_broadcast_enable  <= `FALSE;
      alu_broadcast_rob_pos <= 0;
      alu_broadcast_val     <= 0;
      alu_broadcast_jump    <= `FALSE;
      alu_broadcast_pc      <= 0;
    end else if (!rdy) begin
      ;
    end else begin
      alu_broadcast_enable <= rs_to_alu_enable;
      if (rs_to_alu_enable) begin
        alu_broadcast_rob_pos <= rs_to_alu_rob_pos;
        alu_broadcast_jump    <= `FALSE;
        alu_broadcast_val     <= 0;
        alu_broadcast_pc      <= 0;
        if (br_inst) begin
          if (jump) begin
            alu_broadcast_jump <= `TRUE;
            alu_broadcast_pc   <= rs_to_alu_pc + rs_to_alu_imm;
          end else alu_broadcast_pc <= rs_to_alu_pc + 4;
        end else begin
          case (rs_to_alu_openum)
            `OPENUM_JAL: begin
              alu_broadcast_jump <= `TRUE;
              alu_broadcast_val  <= rs_to_alu_pc + 4;
              alu_broadcast_pc   <= rs_to_alu_pc + rs_to_alu_imm;
            end
            `OPENUM_JALR: begin
              alu_broadcast_jump <= `TRUE;
              alu_broadcast_val  <= rs_to_alu_pc + 4;
              alu_broadcast_pc   <= rs_to_alu_rs1_val + rs_to_alu_imm;
            end
            `OPENUM_LUI:   alu_broadcast_val <= rs_to_alu_imm;
            `OPENUM_AUIPC: alu_broadcast_val <= rs_to_alu_pc + rs_to_alu_imm;
            default: begin  //for arithmetic instructions
              alu_broadcast_val <= alu_result;
            end
          endcase
        end
      end
    end
  end

endmodule
`endif
