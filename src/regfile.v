`ifndef macro_regfile
`define macro_regfile
`include "definition.v"

module regfile (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire clr,  //由于regfile的val来自commit，所以clr时只需清空rob_pos即可

    //from issue
    input wire                      issue_to_reg_enable,
    input wire [     `REG_POS_TYPE] issue_to_reg_rd,
    input wire [`ROB_WRAP_POS_TYPE] issue_to_reg_rob_pos,

    //from rob commit
    input wire                      rob_to_reg_enable,
    input wire [     `REG_POS_TYPE] rob_to_reg_rd,
    input wire [`ROB_WRAP_POS_TYPE] rob_to_reg_rob_pos,
    input wire [        `DATA_TYPE] rob_to_reg_val,

    //to decoder
    input  wire [     `REG_POS_TYPE] dc_to_reg_rs1_reg_pos,
    output reg  [        `DATA_TYPE] reg_to_dc_rs1_val,
    output reg  [`ROB_WRAP_POS_TYPE] reg_to_dc_rs1_rob_pos,
    input  wire [     `REG_POS_TYPE] dc_to_reg_rs2_reg_pos,
    output reg  [        `DATA_TYPE] reg_to_dc_rs2_val,
    output reg  [`ROB_WRAP_POS_TYPE] reg_to_dc_rs2_rob_pos
);


  reg [`DATA_TYPE] val_store[`REG_SIZE-1:0];
  reg [`ROB_WRAP_POS_TYPE] rob_pos_store[`REG_SIZE-1:0];

  wire correct_commit = rob_to_reg_enable & (rob_to_reg_rd != 0);  //the 0th register is always 0
  wire rob_pos_match = rob_pos_store[rob_to_reg_rd] == rob_to_reg_rob_pos;


  always @(*) begin
    //get val
    if (correct_commit && dc_to_reg_rs1_reg_pos == rob_to_reg_rd && rob_pos_match) begin
      reg_to_dc_rs1_val     = rob_to_reg_val;
      reg_to_dc_rs1_rob_pos = 0;
    end else begin
      reg_to_dc_rs1_val     = val_store[dc_to_reg_rs1_reg_pos];
      reg_to_dc_rs1_rob_pos = rob_pos_store[dc_to_reg_rs1_reg_pos];
    end

    if (correct_commit && dc_to_reg_rs2_reg_pos == rob_to_reg_rd && rob_pos_match) begin
      reg_to_dc_rs2_val     = rob_to_reg_val;
      reg_to_dc_rs2_rob_pos = 0;
    end else begin
      reg_to_dc_rs2_val     = val_store[dc_to_reg_rs2_reg_pos];
      reg_to_dc_rs2_rob_pos = rob_pos_store[dc_to_reg_rs2_reg_pos];
    end
  end

  integer i;
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < `REG_SIZE; i = i + 1) begin
        val_store[i]     <= 0;
        rob_pos_store[i] <= 0;
      end
    end else if (clr) begin
      for (i = 0; i < `REG_SIZE; i = i + 1) rob_pos_store[i] <= 0;
    end else if (!rdy) begin
      ;
    end else begin
      if (correct_commit) begin

`ifdef DEBUG
        $fdisplay(logfile, "Reg @%t", $realtime);
        for (i = 0; i < 32; i += 8) begin
          $fdisplay(logfile, "%6H %6H %6H %6H %6H %6H %6H %6H", val_store[i], val_store[i+1],
                    val_store[i+2], val_store[i+3], val_store[i+4], val_store[i+5], val_store[i+6],
                    val_store[i+7]);
        end
`endif

        val_store[rob_to_reg_rd] <= rob_to_reg_val;
        if (rob_pos_match) rob_pos_store[rob_to_reg_rd] <= 0;
      end

      if (issue_to_reg_enable && issue_to_reg_rd != 0)
        rob_pos_store[issue_to_reg_rd] <= issue_to_reg_rob_pos;
    end
  end
`ifdef DEBUG
  integer logfile;
  integer commit_cnt;
  initial begin
    logfile = $fopen("reg.log", "w");
    commit_cnt = 0;
  end
`endif

endmodule
`endif
