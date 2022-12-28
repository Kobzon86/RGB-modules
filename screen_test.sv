/*
*Генератор RGB сигналов
*/
typedef struct packed {
  logic        clock  ;
  logic        hsync_n;
  logic        vsync_n;
  logic        de     ;
  logic [23:0] data   ;
  logic        locked ;
} t_parallel_video;

module screen_test (
  input                   clk                  ,
  input                   reset                ,
  output t_parallel_video o_video              ,
  input  [ 3:0]           mode                 ,
  input  [21:0]           resolution           ,
  input  [31:0]           Hfrporch_Vfrporch    ,
  input  [31:0]           Hbkporch_Vbkporch    ,
  input  [31:0]           Hsyncpulse_Vsyncpulse
);
//initial v_sync=1'b1;
logic [10:0]WIDTH;    always_ff @(posedge clk ) WIDTH   <= resolution[21:11];
logic [10:0]HEIGHT;   always_ff @(posedge clk ) HEIGHT  <= resolution[10:0];
logic [8:0]H_FRONT;   always_ff @(posedge clk ) H_FRONT <= Hfrporch_Vfrporch[24:16];  
logic [8:0]H_BACK;    always_ff @(posedge clk ) H_BACK  <= Hbkporch_Vbkporch[24:16];  
logic [8:0]H_SYNC;    always_ff @(posedge clk ) H_SYNC  <= Hsyncpulse_Vsyncpulse[24:16];    
logic [5:0]V_FRONT;   always_ff @(posedge clk ) V_FRONT <= Hfrporch_Vfrporch[5:0];  
logic [7:0]V_BACK;    always_ff @(posedge clk ) V_BACK  <= Hbkporch_Vbkporch[7:0];    
logic [5:0]V_SYNC;    always_ff @(posedge clk ) V_SYNC  <= Hsyncpulse_Vsyncpulse[5:0];      


reg[11:0]full_x;    always_ff @(posedge clk )full_x  <= WIDTH + H_FRONT + H_SYNC + H_BACK ;
reg[10:0]full_y;    always_ff @(posedge clk )full_y  <= HEIGHT + V_FRONT + V_SYNC + V_BACK;
reg[10:0]blank_x;   always_ff @(posedge clk )blank_x <= H_FRONT + H_SYNC + H_BACK;
reg[8:0]blank_y;    always_ff @(posedge clk )blank_y <= V_FRONT + V_SYNC + V_BACK;

  logic [11:0] pix_cnt=0 ;
  logic [10:0] line_cnt=0;

  always_ff @(posedge clk or negedge reset)
    if (!reset)
      begin
        pix_cnt  <= '0;
        line_cnt <= '0;
      end
    else
      begin
        if (pix_cnt < full_x - 1'b1)
            pix_cnt <= pix_cnt + 1'b1;
        else
          begin
            pix_cnt <= '0;
            if (line_cnt < full_y - 1'b1)   line_cnt <= line_cnt + 1'b1;
            else line_cnt <= '0;
          end
      end

  always_ff @(posedge clk or negedge reset)
    begin
      if (!reset)
        begin
          o_video.hsync_n <= 1'b1;
          o_video.vsync_n <= 1'b1;
          o_video.de     <= '0;
        end
      else
        begin
          o_video.hsync_n <= (pix_cnt  < H_BACK || pix_cnt  > (H_SYNC + H_BACK - 1'b1)) ? 1'b1 : 1'b0;
          o_video.vsync_n <= (line_cnt < V_BACK || line_cnt > (V_SYNC + V_BACK - 1'b1)) ? 1'b1 : 1'b0;
          o_video.de     <= (pix_cnt  > (blank_x - 1'b1) && line_cnt > (blank_y - 1'b1) ) ? 1'b1 : 1'b0;
        end
    end



wire de_sig = (pix_cnt  > (blank_x - 1'b1) && line_cnt > (blank_y - 1'b1) );
/////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////Test data generation
///////////////////black box with a white frame along the frame border and intersecting diagonal lines

wire [10:0] width_div_8 = WIDTH/8;
wire [10:0] heigth_div_8 = HEIGHT/8;
wire [10:0] cross_step = WIDTH*256/HEIGHT;

logic [10:0] de_counter;
logic [21:0] de_counter_fracture;
logic [10:0] pix_counter;
logic [1:0] de_edge_fndr;
wire [5:0] cross_events = {(pix_counter == '0),(pix_counter == WIDTH-1),(de_counter == '0),(de_counter == HEIGHT-1),(pix_counter == de_counter_fracture[18:8]),(pix_counter == ((WIDTH-1) - de_counter_fracture[18:8]))};
logic cross_pix;
always_ff @(posedge clk) begin
  de_edge_fndr <= {de_edge_fndr[0],de_sig};

  if( !o_video.vsync_n ) 
    de_counter <= '0;
  if( de_edge_fndr == 2'd2 )
    de_counter <= de_counter + 1;  

  de_counter_fracture <= de_counter * cross_step;


  if( !de_sig )
    pix_counter <= '0;
  else 
    pix_counter <= pix_counter + 1;

  cross_pix <=  |cross_events ;

end

///////////////////////////////////////////////
/////////////////////////////////grayscale
logic [7:0] gray_lines=0;
logic [10:0]gray_pix_counter;
logic [3:0] gray_number;
always_ff @(posedge clk) begin : gray_gen  
  if(!de_sig )begin
    gray_pix_counter = '0;
    gray_number = '0; 
  end
  else if( gray_pix_counter == width_div_8 )begin
    gray_pix_counter ='0;
    gray_number++;
  end
  else gray_pix_counter++;

  gray_lines <= 8'hff >> gray_number;
end
///////////////////////////////////////////////
///////////////////////////////////////////////

//////////////////////////////////////////////
////////////////////////////////chessboard
logic [7:0] chess=0;
logic [1:0]chess_colour;
logic [10:0]chess_lines_counter;
always_ff @(posedge clk) begin : chess_gen 

  if(!de_sig )begin
    chess_colour[0] = '0; 
  end
  else if( gray_pix_counter == width_div_8 )begin
    chess_colour[0] = !chess_colour[0];
  end

  if(!o_video.vsync_n)begin
    chess_lines_counter = '0;
    chess_colour[1] = '0;
  end    
  else if(chess_lines_counter == heigth_div_8)begin
    chess_lines_counter = '0;
    chess_colour[1]++;
  end
  if(de_edge_fndr == 1)
    chess_lines_counter++;

  chess <= (^chess_colour) ? 8'hff:8'h0;  
end
///////////////////////////////////////////////////
///////////////////////////////////////////////////


//sequential switching between test frames: 
always_ff @(*) begin : mode_sel

  case (mode)
    4'd0:begin
      o_video.data <= {8'hff,8'h0,8'h0};// all-over red;
    end
    4'd1:begin
      o_video.data <= {8'h0,8'hff,8'h0};//all-over green; 
    end
    4'd2:begin
      o_video.data <= {8'h0,8'h0,8'hff};//all-over blue; 
    end
    4'd3:begin
      o_video.data <= {8'h0,8'h0,8'h0};//all-over black; 
    end    
    4'd4:begin
      o_video.data <= {8'hff,8'hff,8'hff};//all-over white; 
    end
    4'd5:begin 
      o_video.data <= {gray_lines,gray_lines,gray_lines};//grayscale;
    end
    4'd6:begin
      o_video.data <= {chess,chess,chess};//chess black and white field; 
    end
    default : begin
      o_video.data <= {{8{cross_pix}},{8{cross_pix}},{8{cross_pix}}};//black box with a white frame along the frame border and intersecting diagonal lines.
    end
  endcase
end




endmodule