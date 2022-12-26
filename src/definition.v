`ifndef macro_definition
`define macro_definition

//wire status
`define TRUE 1'b1
`define FALSE 1'b0
`define MEM_READ 1'b0
`define MEM_WRITE 1'b1


//element type
`define INST_TYPE 31:0
`define ADDR_TYPE 31:0
//`define IMM_TYPE 31:0//for imm
`define DATA_TYPE 31:0//for data
`define NUM_TYPE 31:0

`define STATUS_TYPE 1:0


//position type
`define REG_POS_TYPE 4:0//for rs1,rs2,rd
`define ROB_POS_TYPE 4:0
`define ROB_WRAP_POS_TYPE 5:0
`define RS_POS_TYPE 3:0
`define LSB_POS_TYPE 3:0


//inst_range
`define FUNC7_RANGE 31:25
`define RS2_RANGE 24:20
`define RS1_RANGE 19:15
`define FUNC3_RANGE 14:12
`define RD_RANGE 11:7
`define OPCODE_RANGE 6:0

//size of element
`define ROB_SIZE 32'd32
`define RS_SIZE 32'd16
`define REG_SIZE 32'd32
`define LSB_SIZE 32'd16

//for lsb
`define LS_TYPE 2:0
`define BYTE_TYPE 3'b100
`define HALF_TYPE 3'b101
`define WORD_TYPE 3'b111


//default value
`define BLANK_INST 32'd0
`define BLANK_ADDR 32'd0
`define PC_DEFALT_STEP 32'd4

`define IO_ADDR 32'h30000

//opcode
`define OPCODE_TYPE 6:0
`define OPCODE_RC 7'b0110011
`define OPCODE_RI 7'b0010011
`define OPCODE_LD 7'b0000011
`define OPCODE_ST 7'b0100011
`define OPCODE_BR 7'b1100011
`define OPCODE_JALR 7'b1100111
`define OPCODE_JAL 7'b1101111
`define OPCODE_LUI 7'b0110111
`define OPCODE_AUIPC 7'b0010111

//func3
`define FUNC3_TYPE 2:0
`define FUNC3_ADD_SUB 3'h0
`define FUNC3_XOR 3'h4
`define FUNC3_OR 3'h6
`define FUNC3_AND 3'h7
`define FUNC3_SLL 3'h1
`define FUNC3_SRL_SRA 3'h5
`define FUNC3_SLT 3'h2
`define FUNC3_SLTU 3'h3

`define FUNC3_ADDI 3'h0
`define FUNC3_XORI 3'h4
`define FUNC3_ORI 3'h6
`define FUNC3_ANDI 3'h7
`define FUNC3_SLLI 3'h1
`define FUNC3_SRLI_SRAI 3'h5
`define FUNC3_ 3'h5
`define FUNC3_SLTI 3'h2
`define FUNC3_SLTIU 3'h3

`define FUNC3_LB 3'h0
`define FUNC3_LH 3'h1
`define FUNC3_LW 3'h2
`define FUNC3_LBU 3'h4
`define FUNC3_LHU 3'h5

`define FUNC3_SB 3'h0
`define FUNC3_SH 3'h1
`define FUNC3_SW 3'h2

`define FUNC3_BEQ 3'h0
`define FUNC3_BNE 3'h1
`define FUNC3_BLT 3'h4
`define FUNC3_BGE 3'h5
`define FUNC3_BLTU 3'h6
`define FUNC3_BGEU 3'h7

//func7
`define FUNC7_TYPE 6:0
`define FUNC7_ADD 7'h0
`define FUNC7_SUB 7'h20
`define FUNC7_XOR 7'h0
`define FUNC7_OR 7'h0
`define FUNC7_AND 7'h0
`define FUNC7_SLL 7'h0
`define FUNC7_SRL 7'h0
`define FUNC7_SRA 7'h20
`define FUNC7_SLT 7'h0
`define FUNC7_SLTU 7'h0

`define FUNC7_SRLI 7'h0
`define FUNC7_SRAI 7'h20



`define OPENUM_TYPE 5:0
//opEnum
`define OPENUM_NOP 6'd0
`define OPENUM_ADD 6'd1
`define OPENUM_SUB 6'd2
`define OPENUM_XOR 6'd3
`define OPENUM_OR 6'd4
`define OPENUM_AND 6'd5
`define OPENUM_SLL 6'd6
`define OPENUM_SRL 6'd7
`define OPENUM_SRA 6'd8
`define OPENUM_SLT 6'd9
`define OPENUM_SLTU 6'd10
//imm[5:11]
`define OPENUM_ADDI 6'd11
`define OPENUM_XORI 6'd12
`define OPENUM_ORI 6'd13
`define OPENUM_ANDI 6'd14
`define OPENUM_SLLI 6'd15
`define OPENUM_SRLI 6'd16
`define OPENUM_SRAI 6'd17
`define OPENUM_SLTI 6'd18
`define OPENUM_SLTIU 6'd19
//load
`define OPENUM_LB 6'd20
`define OPENUM_LH 6'd21
`define OPENUM_LW 6'd22
`define OPENUM_LBU 6'd23
`define OPENUM_LHU 6'd24
//store
`define OPENUM_SB 6'd25
`define OPENUM_SH 6'd26
`define OPENUM_SW 6'd27
//branch
`define OPENUM_BEQ 6'd28
`define OPENUM_BNE 6'd29
`define OPENUM_BLT 6'd30
`define OPENUM_BGE 6'd31
`define OPENUM_BLTU 6'd32
`define OPENUM_BGEU 6'd33
//jump
`define OPENUM_JAL 6'd34
`define OPENUM_JALR 6'd35
//system
`define OPENUM_LUI 6'd36
`define OPENUM_AUIPC 6'd37

//`define OPENUM_ECALL 6'd35




`endif


