`ifndef macro_memCtrl
`define macro_memCtrl
`include "definition.v"
module memCtrl (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire clr,

    input  wire [ 7:0] mem_to_mc_din,   // data input bus
    output reg  [ 7:0] mc_to_mem_dout,  // data output bus
    output reg  [31:0] mc_to_mem_addr,  // address bus (only 17:0 is used)
    output reg         mc_to_mem_wr,    // write/read signal (1 for write)
    input  wire        io_buffer_full,
    // 1 if uart buffer is full

    //with IF
    input  wire              if_to_mc_enable,
    input  wire [`ADDR_TYPE] if_to_mc_pc,
    output reg               mc_to_if_done,
    output reg  [`DATA_TYPE] mc_to_if_result,

    //with lsb
    input  wire              lsb_to_mc_enable,
    input  wire              lsb_to_mc_wr,
    input  wire [`ADDR_TYPE] lsb_to_mc_addr,
    input  wire [  `LS_TYPE] lsb_to_mc_ls_type,
    input  wire [`DATA_TYPE] lsb_to_mc_st_val,
    output reg               mc_to_lsb_ld_done,
    output reg               mc_to_lsb_st_done,
    output reg  [`DATA_TYPE] mc_to_lsb_ld_val

);

  localparam IDLE = 3'b000,GEP = 3'b001,
WAIT_FOR_FIRST_BYTE = 3'b100,//for load, get the first byte; for store, put the first byte to the buffer
  WAIT_FOR_SECOND_BYTE = 3'b101, WAIT_FOR_THIRD_BYTE = 3'b110, WAIT_FOR_FOURTH_BYTE = 3'b111;

  reg last_lsb = `FALSE;
  reg [2:0] ls_step;  //0:idle, 1:wait for first byte and so on
  wire [2:0] ls_last_step = lsb_to_mc_ls_type;  //use ls type to secure the matching of the last step
  reg [2:0] if_step;
  wire [2:0] if_last_step = WAIT_FOR_FOURTH_BYTE;
  reg [`DATA_TYPE] mem_result;

  wire io_allow = lsb_to_mc_wr == `MEM_READ || lsb_to_mc_addr[17:16] != 2'b11 || !io_buffer_full;
  wire chose_if = (if_to_mc_enable && !lsb_to_mc_enable)||(if_to_mc_enable && lsb_to_mc_enable && (last_lsb || !io_allow));
  wire chose_ls = ((!if_to_mc_enable && lsb_to_mc_enable)||(if_to_mc_enable && lsb_to_mc_enable && !last_lsb));

  wire executable = (ls_step == IDLE && if_step == IDLE) && rdy && !rst && !clr && (chose_if||chose_ls);

  wire ls_in_run = (ls_step != IDLE && ls_step != GEP);
  wire if_in_run = (if_step != IDLE && if_step != GEP);


  always @(*) begin
    mc_to_mem_dout = 8'b0;
    mc_to_mem_addr = 32'b0;
    mc_to_mem_wr   = `MEM_READ;
    // mc_to_if_result  = 32'b0;
    // mc_to_lsb_ld_val = 32'b0;


    if (executable) begin
      // mem_result = 32'b0;
      if (chose_if) begin
        mc_to_mem_addr = if_to_mc_pc;
        mc_to_mem_wr   = `MEM_READ;
      end else if (chose_ls) begin
        if (lsb_to_mc_wr == `MEM_READ || lsb_to_mc_addr[17:16] != 2'b11 || !io_buffer_full) begin
          mc_to_mem_addr = lsb_to_mc_addr;
          mc_to_mem_wr   = lsb_to_mc_wr;
          if (mc_to_mem_wr == `MEM_WRITE) begin
            mc_to_mem_dout = lsb_to_mc_st_val[7:0];
          end
        end else begin
          mc_to_mem_addr = 0;
          mc_to_mem_wr   = `MEM_READ;
        end
      end
    end else if (if_step == GEP || ls_step == GEP) begin
      mc_to_mem_wr   = `MEM_READ;
      mc_to_mem_addr = 0;
    end else begin
      if (ls_in_run && if_step == IDLE) begin
        mc_to_mem_wr   = lsb_to_mc_wr;
        mc_to_mem_addr = lsb_to_mc_addr + {{30{1'b0}}, ls_step[1:0]} + 1;
        if (lsb_to_mc_wr == `MEM_READ) begin  //load
          if (ls_step == ls_last_step) begin
            mc_to_mem_wr   = `MEM_READ;
            mc_to_mem_addr = 0;
          end
        end else begin  //store
          if (ls_step == ls_last_step || (lsb_to_mc_addr[17:16] == 2'b11 && io_buffer_full)) begin
            mc_to_mem_wr   = `MEM_READ;
            mc_to_mem_addr = 0;
          end else begin
            case (ls_step)
              WAIT_FOR_FIRST_BYTE: mc_to_mem_dout = lsb_to_mc_st_val[15:8];
              WAIT_FOR_SECOND_BYTE: mc_to_mem_dout = lsb_to_mc_st_val[23:16];
              WAIT_FOR_THIRD_BYTE: mc_to_mem_dout = lsb_to_mc_st_val[31:24];
              WAIT_FOR_FOURTH_BYTE: ;
              default: ;
            endcase
          end
        end
      end else if (ls_step == IDLE && if_in_run) begin
        mc_to_mem_wr   = `MEM_READ;
        mc_to_mem_addr = if_to_mc_pc + {{30{1'b0}}, if_step[1:0]} + 1;
      end else begin
        mc_to_mem_wr   = `MEM_READ;
        mc_to_mem_addr = 0;
      end
    end
  end


  always @(posedge clk) begin
    if (rst) begin
      if_step           <= IDLE;
      ls_step           <= IDLE;
      // mc_to_mem_wr      <= `MEM_READ;
      //   mc_to_mem_addr <= 0;
      mc_to_lsb_ld_done <= `FALSE;
      mc_to_lsb_st_done <= `FALSE;
      mc_to_if_done     <= `FALSE;
      mc_to_if_result   <= 0;
      mc_to_lsb_ld_val  <= 0;
      mem_result        <= 0;
    end else if (!rdy) begin
      if_step <= IDLE;
      ls_step <= IDLE;
      // mc_to_mem_wr <= `MEM_READ;
      //   mc_to_mem_addr <= 0;
    end else begin
      // mc_to_mem_wr      <= 0;
      mc_to_if_done     <= `FALSE;
      mc_to_if_result   <= 0;
      mc_to_lsb_ld_done <= `FALSE;
      mc_to_lsb_st_done <= `FALSE;
      mc_to_lsb_ld_val  <= 0;

      if (if_step == IDLE && ls_step == IDLE) begin  //mem idle
        if (!clr) begin
          if (chose_if) begin
            if_step  <= WAIT_FOR_FIRST_BYTE;
            last_lsb <= `FALSE;
          end else if (chose_ls) begin
            if (lsb_to_mc_wr == `MEM_READ || lsb_to_mc_addr[17:16] != 2'b11 || !io_buffer_full)begin
              ls_step  <= WAIT_FOR_FIRST_BYTE;
              last_lsb <= `TRUE;
            end

          end
        end
      end else if (if_step == GEP) begin
        if_step <= IDLE;
      end else if (ls_step == GEP) begin
        ls_step <= IDLE;
      end else begin
        if (if_in_run && ls_step == IDLE) begin
          // mc_to_mem_wr <= `MEM_READ;  //important
          if (if_step != if_last_step) begin
            case (if_step)
              WAIT_FOR_FIRST_BYTE: begin
                if_step <= WAIT_FOR_SECOND_BYTE;
                mem_result[7:0] <= mem_to_mc_din;
              end
              WAIT_FOR_SECOND_BYTE: begin
                if_step <= WAIT_FOR_THIRD_BYTE;
                mem_result[15:8] <= mem_to_mc_din;
              end
              WAIT_FOR_THIRD_BYTE: begin
                if_step <= WAIT_FOR_FOURTH_BYTE;
                mem_result[23:16] <= mem_to_mc_din;
              end
              WAIT_FOR_FOURTH_BYTE: begin
                if_step <= GEP;
                mem_result[31:24] <= mem_to_mc_din;
              end
              default: ;
            endcase
          end else begin
            if_step         <= GEP;
            mc_to_if_result <= {mem_to_mc_din, mem_result[23:0]};
            mem_result      <= 0;
            mc_to_if_done   <= `TRUE;
          end
        end else if (if_step == IDLE && ls_in_run) begin
          if (clr && lsb_to_mc_wr == `MEM_READ) begin
            ls_step <= IDLE;
            mem_result <= 0;
          end else begin
            // mc_to_mem_wr <= lsb_to_mc_wr;
            if (ls_step != ls_last_step) begin
              if (lsb_to_mc_wr == `MEM_READ || lsb_to_mc_addr[17:16] != 2'b11 || !io_buffer_full) begin
                case (ls_step)
                  WAIT_FOR_FIRST_BYTE: ls_step <= WAIT_FOR_SECOND_BYTE;
                  WAIT_FOR_SECOND_BYTE: ls_step <= WAIT_FOR_THIRD_BYTE;
                  WAIT_FOR_THIRD_BYTE: ls_step <= WAIT_FOR_FOURTH_BYTE;
                  WAIT_FOR_FOURTH_BYTE: ls_step <= GEP;
                  default: ;
                endcase
              end
              if (lsb_to_mc_wr == `MEM_READ) begin
                case (ls_step)
                  WAIT_FOR_FIRST_BYTE: mem_result[7:0] <= mem_to_mc_din;
                  WAIT_FOR_SECOND_BYTE: mem_result[15:8] <= mem_to_mc_din;
                  WAIT_FOR_THIRD_BYTE: mem_result[23:16] <= mem_to_mc_din;
                  WAIT_FOR_FOURTH_BYTE: mem_result <= {mem_to_mc_din, mem_result[23:0]};
                  default: ;
                endcase
              end
            end else begin  //last step
              ls_step <= GEP;
              if (lsb_to_mc_wr == `MEM_READ) begin
                case (ls_last_step)
                  WAIT_FOR_FIRST_BYTE: mc_to_lsb_ld_val <= {24'b0, mem_to_mc_din};
                  WAIT_FOR_SECOND_BYTE: mc_to_lsb_ld_val <= {16'b0, mem_to_mc_din, mem_result[7:0]};
                  WAIT_FOR_THIRD_BYTE: mc_to_lsb_ld_val <= {8'b0, mem_to_mc_din, mem_result[15:0]};
                  WAIT_FOR_FOURTH_BYTE: mc_to_lsb_ld_val <= {mem_to_mc_din, mem_result[23:0]};
                  default: ;
                endcase
                mem_result <= 0;
                mc_to_lsb_ld_done <= `TRUE;
              end else begin  //store
                mc_to_lsb_st_done <= `TRUE;
              end
            end
          end
        end else begin

        end
      end
    end
  end
endmodule
`endif
