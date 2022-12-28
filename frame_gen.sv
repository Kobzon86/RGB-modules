/*
*Генератор RGB сигналов
*/
module frame_gen (
  input               clk                  ,
  input               reset                ,
  output logic        h_sync               ,
  output logic        v_sync               ,
  output logic        de                   ,
  input        [21:0] resolution           ,
  input        [31:0] Hfrporch_Vfrporch    ,
  input        [31:0] Hbkporch_Vbkporch    ,
  input        [31:0] Hsyncpulse_Vsyncpulse
);
initial v_sync=1'b1;
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
          h_sync <= '0;
          v_sync <= 1'b1;
          de     <= '0;
        end
      else
        begin
          h_sync <= (pix_cnt  < H_BACK || pix_cnt  > (H_SYNC + H_BACK - 1'b1)) ? 1'b1 : 1'b0;
          v_sync <= (line_cnt < V_BACK || line_cnt > (V_SYNC + V_BACK - 1'b1)) ? 1'b1 : 1'b0;
          de     <= (pix_cnt  > (blank_x - 1'b1) && line_cnt > (blank_y - 1'b1) ) ? 1'b1 : 1'b0;
        end
    end

endmodule