module splash_screen #(
  parameter              PIXELS_IN_PARALLEL = 1                    ,
  parameter logic [15:0] PIC_WIDTH          = 400                  ,
  parameter logic [15:0] PIC_HEIGHT         = 160                  ,
  parameter              PIC_MIF            = "../splashscreen.mif",
  parameter              EMPTY_WIDTH        = 4
) (
  input                                      clk              ,
  input                                      reset            ,
  output logic                               aso_startofpacket,
  output logic                               aso_endofpacket  ,
  output logic                               aso_valid        ,
  output logic [(24*PIXELS_IN_PARALLEL)-1:0] aso_data         ,
  input                                      aso_ready        ,
  output       [            EMPTY_WIDTH-1:0] aso_empty
);
  
  localparam TOTAL_PIX   = ( PIC_WIDTH * PIC_HEIGHT )  ;
  localparam ROM_ADDR    = $clog2( TOTAL_PIX >> 2 )    ;

  initial
    begin
      $display("PIXELS_IN_PARALLEL: %d", PIXELS_IN_PARALLEL);
      $display("Width: %d(%x) Height: %d(%x)", PIC_WIDTH, PIC_WIDTH, PIC_HEIGHT, PIC_HEIGHT);
      $display("ROM_ADDR: %d", ROM_ADDR);
    end

  enum logic [1:0] {
    MAIN_CONTROL,
    MAIN_DATA,
    MAIN_RESET
  } state_main;

  enum logic [2:0] {
    CTRL_IDLE,
    CTRL_SOP,
    CTRL_DATA1,
    CTRL_DATA2,
    CTRL_EOP,
    CTRL_RESET
  } state_ctrl;

  enum logic [2:0] {
    DATA_IDLE,
    DATA_SOP,
    DATA_DATA,
    DATA_EOP,
    DATA_RESET
  } state_data;

  logic                               ctrl_startofpacket;
  logic                               ctrl_valid        ;
  logic [(24*PIXELS_IN_PARALLEL)-1:0] ctrl_data         ;
  logic                               ctrl_endofpacket  ;

  logic                               data_startofpacket;
  logic                               data_valid        ;
  logic [(24*PIXELS_IN_PARALLEL)-1:0] data_data         ;
  logic                               data_endofpacket  ;

  logic [         1:0]       subpix_cnt, subpix_cnt_r;
  logic [ROM_ADDR-1:0]       rom_addr, rom_addr_r;
  logic [        15:0]       rom_data  ;
  logic [         3:0][23:0] pixel_8bit;

  logic [3:0][3:0] W;
  logic [3:0][3:0] H;

  assign W = {PIC_WIDTH[3:0], PIC_WIDTH[7:4], PIC_WIDTH[11:8], PIC_WIDTH[15:12]};
  assign H = {PIC_HEIGHT[3:0], PIC_HEIGHT[7:4], PIC_HEIGHT[11:8], PIC_HEIGHT[15:12]};

  assign aso_startofpacket = (state_main == MAIN_CONTROL) ? ctrl_startofpacket : data_startofpacket;
  assign aso_endofpacket   = (state_main == MAIN_CONTROL) ? ctrl_endofpacket   : data_endofpacket  ;
  assign aso_valid         = (state_main == MAIN_CONTROL) ? ctrl_valid         : data_valid        ;
  assign aso_data          = (state_main == MAIN_CONTROL) ? ctrl_data          : data_data         ;
  assign aso_empty         = '0;

  always_comb
    begin
      for(int i = 0; i < 4; i++)
        begin
          case (rom_data[i*4 +: 4])
            4'h0 : pixel_8bit[i] = 24'b00000000_00000000_00000000; // Черный
            4'h1 : pixel_8bit[i] = 24'b11001110_00000000_00000000; // Темно-синий
            4'h2 : pixel_8bit[i] = 24'b00000000_11001110_00000000; // Темно-зеленый
            4'h3 : pixel_8bit[i] = 24'b11001110_11001110_00000000; // Темно-бирюзовый
            4'h4 : pixel_8bit[i] = 24'b00000000_00000000_11001110; // Темно-красный
            4'h5 : pixel_8bit[i] = 24'b11001110_00000000_11001110; // Темно-фиолетовый
            4'h6 : pixel_8bit[i] = 24'b00000000_11001110_11001110; // Темно-желтый
            4'h7 : pixel_8bit[i] = 24'b11000000_11000000_11000000; // Светло-серый
            4'h8 : pixel_8bit[i] = 24'b11001110_11001110_11001110; // Темно-серый
            4'h9 : pixel_8bit[i] = 24'b11111111_00000000_00000000; // Синий
            4'hA : pixel_8bit[i] = 24'b00000000_11111111_00000000; // Зеленый
            4'hB : pixel_8bit[i] = 24'b11111111_11111111_00000000; // Бирюзовый
            4'hC : pixel_8bit[i] = 24'b00000000_00000000_11111111; // Красный
            4'hD : pixel_8bit[i] = 24'b11111111_00000000_11111111; // Фиолетовый
            4'hE : pixel_8bit[i] = 24'b00000000_11111111_11111111; // Желтый
            4'hF : pixel_8bit[i] = 24'b11111111_11111111_11111111; // Белый
          endcase
        end
    end

  always_ff @(posedge clk or posedge reset)
    begin
      if (reset)
        state_main <= MAIN_RESET;
      else
        begin
          case (state_main)
            MAIN_CONTROL :
              begin
                if (aso_endofpacket && aso_valid)
                  state_main <= MAIN_DATA;
              end
            MAIN_DATA :
              begin
                if (aso_endofpacket && aso_valid)
                  state_main <= MAIN_CONTROL;
              end
            default : state_main <= MAIN_CONTROL;
          endcase
        end
    end

  always_ff @(posedge clk or posedge reset)
    begin
      if (reset)
        begin
          state_data         <= DATA_RESET;
          data_startofpacket <= '0;
          data_valid         <= '0;
          data_data          <= '0;
          data_endofpacket   <= '0;
        end
      else
        begin
          case (state_data)
            DATA_IDLE :
              begin
                if (state_main == MAIN_DATA && aso_ready)
                  begin
                    state_data <= DATA_SOP;
                    case (PIXELS_IN_PARALLEL)
                      1 : data_data <= '0;
                      2 : data_data <= '0;
                      4 : data_data <= '0;
                    endcase
                    data_startofpacket <= 1'b1;
                    data_valid         <= 1'b1;
                  end
              end
            DATA_SOP :
              begin
                data_startofpacket <= '0;
                if (aso_ready)
                  begin
                    case (PIXELS_IN_PARALLEL)
                      1 : data_data <= pixel_8bit[subpix_cnt];
                      2 : data_data <= (subpix_cnt[0]) ? {pixel_8bit[3], pixel_8bit[2]} : {pixel_8bit[1], pixel_8bit[0]};
                      4 : data_data <= {pixel_8bit[3], pixel_8bit[2], pixel_8bit[1], pixel_8bit[0]};
                    endcase
                    data_valid <= 1'b1;
                    state_data <= DATA_DATA;
                  end
                else
                  data_valid <= '0;
              end
            DATA_DATA :
              begin
                if (aso_ready)
                  begin
                    case (PIXELS_IN_PARALLEL)
                      1 :
                        begin
                          data_data        <= pixel_8bit[subpix_cnt];
                          state_data       <= (rom_addr >= ( ( TOTAL_PIX >> 2 ) - 1 ) && subpix_cnt == 2 ) ? DATA_EOP : DATA_DATA;
                          data_endofpacket <= (rom_addr >= ( ( TOTAL_PIX >> 2 ) - 1 ) && subpix_cnt == 2 ) ? 1'b1 : '0;
                        end
                      2 :
                        begin
                          data_data        <= (subpix_cnt[0]) ? {pixel_8bit[3], pixel_8bit[2]} : {pixel_8bit[1], pixel_8bit[0]};
                          state_data       <= (rom_addr >= ( ( TOTAL_PIX >> 2 ) - 1 )  && subpix_cnt == 0 ) ? DATA_EOP : DATA_DATA;
                          data_endofpacket <= (rom_addr >= ( ( TOTAL_PIX >> 2 ) - 1 )  && subpix_cnt == 0 ) ? 1'b1 : '0;
                        end
                      4 :
                        begin
                          data_data        <= {pixel_8bit[3],pixel_8bit[2],pixel_8bit[1],pixel_8bit[0]};
                          state_data       <= (rom_addr >= ( ( TOTAL_PIX >> 2 ) - 2 ) ) ? DATA_EOP : DATA_DATA;
                          data_endofpacket <= (rom_addr >= ( ( TOTAL_PIX >> 2 ) - 2 ) ) ? 1'b1 : '0;
                        end
                    endcase
                    data_valid <= 1'b1;

                  end
                else
                  data_valid <= '0;
              end
            DATA_EOP :
              begin
                data_endofpacket <= 1'b0;
                data_data        <= '0;
                state_data       <= DATA_IDLE;
                data_valid       <= '0;
              end
            default :
              begin
                data_startofpacket <= '0;
                data_valid         <= '0;
                data_data          <= '0;
                data_endofpacket   <= '0;
                state_data         <= DATA_IDLE;
              end
          endcase
        end
    end

  always_ff @(posedge clk or posedge reset)
    begin
      if (reset)
        begin
          state_ctrl         <= CTRL_RESET;
          ctrl_startofpacket <= '0;
          ctrl_valid         <= '0;
          ctrl_data          <= '0;
          ctrl_endofpacket   <= '0;
        end
      else
        begin
          case (state_ctrl)
            CTRL_IDLE :
              begin
                if (state_main == MAIN_CONTROL && aso_ready)
                  begin
                    state_ctrl         <= CTRL_SOP;
                    ctrl_startofpacket <= 1'b1;
                    ctrl_endofpacket   <= '0;
                    ctrl_valid         <= 1'b1;
                    ctrl_data          <= 4'hF;
                  end
              end
            CTRL_SOP :
              begin
                ctrl_startofpacket <= 1'b0;
                if (aso_ready)
                  begin
                    ctrl_valid <= 1'b1;
                    ctrl_data  <= 4'hF;
                    case (PIXELS_IN_PARALLEL)
                      1 :
                        begin
                          state_ctrl <= CTRL_DATA1;
                          ctrl_data  <= {4'h0, W[2], 4'h0, W[1], 4'h0, W[0]};
                        end
                      2 :
                        begin
                          state_ctrl <= CTRL_DATA1;
                          ctrl_data  <= {4'h0, H[1], 4'h0, H[0], 4'h0, W[3], 4'h0, W[2], 4'h0, W[1], 4'h0, W[0]};
                        end
                      4 :
                        begin
                          state_ctrl       <= CTRL_EOP;
                          ctrl_data        <= {4'h3, 4'h0, H[3], 4'h0, H[2], 4'h0, H[1], 4'h0, H[0], 4'h0, W[3], 4'h0, W[2], 4'h0, W[1], 4'h0, W[0]};
                          ctrl_endofpacket <= 1'b1;
                        end
                    endcase
                  end
                else
                  ctrl_valid <= '0;
              end
            CTRL_DATA1 :
              begin
                if (aso_ready)
                  begin
                    ctrl_valid <= 1'b1;
                    case (PIXELS_IN_PARALLEL)
                      1 :
                        begin
                          state_ctrl <= CTRL_DATA2;
                          ctrl_data  <= {4'h0, H[1], 4'h0, H[0], 4'h0, W[3]};
                        end
                      2 :
                        begin
                          state_ctrl       <= CTRL_EOP;
                          ctrl_data        <= {4'h3, 4'h0, H[3], 4'h0, H[2]};
                          ctrl_endofpacket <= 1'b1;
                        end
                    endcase
                  end
                else
                  ctrl_valid <= 1'b0;
              end
            CTRL_DATA2 :
              begin
                if (aso_ready)
                  begin
                    ctrl_valid       <= 1'b1;
                    ctrl_endofpacket <= 1'b1;
                    ctrl_data        <= {4'h3, 4'h0, H[3], 4'h0, H[2]};
                    state_ctrl       <= CTRL_EOP;
                  end
                else
                  ctrl_valid <= 1'b0;
              end
            CTRL_EOP :
              begin
                ctrl_startofpacket <= '0;
                ctrl_endofpacket   <= '0;
                ctrl_valid         <= '0;
                ctrl_data          <= '0;
                state_ctrl         <= CTRL_IDLE;
              end
            default :
              begin
                state_ctrl         <= CTRL_IDLE;
                ctrl_startofpacket <= '0;
                ctrl_endofpacket   <= '0;
                ctrl_valid         <= '0;
                ctrl_data          <= '0;
              end
          endcase
        end
    end

  always_ff @(posedge clk or posedge reset)
    begin
      if (reset)
        begin
          subpix_cnt <= '0;
          rom_addr   <= '0;
        end
      else
        begin
          subpix_cnt <= subpix_cnt_r;
          rom_addr   <= rom_addr_r;
        end
    end

  always_comb
    begin
      if (state_main == MAIN_CONTROL)
        begin
          subpix_cnt_r = '0;
          rom_addr_r   = '0;
        end
      else if ( ( state_data == DATA_SOP || state_data == DATA_DATA ) && aso_ready )
        begin
          if ( ( subpix_cnt == 3 && PIXELS_IN_PARALLEL == 1 ) || ( subpix_cnt == 1 && PIXELS_IN_PARALLEL == 2) || PIXELS_IN_PARALLEL == 4)
            begin
              subpix_cnt_r = '0;
              rom_addr_r   = ( rom_addr < ( ( TOTAL_PIX >> 2 ) - 1 ) ) ? rom_addr + 1'b1 : '0;
            end
          else 
            begin
              rom_addr_r   = rom_addr;
              subpix_cnt_r = subpix_cnt + 1'b1;
            end
        end
      else
        begin
          subpix_cnt_r = subpix_cnt;
          rom_addr_r   = rom_addr;
        end
    end

  altsyncram #(
    .address_aclr_a        ("NONE"                                      ),
    .clock_enable_input_a  ("BYPASS"                                    ),
    .clock_enable_output_a ("BYPASS"                                    ),
    .init_file             (PIC_MIF                                     ),
    .intended_device_family("Cyclone V"                                 ),
    .lpm_hint              ("ENABLE_RUNTIME_MOD=YES, INSTANCE_NAME=LOGO"),
    .lpm_type              ("altsyncram"                                ),
    .numwords_a            (2 ** ROM_ADDR                               ),
    .operation_mode        ("ROM"                                       ),
    .outdata_aclr_a        ("NONE"                                      ),
    .outdata_reg_a         ("UNREGISTERED"                              ),
    .ram_block_type        ("M10K"                                      ),
    .widthad_a             (ROM_ADDR                                    ),
    .width_a               (16                                          ),
    .width_byteena_a       (1                                           )
  ) altsyncram_component (
    .address_a(rom_addr_r),
    .clock0   (clk       ),
    .q_a      (rom_data  )
  );

endmodule