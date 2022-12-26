// RISCV32I CPU top module
// port modification allowed for debugging purposes


`include "definition.v"


`include "memCtrl.v"
`include "if.v"
`include "lsb.v"
`include "decoder.v"
`include "rs.v"
`include "alu.v"
`include "rob.v"
`include "regfile.v"


module cpu (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    output wire [31:0] dbgreg_dout  // cpu register output (debugging demo)
);

  // implementation goes here

  // Specifications:
  // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
  // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
  // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
  // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
  // - 0x30000 read: read a byte from input
  // - 0x30000 write: write a byte to output (write 0x00 is ignored)
  // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
  // - 0x30004 write: indicates program stop (will output '\0' through uart tx)


  //rob clr
  wire                      clr;

  //CDB
  //alu broadcast
  wire                      alu_result_ready;
  wire [`ROB_WRAP_POS_TYPE] alu_result_rob_pos;
  wire [        `DATA_TYPE] alu_result_val;
  wire                      alu_result_jump;
  wire [        `ADDR_TYPE] alu_result_pc;
  //lsb broadcast
  wire                      lsb_load_result_ready;
  wire [`ROB_WRAP_POS_TYPE] lsb_load_result_rob_pos;
  wire [        `DATA_TYPE] lsb_load_result_val;
  //full broadcast
  wire                      lsb_next_full;
  wire                      rob_next_full;
  wire                      rs_next_full;


  //---------------------memCtrl---------------------

  //mem to memCtrl : given
  //if with memCtrl
  wire                      mc_with_if_enable;
  wire [        `ADDR_TYPE] mc_with_if_pc;
  wire                      mc_with_if_done;
  wire [        `INST_TYPE] mc_with_if_result;

  //lsb with memCtrl
  wire                      mc_with_lsb_enable;
  wire                      mc_with_lsb_wr;
  wire [        `ADDR_TYPE] mc_with_lsb_addr;
  wire [          `LS_TYPE] mc_with_lsb_ls_type;
  wire [        `DATA_TYPE] mc_with_lsb_st_val;
  wire                      mc_with_lsb_st_done;
  wire                      mc_with_lsb_ld_done;
  wire [        `DATA_TYPE] mc_with_lsb_ld_val;


  memCtrl u_memCtrl (
      .clk              (clk_in),
      .rst              (rst_in),
      .rdy              (rdy_in),
      .clr              (clr),
      .mem_to_mc_din    (mem_din),
      .mc_to_mem_dout   (mem_dout),
      .mc_to_mem_addr   (mem_a),
      .mc_to_mem_wr     (mem_wr),
      .io_buffer_full   (io_buffer_full),
      .if_to_mc_enable  (mc_with_if_enable),
      .if_to_mc_pc      (mc_with_if_pc),
      .mc_to_if_done    (mc_with_if_done),
      .mc_to_if_result  (mc_with_if_result),
      .lsb_to_mc_enable (mc_with_lsb_enable),
      .lsb_to_mc_wr     (mc_with_lsb_wr),
      .lsb_to_mc_addr   (mc_with_lsb_addr),
      .lsb_to_mc_ls_type(mc_with_lsb_ls_type),
      .lsb_to_mc_st_val (mc_with_lsb_st_val),
      .mc_to_lsb_st_done(mc_with_lsb_st_done),
      .mc_to_lsb_ld_done(mc_with_lsb_ld_done),
      .mc_to_lsb_ld_val (mc_with_lsb_ld_val)
  );


  //---------------------iFetch---------------------
  //if with rob
  wire                if_with_rob_set_pc_enable;
  wire [  `ADDR_TYPE] if_with_rob_set_pc_val;
  wire                if_with_rob_br_commit;
  wire                if_with_rob_br_jump;

  //if with decoder
  wire                if_with_dc_enable;
  wire [`OPENUM_TYPE] if_with_dc_openum;
  wire [  `INST_TYPE] if_with_dc_inst_val;
  wire [  `ADDR_TYPE] if_with_dc_pc;
  wire                if_with_dc_pred_jump;
  wire                if_with_dc_lsb_enable;
  wire                if_with_dc_rs_enable;

  iFetch u_iFetch (
      .clk                    (clk_in),
      .rst                    (rst_in),
      .rdy                    (rdy_in),
      .rs_next_full           (rs_next_full),
      .lsb_next_full          (lsb_next_full),
      .rob_next_full          (rob_next_full),
      .if_to_mc_enable        (mc_with_if_enable),
      .if_to_mc_pc            (mc_with_if_pc),
      .mc_to_if_done          (mc_with_if_done),
      .mc_to_if_result        (mc_with_if_result),
      .rob_to_if_set_pc_enable(if_with_rob_set_pc_enable),
      .rob_to_if_set_pc_val   (if_with_rob_set_pc_val),
      .rob_to_if_br_commit    (if_with_rob_br_commit),
      .rob_to_if_br_jump      (if_with_rob_br_jump),
      .if_to_dc_enable        (if_with_dc_enable),
      .if_to_dc_openum        (if_with_dc_openum),
      .if_to_dc_inst_val      (if_with_dc_inst_val),
      .if_to_dc_pc            (if_with_dc_pc),
      .if_to_dc_pred_jump     (if_with_dc_pred_jump),
      .if_to_dc_lsb_enable    (if_with_dc_lsb_enable),
      .if_to_dc_rs_enable     (if_with_dc_rs_enable)
  );


  //---------------------decoder---------------------

  //decoder issue
  wire                      issue_enable;
  wire [      `OPENUM_TYPE] issue_openum;
  wire [     `REG_POS_TYPE] issue_rd;
  wire [        `DATA_TYPE] issue_rs1_val;
  wire [`ROB_WRAP_POS_TYPE] issue_rs1_rob_pos;
  wire [        `DATA_TYPE] issue_rs2_val;
  wire [`ROB_WRAP_POS_TYPE] issue_rs2_rob_pos;
  wire [        `DATA_TYPE] issue_imm;
  wire [        `ADDR_TYPE] issue_pc;
  wire                      issue_pred_jump;
  wire                      issue_ready_inst;
  wire [`ROB_WRAP_POS_TYPE] issue_rob_pos;

  //decoder with regfile
  wire [     `REG_POS_TYPE] dc_with_reg_rs1_reg_pos;
  wire [     `REG_POS_TYPE] dc_with_reg_rs2_reg_pos;
  wire [        `DATA_TYPE] dc_with_reg_rs1_val;
  wire [`ROB_WRAP_POS_TYPE] dc_with_reg_rs1_rob_pos;
  wire [        `DATA_TYPE] dc_with_reg_rs2_val;
  wire [`ROB_WRAP_POS_TYPE] dc_with_reg_rs2_rob_pos;

  //dc with rob(not issue)
  wire [`ROB_WRAP_POS_TYPE] dc_with_rob_rs1_pos;
  wire                      dc_with_rob_rs1_ready;
  wire [        `DATA_TYPE] dc_with_rob_rs1_val;
  wire [`ROB_WRAP_POS_TYPE] dc_with_rob_rs2_pos;
  wire                      dc_with_rob_rs2_ready;
  wire [        `DATA_TYPE] dc_with_rob_rs2_val;
  wire [`ROB_WRAP_POS_TYPE] dc_with_rob_next_rob_pos;

  //dc with alu (by broadcast)
  //dc with lsb (by broadcast)
  //dc out control
  wire                      dc_with_rs_enable;
  wire                      dc_with_lsb_enable;

  decoder u_decoder (
      .clk                    (clk_in),
      .rst                    (rst_in),
      .rdy                    (rdy_in),
      .clr                    (clr),
      .if_to_dc_enable        (if_with_dc_enable),
      .if_to_dc_inst_val      (if_with_dc_inst_val),
      .if_to_dc_openum        (if_with_dc_openum),
      .if_to_dc_pc            (if_with_dc_pc),
      .if_to_dc_pred_jump     (if_with_dc_pred_jump),
      .if_to_dc_lsb_enable    (if_with_dc_lsb_enable),
      .if_to_dc_rs_enable     (if_with_dc_rs_enable),
      .issue_enable           (issue_enable),
      .issue_openum           (issue_openum),
      .issue_rd               (issue_rd),
      .issue_rs1_val          (issue_rs1_val),
      .issue_rs1_rob_pos      (issue_rs1_rob_pos),
      .issue_rs2_val          (issue_rs2_val),
      .issue_rs2_rob_pos      (issue_rs2_rob_pos),
      .issue_imm              (issue_imm),
      .issue_pc               (issue_pc),
      .issue_pred_jump        (issue_pred_jump),
      .issue_ready_inst       (issue_ready_inst),
      .issue_rob_pos          (issue_rob_pos),
      .dc_to_reg_rs1_reg_pos  (dc_with_reg_rs1_reg_pos),
      .dc_to_reg_rs2_reg_pos  (dc_with_reg_rs2_reg_pos),
      .reg_to_dc_rs1_val      (dc_with_reg_rs1_val),
      .reg_to_dc_rs1_rob_pos  (dc_with_reg_rs1_rob_pos),
      .reg_to_dc_rs2_val      (dc_with_reg_rs2_val),
      .reg_to_dc_rs2_rob_pos  (dc_with_reg_rs2_rob_pos),
      .dc_to_rob_rs1_pos      (dc_with_rob_rs1_pos),
      .rob_to_dc_rs1_ready    (dc_with_rob_rs1_ready),
      .rob_to_dc_rs1_val      (dc_with_rob_rs1_val),
      .dc_to_rob_rs2_pos      (dc_with_rob_rs2_pos),
      .rob_to_dc_rs2_ready    (dc_with_rob_rs2_ready),
      .rob_to_dc_rs2_val      (dc_with_rob_rs2_val),
      .rob_to_dc_next_rob_pos (dc_with_rob_next_rob_pos),
      .alu_result_ready       (alu_result_ready),
      .alu_result_rob_pos     (alu_result_rob_pos),
      .alu_result_val         (alu_result_val),
      .lsb_load_result_ready  (lsb_load_result_ready),
      .lsb_load_result_rob_pos(lsb_load_result_rob_pos),
      .lsb_load_result_val    (lsb_load_result_val),
      .rs_enable              (dc_with_rs_enable),
      .lsb_enable             (dc_with_lsb_enable)
  );

  //---------------------regfile---------------------
  //issue to regfile 
  //regfile with rob
  wire [`ROB_WRAP_POS_TYPE] rob_commit_rob_pos;

  wire                      rob_commit_enable;
  wire [     `REG_POS_TYPE] reg_with_rob_rd;
  wire [        `DATA_TYPE] reg_with_rob_val;

  regfile u_regfile (
      .clk                  (clk_in),
      .rst                  (rst_in),
      .rdy                  (rdy_in),
      .clr                  (clr),
      .issue_to_reg_enable  (issue_enable),
      .issue_to_reg_rd      (issue_rd),
      .issue_to_reg_rob_pos (issue_rob_pos),
      .rob_to_reg_enable    (rob_commit_enable),
      .rob_to_reg_rd        (reg_with_rob_rd),
      .rob_to_reg_rob_pos   (rob_commit_rob_pos),
      .rob_to_reg_val       (reg_with_rob_val),
      .dc_to_reg_rs1_reg_pos(dc_with_reg_rs1_reg_pos),
      .reg_to_dc_rs1_val    (dc_with_reg_rs1_val),
      .reg_to_dc_rs1_rob_pos(dc_with_reg_rs1_rob_pos),
      .dc_to_reg_rs2_reg_pos(dc_with_reg_rs2_reg_pos),
      .reg_to_dc_rs2_val    (dc_with_reg_rs2_val),
      .reg_to_dc_rs2_rob_pos(dc_with_reg_rs2_rob_pos)
  );


  //---------------------rs---------------------
  //rs with alu
  wire                      rs_with_alu_enable;
  wire [      `OPENUM_TYPE] rs_with_alu_openum;
  wire [`ROB_WRAP_POS_TYPE] rs_with_alu_rob_pos;
  wire [        `DATA_TYPE] rs_with_alu_rs1_val;
  wire [        `DATA_TYPE] rs_with_alu_rs2_val;
  wire [        `DATA_TYPE] rs_with_alu_imm;
  wire [        `ADDR_TYPE] rs_with_alu_pc;

  RS u_RS (
      .clk                     (clk_in),
      .rst                     (rst_in),
      .rdy                     (rdy_in),
      .clr                     (clr),
      .issue_to_rs_enable      (dc_with_rs_enable),
      .issue_to_rs_openum      (issue_openum),
      .issue_to_rs_rob_pos     (issue_rob_pos),
      .issue_to_rs_rs1_val     (issue_rs1_val),
      .issue_to_rs_rs1_rob_pos (issue_rs1_rob_pos),
      .issue_to_rs_rs2_val     (issue_rs2_val),
      .issue_to_rs_rs2_rob_pos (issue_rs2_rob_pos),
      .issue_to_rs_imm         (issue_imm),
      .issue_to_rs_pc          (issue_pc),
      .alu_to_rs_result_ready  (alu_result_ready),
      .alu_to_rs_result_rob_pos(alu_result_rob_pos),
      .alu_to_rs_result_val    (alu_result_val),
      .rs_to_alu_enable        (rs_with_alu_enable),
      .rs_to_alu_openum        (rs_with_alu_openum),
      .rs_to_alu_rob_pos       (rs_with_alu_rob_pos),
      .rs_to_alu_rs1_val       (rs_with_alu_rs1_val),
      .rs_to_alu_rs2_val       (rs_with_alu_rs2_val),
      .rs_to_alu_imm           (rs_with_alu_imm),
      .rs_to_alu_pc            (rs_with_alu_pc),
      .lsb_load_result_ready   (lsb_load_result_ready),
      .lsb_load_result_rob_pos (lsb_load_result_rob_pos),
      .lsb_load_result_val     (lsb_load_result_val),
      .rs_next_full            (rs_next_full)
  );

  //---------------------alu---------------------
  ALU u_ALU (
      .clk                  (clk_in),
      .rst                  (rst_in),
      .rdy                  (rdy_in),
      .clr                  (clr),
      .rs_to_alu_enable     (rs_with_alu_enable),
      .rs_to_alu_openum     (rs_with_alu_openum),
      .rs_to_alu_rob_pos    (rs_with_alu_rob_pos),
      .rs_to_alu_rs1_val    (rs_with_alu_rs1_val),
      .rs_to_alu_rs2_val    (rs_with_alu_rs2_val),
      .rs_to_alu_imm        (rs_with_alu_imm),
      .rs_to_alu_pc         (rs_with_alu_pc),
      .alu_broadcast_enable (alu_result_ready),
      .alu_broadcast_rob_pos(alu_result_rob_pos),
      .alu_broadcast_val    (alu_result_val),
      .alu_broadcast_jump   (alu_result_jump),
      .alu_broadcast_pc     (alu_result_pc)
  );

  //---------------------lsb---------------------
  //lsb with rob
  wire                      lsb_with_rob_st_commit;
  wire [`ROB_WRAP_POS_TYPE] lsb_with_rob_st_rob_pos;
  wire [`ROB_WRAP_POS_TYPE] lsb_with_rob_head_rob_pos;

  lsb u_lsb (
      .clk                     (clk_in),
      .rst                     (rst_in),
      .rdy                     (rdy_in),
      .clr                     (clr),
      .issue_to_lsb_enable     (dc_with_lsb_enable),
      .issue_to_lsb_openum     (issue_openum),
      .issue_to_lsb_rob_pos    (issue_rob_pos),
      .issue_to_lsb_rs1_val    (issue_rs1_val),
      .issue_to_lsb_rs1_rob_pos(issue_rs1_rob_pos),
      .issue_to_lsb_rs2_val    (issue_rs2_val),
      .issue_to_lsb_rs2_rob_pos(issue_rs2_rob_pos),
      .issue_to_lsb_imm        (issue_imm),
      .mc_to_lsb_st_done       (mc_with_lsb_st_done),
      .mc_to_lsb_ld_done       (mc_with_lsb_ld_done),
      .mc_to_lsb_ld_val        (mc_with_lsb_ld_val),
      .lsb_to_mc_enable        (mc_with_lsb_enable),
      .lsb_to_mc_wr            (mc_with_lsb_wr),
      .lsb_to_mc_ls_type       (mc_with_lsb_ls_type),
      .lsb_to_mc_addr          (mc_with_lsb_addr),
      .lsb_to_mc_st_val        (mc_with_lsb_st_val),
      .rob_to_lsb_st_commit    (lsb_with_rob_st_commit),
      .rob_to_lsb_st_rob_pos   (rob_commit_rob_pos),
      .rob_to_lsb_head_rob_pos (lsb_with_rob_head_rob_pos),
      .lsb_broadcast_next_full (lsb_next_full),
      .lsb_broadcast_ld_done   (lsb_load_result_ready),
      .lsb_broadcast_ld_rob_pos(lsb_load_result_rob_pos),
      .lsb_broadcast_ld_val    (lsb_load_result_val),
      .alu_result_ready        (alu_result_ready),
      .alu_result_rob_pos      (alu_result_rob_pos),
      .alu_result_val          (alu_result_val),
      .lsb_load_result_ready   (lsb_load_result_ready),
      .lsb_load_result_rob_pos (lsb_load_result_rob_pos),
      .lsb_load_result_val     (lsb_load_result_val)
  );


  //---------------------rob---------------------

  rob u_rob (
      .clk                        (clk_in),
      .rst                        (rst_in),
      .rdy                        (rdy_in),
      .rob_next_full              (rob_next_full),
      .clr                        (clr),
      .issue_to_rob_enable        (issue_enable),
      .issue_to_rob_pc            (issue_pc),
      .issue_to_rob_rd            (issue_rd),
      .issue_to_rob_openum        (issue_openum),
      .issue_to_rob_pred_jump     (issue_pred_jump),
      .issue_to_rob_ready         (issue_ready_inst),
      .commit_rob_pos             (rob_commit_rob_pos),
      .rob_to_reg_enable          (rob_commit_enable),
      .rob_to_reg_rd              (reg_with_rob_rd),
      .rob_to_reg_val             (reg_with_rob_val),
      .rob_to_lsb_st_commit_enable(lsb_with_rob_st_commit),
      .rob_to_lsb_head_rob_pos    (lsb_with_rob_head_rob_pos),
      .lsb_to_rob_ld_ready        (lsb_load_result_ready),
      .lsb_to_rob_ld_rob_pos      (lsb_load_result_rob_pos),
      .lsb_to_rob_ld_val          (lsb_load_result_val),
      .rob_to_if_br_commit_enable (if_with_rob_br_commit),
      .rob_to_if_br_real_jump     (if_with_rob_br_jump),
      .rob_to_if_set_pc_enable    (if_with_rob_set_pc_enable),
      .rob_to_if_target_pc        (if_with_rob_set_pc_val),
      .alu_to_rob_result_ready    (alu_result_ready),
      .alu_to_rob_result_rob_pos  (alu_result_rob_pos),
      .alu_to_rob_result_val      (alu_result_val),
      .alu_to_rob_result_jump     (alu_result_jump),
      .alu_to_rob_result_pc       (alu_result_pc),
      .dc_to_rob_rs1_pos          (dc_with_rob_rs1_pos),
      .dc_to_rob_rs2_pos          (dc_with_rob_rs2_pos),
      .rob_to_dc_rs1_ready        (dc_with_rob_rs1_ready),
      .rob_to_dc_rs2_ready        (dc_with_rob_rs2_ready),
      .rob_to_dc_rs1_val          (dc_with_rob_rs1_val),
      .rob_to_dc_rs2_val          (dc_with_rob_rs2_val),
      .rob_to_dc_next_rob_pos     (dc_with_rob_next_rob_pos)
  );

endmodule
