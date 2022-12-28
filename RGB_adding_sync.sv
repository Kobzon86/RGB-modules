/*
*Модуль вставляет недостающие сигналы синхронизации в RGB поток
*/
typedef struct packed {
	logic        clock  ;
	logic        hsync_n;
	logic        vsync_n;
	logic        de     ;
	logic [23:0] data   ;
	logic        locked ;
} t_parallel_video;

module RGB_adding_sync (
	input                   clk          ,
	input                   reset        ,
	//////////входы rgb
	input                   i_de         ,
	input        [23:0]     i_data       ,
	//////////выход rgb
	output t_parallel_video o_video
);
	assign o_video.clock = clk;
	logic [11:0] pix_cnt  = 0;
	logic [10:0] line_cnt = 0;
	logic[11:0] H_FRONT;
	logic[11:0] H_BACK ;
	logic[11:0] H_SYNC ;
	logic[10:0] V_FRONT;
	logic[10:0] V_BACK ;
	logic[10:0] V_SYNC ;
	logic [12:0] full_x;
	logic [12:0] full_y;

	always_ff @(posedge clk)begin
		if(width_sig[3]>900)begin
			H_FRONT <= 12'd24;
			H_BACK  <= 12'd160;
			H_SYNC  <= 12'd136;
			V_FRONT <= 11'd3;
			V_BACK  <= 11'd29;
			V_SYNC  <= 11'd6;
		end
		else if(width_sig[3][9:8] == 2'b11)begin
			H_FRONT <= 12'd40;
			H_BACK  <= 12'd88;
			H_SYNC  <= 12'd128;
			V_FRONT <= 11'd1;
			V_BACK  <= 11'd23;
			V_SYNC  <= 11'd4;
		end
		else begin
			H_FRONT <= 12'h10;
			H_BACK  <= 12'h30;
			H_SYNC  <= 12'h60;
			V_FRONT <= 11'h0a;
			V_BACK  <= 11'h21;
			V_SYNC  <= 11'h02;
		end

		full_x <= H_FRONT + H_SYNC + H_BACK + width_sig[3];
		full_y <= V_FRONT + V_SYNC + V_BACK;
	end

	logic[11:0]width_sig[3:0];
	always_ff @(posedge clk or negedge reset) begin : proc_
		if(~reset) begin
			o_video.hsync_n <= 0;
			o_video.vsync_n <= 0;
			o_video.de      <= 0;
			pix_cnt         <= '0;
			line_cnt        <= '0;
		end else begin
			o_video.de   <= i_de;
			o_video.data <= i_data;
			if(i_de) begin
				pix_cnt      <= '0;
				line_cnt     <= '0;
				width_sig[0] <= width_sig[0] + 1'b1;
			end
			else begin
				width_sig[0] <= '0;
				if(pix_cnt < full_x)
					pix_cnt <= pix_cnt + 1'b1;
				else begin
					pix_cnt <= '0;
					if (line_cnt < full_y - 1'b1)   line_cnt <= line_cnt + 1'b1;
				end
			end

			if( o_video.de && ( !i_de ) )begin
				{width_sig[3],width_sig[2],width_sig[1]} <=  {width_sig[2],width_sig[1],width_sig[0]};
			end

			o_video.locked  <= (width_sig[3] == width_sig[2]) && (width_sig[2] == width_sig[1]) && (width_sig[1] != '0);
			o_video.hsync_n <= (pix_cnt  < H_BACK || pix_cnt  > (H_SYNC + H_BACK - 1'b1)) ? 1'b1 : 1'b0;
			o_video.vsync_n <= (line_cnt < V_BACK || line_cnt > (V_SYNC + V_BACK - 1'b1)) ? 1'b1 : 1'b0;
		end
	end
endmodule
