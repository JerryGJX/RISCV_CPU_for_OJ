`ifndef macro_if
`define macro_if
`include "definition.v"

module iFetch (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rs_next_full,
    input wire lsb_next_full,
    input wire rob_next_full,


    //with mem ctrl
    output reg               if_to_mc_enable,
    output reg  [`ADDR_TYPE] if_to_mc_pc,
    input  wire              mc_to_if_done,
    input  wire [`INST_TYPE] mc_to_if_result,

    //with rob, handle pc fix
    input wire              rob_to_if_set_pc_enable,
    input wire [`ADDR_TYPE] rob_to_if_set_pc_val,
    input wire              rob_to_if_br_commit,
    input wire              rob_to_if_br_jump,


    //to decoder
    output reg                if_to_dc_enable,
    output reg [`OPENUM_TYPE] if_to_dc_openum,
    output reg [  `INST_TYPE] if_to_dc_inst_val,
    output reg [  `ADDR_TYPE] if_to_dc_pc,
    output reg                if_to_dc_pred_jump,
    output reg                if_to_dc_lsb_enable,
    output reg                if_to_dc_rs_enable
);

  parameter STATUS_IDLE = 0, STATUS_FETCH = 1;

  integer i;

  reg [`STATUS_TYPE] status;
  //pc
  reg [`ADDR_TYPE] pc;

  //direct mapping iCache
  `define ICACHE_SIZE 256
  `define INDEX_RANGE 9:2
  `define TAG_RANGE 31:10

  reg [`ICACHE_SIZE - 1:0] valid;  //bitset
  reg [`TAG_RANGE] tag_store[`ICACHE_SIZE - 1:0];

  reg [`INST_TYPE] inst_store[`ICACHE_SIZE - 1:0];

  wire hit = valid[pc[`INDEX_RANGE]] == `TRUE && (tag_store[pc[`INDEX_RANGE]] == pc[`TAG_RANGE]);

  wire [`INST_TYPE] hit_inst_val = (hit) ? inst_store[pc[`INDEX_RANGE]] : `BLANK_INST;

  //predictor
  reg [`ADDR_TYPE] pred_pc;
  reg pred_jump;

  reg [1:0] jump_record;

  //local

  // reg [`OPENUM_TYPE] local_inst_openum;

  reg local_lsb_enable;
  reg local_rs_enable;

  reg local_rs_dispatch_enable;
  reg local_lsb_dispatch_enable;
  reg local_issue_enable;


  always @(posedge clk) begin
    if (rob_to_if_br_commit) begin
      jump_record <= jump_record << 1 + rob_to_if_br_jump;
    end
  end

  always @(*) begin
    pred_pc   = pc + 4;
    pred_jump = `FALSE;

    case (hit_inst_val[`OPCODE_RANGE])
      `OPCODE_JAL: begin
        pred_pc = pc + {{12{hit_inst_val[31]}}, hit_inst_val[19:12], hit_inst_val[20], hit_inst_val[30:21], 1'b0};
        pred_jump = `TRUE;
      end
      `OPCODE_BR: begin
        if (jump_record >= 2) begin
          pred_pc = pc + {{20{hit_inst_val[31]}}, hit_inst_val[7], hit_inst_val[30:25], hit_inst_val[11:8], 1'b0};
          pred_jump = `TRUE;
        end
      end
      default;
    endcase
  end

  //decode
  always @(*) begin
    local_lsb_enable          = `FALSE;
    local_rs_enable           = `FALSE;
    local_rs_dispatch_enable  = `FALSE;
    local_lsb_dispatch_enable = `FALSE;
    local_issue_enable        = `FALSE;

    case (hit_inst_val[`OPCODE_RANGE])
      `OPCODE_RC: begin
        local_rs_enable = `TRUE;
      end
      `OPCODE_RI: begin
        local_rs_enable = `TRUE;
      end
      `OPCODE_LD: begin
        local_lsb_enable = `TRUE;
      end
      `OPCODE_ST: begin
        local_lsb_enable = `TRUE;
      end
      `OPCODE_BR: begin
        local_rs_enable = `TRUE;
      end
      `OPCODE_JAL: begin
        local_rs_enable = `TRUE;
      end
      `OPCODE_JALR: begin
        local_rs_enable = `TRUE;
      end
      `OPCODE_LUI: begin
        local_rs_enable = `TRUE;
      end
      `OPCODE_AUIPC: begin
        local_rs_enable = `TRUE;
      end
      default;
    endcase

    local_lsb_dispatch_enable = (!lsb_next_full) && local_lsb_enable;
    local_rs_dispatch_enable = (!rs_next_full) && local_rs_enable;
    local_issue_enable        = (local_lsb_dispatch_enable||local_rs_dispatch_enable)&& (!rob_next_full);
  end



  always @(posedge clk) begin
    if (rst) begin
      pc              <= `BLANK_ADDR;
      if_to_mc_pc     <= `BLANK_ADDR;
      if_to_mc_enable <= `FALSE;
      status          <= STATUS_IDLE;
      if_to_dc_enable <= `FALSE;
      if_to_dc_openum <= `OPENUM_NOP;
      valid           <= 0;
    end else if (!rdy) begin
      ;
    end else begin
      if (rob_to_if_set_pc_enable) begin
        if_to_dc_enable <= `FALSE;
        pc              <= rob_to_if_set_pc_val;
      end else begin
        if (hit && local_issue_enable) begin
          if_to_dc_enable     <= `TRUE;

          if_to_dc_inst_val   <= hit_inst_val;
          if_to_dc_lsb_enable <= local_lsb_dispatch_enable;
          if_to_dc_rs_enable  <= local_rs_dispatch_enable;
          if_to_dc_pc         <= pc;
          pc                  <= pred_pc;
          if_to_dc_pred_jump  <= pred_jump;

          case (hit_inst_val[`OPCODE_RANGE])
            `OPCODE_RC: begin
              case (hit_inst_val[`FUNC3_RANGE])
                `FUNC3_ADD_SUB: begin
                  case (hit_inst_val[`FUNC7_RANGE])
                    `FUNC7_ADD: begin
                      if_to_dc_openum <= `OPENUM_ADD;
                    end
                    `FUNC7_SUB: begin
                      if_to_dc_openum <= `OPENUM_SUB;
                    end
                    default;
                  endcase
                end
                `FUNC3_XOR: begin
                  if_to_dc_openum <= `OPENUM_XOR;
                end
                `FUNC3_OR: begin
                  if_to_dc_openum <= `OPENUM_OR;
                end
                `FUNC3_AND: begin
                  if_to_dc_openum <= `OPENUM_AND;
                end
                `FUNC3_SLL: begin
                  if_to_dc_openum <= `OPENUM_SLL;
                end
                `FUNC3_SRL_SRA: begin
                  case (hit_inst_val[`FUNC7_RANGE])
                    `FUNC7_SRL: begin
                      if_to_dc_openum <= `OPENUM_SRL;
                    end
                    `FUNC7_SRA: begin
                      if_to_dc_openum <= `OPENUM_SRA;
                    end
                    default;
                  endcase
                end
                `FUNC3_SLT: begin
                  if_to_dc_openum <= `OPENUM_SLT;
                end
                `FUNC3_SLTU: begin
                  if_to_dc_openum <= `OPENUM_SLTU;
                end
                default;
              endcase
            end
            `OPCODE_RI: begin
              case (hit_inst_val[`FUNC3_RANGE])
                `FUNC3_ADDI: begin
                  if_to_dc_openum <= `OPENUM_ADDI;
                end
                `FUNC3_XORI: begin
                  if_to_dc_openum <= `OPENUM_XORI;
                end
                `FUNC3_ORI: begin
                  if_to_dc_openum <= `OPENUM_ORI;
                end
                `FUNC3_ANDI: begin
                  if_to_dc_openum <= `OPENUM_ANDI;
                end
                `FUNC3_SLLI: begin
                  if_to_dc_openum <= `OPENUM_SLLI;
                end
                `FUNC3_SRLI_SRAI: begin
                  case (hit_inst_val[`FUNC7_RANGE])
                    `FUNC7_SRLI: begin
                      if_to_dc_openum <= `OPENUM_SRLI;
                    end
                    `FUNC7_SRAI: begin
                      if_to_dc_openum <= `OPENUM_SRAI;
                    end
                    default;
                  endcase
                end
                `FUNC3_SLTI: begin
                  if_to_dc_openum <= `OPENUM_SLTI;
                end
                `FUNC3_SLTIU: begin
                  if_to_dc_openum <= `OPENUM_SLTIU;
                end
                default;
              endcase
            end
            `OPCODE_LD: begin
              case (hit_inst_val[`FUNC3_RANGE])
                `FUNC3_LB: begin
                  if_to_dc_openum <= `OPENUM_LB;
                end
                `FUNC3_LH: begin
                  if_to_dc_openum <= `OPENUM_LH;
                end
                `FUNC3_LW: begin
                  if_to_dc_openum <= `OPENUM_LW;
                end
                `FUNC3_LBU: begin
                  if_to_dc_openum <= `OPENUM_LBU;
                end
                `FUNC3_LHU: begin
                  if_to_dc_openum <= `OPENUM_LHU;
                end
                default;
              endcase
            end
            `OPCODE_ST: begin
              case (hit_inst_val[`FUNC3_RANGE])
                `FUNC3_SB: begin
                  if_to_dc_openum <= `OPENUM_SB;
                end
                `FUNC3_SH: begin
                  if_to_dc_openum <= `OPENUM_SH;
                end
                `FUNC3_SW: begin
                  if_to_dc_openum <= `OPENUM_SW;
                end
                default;
              endcase
            end
            `OPCODE_BR: begin
              case (hit_inst_val[`FUNC3_RANGE])
                `FUNC3_BEQ: begin
                  if_to_dc_openum <= `OPENUM_BEQ;
                end
                `FUNC3_BNE: begin
                  if_to_dc_openum <= `OPENUM_BNE;
                end
                `FUNC3_BLT: begin
                  if_to_dc_openum <= `OPENUM_BLT;
                end
                `FUNC3_BGE: begin
                  if_to_dc_openum <= `OPENUM_BGE;
                end
                `FUNC3_BLTU: begin
                  if_to_dc_openum <= `OPENUM_BLTU;
                end
                `FUNC3_BGEU: begin
                  if_to_dc_openum <= `OPENUM_BGEU;
                end
                default;
              endcase
            end
            `OPCODE_JAL: begin
              if_to_dc_openum <= `OPENUM_JAL;
            end
            `OPCODE_JALR: begin
              if_to_dc_openum <= `OPENUM_JALR;
            end
            `OPCODE_LUI: begin
              if_to_dc_openum <= `OPENUM_LUI;
            end
            `OPCODE_AUIPC: begin
              if_to_dc_openum <= `OPENUM_AUIPC;
            end
            default;
          endcase

        end else begin
          if_to_dc_enable <= `FALSE;
          if_to_dc_openum <= `OPENUM_NOP;
          if_to_dc_inst_val <= `BLANK_INST;
          if_to_dc_lsb_enable <= 0;
          if_to_dc_rs_enable <= 0;
        end
      end

      if (status == STATUS_IDLE) begin
        if (!hit) begin
          if_to_mc_pc     <= pc;
          if_to_mc_enable <= `TRUE;
          status          <= STATUS_FETCH;
        end
      end else begin
        if (mc_to_if_done) begin
          valid[if_to_mc_pc[`INDEX_RANGE]]      <= `TRUE;
          tag_store[if_to_mc_pc[`INDEX_RANGE]]  <= if_to_mc_pc[`TAG_RANGE];
          inst_store[if_to_mc_pc[`INDEX_RANGE]] <= mc_to_if_result;
          if_to_mc_enable                       <= `FALSE;
          status                                <= STATUS_IDLE;
        end
      end
    end
  end


endmodule

`endif
