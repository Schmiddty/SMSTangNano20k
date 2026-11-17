// SMS resolved-color indexed scanout, full 240 lines, and shared menu artwork/OSD.
// SMS CRAM supplies two bits per channel; storing the resolved color at each
// pixel preserves raster palette changes without a large RGB444 framebuffer.
module sms_nano_hdmi(
 input wire debug_enable,
 input wire clk,resetn,pixel_resetn,clk_pixel,clk_5x_pixel,
 input wire ce_pix,game_gear,input wire[7:0]gamegear_top,input wire[8:0]x,y,input wire[11:0]color,
 input wire[8:0]height,input wire[15:0]audio_l,audio_r,
 input wire overlay,output wire[10:0]overlay_x,output wire[9:0]overlay_y,
 input wire[15:0]overlay_color,input wire[23:0]background_rgb,input wire background_valid,
 input wire[15:0]debug_cpu_count,debug_stall_count,debug_m1_wait_count,debug_mem_wait_count,debug_io_wait_count,debug_m1_max_run,debug_raw_m1_t1,debug_raw_m1_t2,debug_raw_m1_t3,debug_m1_wait_max_sysclks,debug_m1_wait_assertions,debug_m1_wait_assertions_hi,debug_m1_event_min_lo,debug_m1_event_min_hi,debug_m1_event_max_lo,debug_m1_event_max_hi,debug_m1_event_avg_lo,debug_m1_event_avg_hi,
 input wire[23:0]debug_m1_wait_sysclks,
 input wire[255:0]debug_event_history,
 input wire[23:0]debug_current_event_count,debug_block_max_event_count,
 output wire tmds_clk_n,tmds_clk_p,output wire[2:0]tmds_d_n,tmds_d_p
);
// 64 native SMS colors plus the fixed legacy TMS palette used by SMS titles
// in legacy display modes. Seven bits retain both without RGB quantization.
function automatic[6:0]encode_color(input[11:0]c);
 begin
 encode_color={1'b0,c[11:10],c[7:6],c[3:2]};
 case(c)
  12'h4A2:encode_color=7'd64;
  12'h7E6:encode_color=7'd65;
  12'hF55:encode_color=7'd66;
  12'hF88:encode_color=7'd67;
  12'h55D:encode_color=7'd68;
  12'hFF4:encode_color=7'd69;
  12'h55F:encode_color=7'd70;
  12'h88F:encode_color=7'd71;
  12'h5DD:encode_color=7'd72;
  12'h8DE:encode_color=7'd73;
  12'h4B2:encode_color=7'd74;
  12'hA6B:encode_color=7'd75;
  12'hBBB:encode_color=7'd76;
  default:;
 endcase
 end
endfunction
function automatic[23:0]decode_color(input[6:0]c);
 reg[11:0]legacy;
 begin
 legacy=0;
 case(c)
  7'd64:legacy=12'h4A2;
  7'd65:legacy=12'h7E6;
  7'd66:legacy=12'hF55;
  7'd67:legacy=12'hF88;
  7'd68:legacy=12'h55D;
  7'd69:legacy=12'hFF4;
  7'd70:legacy=12'h55F;
  7'd71:legacy=12'h88F;
  7'd72:legacy=12'h5DD;
  7'd73:legacy=12'h8DE;
  7'd74:legacy=12'h4B2;
  7'd75:legacy=12'hA6B;
  7'd76:legacy=12'hBBB;
  default:;
 endcase
 decode_color=c[6]?{{2{legacy[3:0]}},{2{legacy[7:4]}},{2{legacy[11:8]}}}:{{4{c[1:0]}},{4{c[3:2]}},{4{c[5:4]}}};
 end
endfunction
// A common 14-bit RAM holds two lossless SMS pixels or one RGB444 GG pixel.
// Packing SMS pairs preserves its full 256x240 image and all legacy colours,
// while GG uses 160x144 RGB444 cells within exactly the same storage budget.
(* syn_ramstyle="block_ram" *) reg[13:0]frame[0:30719];
reg[14:0]init_address=0;reg initialized=0;reg[6:0]first_pixel=0;
wire sms_write=ce_pix&&!game_gear&&x>=1&&x<=256&&y<240&&!x[0];
wire gg_write=ce_pix&&game_gear&&x>48&&x<=208&&y>=gamegear_top&&y<({1'b0,gamegear_top}+9'd144);
wire[7:0]gg_row=y-gamegear_top;
wire[14:0]gg_write_address=({7'd0,gg_row}<<7)+({7'd0,gg_row}<<5)+(x-9'd49);
wire[14:0]frame_write_address=!initialized?init_address:game_gear?gg_write_address:{y[7:0],x[7:1]-7'd1};
wire[13:0]frame_write_data=!initialized?14'd0:game_gear?{2'b0,color}:{encode_color(color),first_pixel};
wire frame_write=!initialized||sms_write||gg_write;
always @(posedge clk)if(frame_write)frame[frame_write_address]<=frame_write_data;
always @(posedge clk)begin
 if(!initialized)begin
  if(init_address==30719)initialized<=1;else init_address<=init_address+1'b1;
 end
 if(ce_pix&&x>=1&&x<=256&&y<240&&x[0])first_pixel<=encode_color(color);
 if(!resetn)begin init_address<=0;initialized<=0;first_pixel<=0;end
end
wire[10:0]cx;wire[9:0]cy;
assign overlay_x=cx;assign overlay_y=cy;
wire[8:0]pixel_height;
cdc_mailbox #(.WIDTH(9))height_cdc(.src_clk(clk),.src_resetn(resetn),.src_data(height),
 .dst_clk(clk_pixel),.dst_resetn(pixel_resetn),.dst_data(pixel_height));
reg init_meta=0,init_pixel=0,overlay_meta=0,overlay_pixel=0;
always @(posedge clk_pixel)begin
 init_meta<=initialized;init_pixel<=init_meta;overlay_meta<=overlay;overlay_pixel<=overlay_meta;
 if(!pixel_resetn)begin init_meta<=0;init_pixel<=0;overlay_meta<=0;overlay_pixel<=0;end
end
// Fractional scaling uses bounded add/subtract counters, not wide dividers.
// Prefetch the next HDMI pixel to compensate for synchronous framebuffer RAM.
wire gear_pixel=pixel_height==9'd144;
wire[10:0]window_left=gear_pixel?11'd240:11'd160,window_right=gear_pixel?11'd1040:11'd1120;
wire[10:0]window_width=gear_pixel?11'd800:11'd960;
reg[7:0]sx=0,sy=0;reg[9:0]xphase=0,yphase=0;
wire[10:0]xsum={1'b0,xphase}+(gear_pixel?11'd160:11'd256);
wire[10:0]ysum={1'b0,yphase}+{2'b0,(gear_pixel?9'd144:pixel_height==224?9'd224:pixel_height==240?9'd240:9'd192)};
wire[7:0]source_x=cx==window_left-1?8'd0:xsum>=window_width?sx+1'b1:sx;
wire[7:0]source_y=sy;
always @(posedge clk_pixel)begin
 if(cx==window_left-1)begin sx<=0;xphase<=0;end
 else if(cx>=window_left&&cx<window_right-1)begin
  xphase<=xsum>=window_width?xsum-window_width:xsum;
  sx<=source_x;
 end
 if(cx==1651&&cy<719)begin
  yphase<=ysum>=720?ysum-11'd720:ysum;
  if(ysum>=720)sy<=sy+1'b1;
 end
 if((cx==0&&cy==0)||!pixel_resetn)begin sy<=0;yphase<=0;end
 if(!pixel_resetn)begin sx<=0;xphase<=0;end
end
// Two 160-word scanline buffers isolate HDMI scanout from writes to the
// live frame store. During each line's horizontal blanking interval, copy
// the next source row into the inactive buffer. The SMS format stores two
// pixels per word (128 words); Game Gear stores one pixel per word (160).
// The 74.25 MHz pixel clock provides at least 160 clocks before the visible
// image starts (x=160 for SMS, x=240 for Game Gear).
(* syn_ramstyle="block_ram" *) reg[13:0]linebuf0[0:159];
(* syn_ramstyle="block_ram" *) reg[13:0]linebuf1[0:159];
reg display_buf=0;
reg prefetch_buf=1;
reg prefetch_active=0;
reg prefetch_gear=0;
reg[7:0]prefetch_y=0;
reg[7:0]prefetch_index=0;
reg[7:0]prefetch_write_index=0;
reg prefetch_write_buf=0;
reg prefetch_write_valid=0;
reg[13:0]frame_read_data;
wire prefetch_start=(cx==0);
wire[7:0]request_index=prefetch_start?8'd0:prefetch_index;
wire request_valid=prefetch_start || prefetch_active;
wire request_gear=prefetch_start?gear_pixel:prefetch_gear;
wire[7:0]request_y=prefetch_start?source_y:prefetch_y;
wire request_buf=prefetch_start?~display_buf:prefetch_buf;
wire[14:0]gg_prefetch_address=({7'd0,request_y}<<7)+({7'd0,request_y}<<5)+request_index;
wire[14:0]sms_prefetch_address={request_y,request_index[6:0]};
wire[14:0]frame_read_address=request_gear?gg_prefetch_address:sms_prefetch_address;
wire[7:0]line_read_index=gear_pixel?source_x:{1'b0,source_x[7:1]};
reg[13:0]pixel_pair;
reg pixel_half=0;
wire[6:0]pixel=pixel_half?pixel_pair[13:7]:pixel_pair[6:0];
wire game_window=cx>=window_left&&cx<window_right&&cy<720;
// The framebuffer read is synchronous. Its result is written to the
// selected inactive line buffer one pixel clock later.
always @(posedge clk_pixel)begin
 if(request_valid)frame_read_data<=frame[frame_read_address];
 if(prefetch_write_valid)begin
  if(prefetch_write_buf)linebuf1[prefetch_write_index]<=frame_read_data;
  else linebuf0[prefetch_write_index]<=frame_read_data;
 end
 prefetch_write_valid<=request_valid;
 if(request_valid)begin
  prefetch_write_index<=request_index;
  prefetch_write_buf<=request_buf;
 end
 if(prefetch_start)begin
  prefetch_y<=source_y;
  prefetch_gear<=gear_pixel;
  prefetch_buf<=~display_buf;
  prefetch_index<=8'd1;
  prefetch_active<=1'b1;
 end else if(prefetch_active)begin
  if(prefetch_index==(prefetch_gear?8'd159:8'd127))prefetch_active<=1'b0;
  else prefetch_index<=prefetch_index+1'b1;
 end
 // The inactive buffer is ready before the visible image begins.
 if(cx==window_left-2)display_buf<=prefetch_buf;
 if(!pixel_resetn)begin
  display_buf<=0;prefetch_buf<=1;prefetch_active<=0;
  prefetch_write_valid<=0;prefetch_index<=0;
 end
end
always @(posedge clk_pixel)begin
 if(cx>=window_left-1&&cx<window_right-1&&cy<720&&source_y<(gear_pixel?144:240))begin
  pixel_pair<=display_buf?linebuf1[line_read_index]:linebuf0[line_read_index];
  pixel_half<=source_x[0];
 end else begin pixel_pair<=0;pixel_half<=0;end
end
wire[23:0]gg_rgb={{2{pixel_pair[3:0]}},{2{pixel_pair[7:4]}},{2{pixel_pair[11:8]}}};
wire[23:0]game_rgb=game_window&&init_pixel?(gear_pixel?gg_rgb:decode_color(pixel)):24'd0;
reg[23:0]rgb;
// Compact hexadecimal readout for the live completed-frame count and the
// maximum from the most recently completed 32-frame statistics block.
function automatic [6:0] hex_segments(input [3:0] n);
 begin
  case(n)
   4'h0:hex_segments=7'b1111110; 4'h1:hex_segments=7'b0110000;
   4'h2:hex_segments=7'b1101101; 4'h3:hex_segments=7'b1111001;
   4'h4:hex_segments=7'b0110011; 4'h5:hex_segments=7'b1011011;
   4'h6:hex_segments=7'b1011111; 4'h7:hex_segments=7'b1110000;
   4'h8:hex_segments=7'b1111111; 4'h9:hex_segments=7'b1111011;
   4'hA:hex_segments=7'b1110111; 4'hB:hex_segments=7'b0011111;
   4'hC:hex_segments=7'b1001110; 4'hD:hex_segments=7'b0111101;
   4'hE:hex_segments=7'b1001111; default:hex_segments=7'b1000111;
  endcase
 end
endfunction
function automatic [23:0] draw_hex_digit(input [3:0] n,input [4:0] px,input [4:0] py);
 reg [6:0] seg; reg on;
 begin
  seg=hex_segments(n); on=0;
  if(px>=5 && px<=14 && py>=1 && py<=4 && seg[6]) on=1;
  if(px>=5 && px<=14 && py>=10 && py<=13 && seg[0]) on=1;
  if(px>=5 && px<=14 && py>=19 && py<=22 && seg[3]) on=1;
  if(px>=1 && px<=4 && py>=4 && py<=11 && seg[5]) on=1;
  if(px>=15 && px<=18 && py>=4 && py<=11 && seg[1]) on=1;
  if(px>=1 && px<=4 && py>=13 && py<=20 && seg[4]) on=1;
  if(px>=15 && px<=18 && py>=13 && py<=20 && seg[2]) on=1;
  draw_hex_digit=on?24'hFFFFFF:24'h101010;
 end
endfunction
// Fixed-scale, low-cost history graph. Each sample is count[11:4],
// i.e. 0..4080 events in 16-event increments. No window scan or
// per-pixel dynamic scaling logic is used.
wire [2:0] history_row=(cy-10'd140)>>4;
reg [7:0] history_threshold;
always @* begin
 case(history_row)
  3'd0: history_threshold=8'hff;
  3'd1: history_threshold=8'he0;
  3'd2: history_threshold=8'hc0;
  3'd3: history_threshold=8'ha0;
  3'd4: history_threshold=8'h80;
  3'd5: history_threshold=8'h60;
  3'd6: history_threshold=8'h40;
  default: history_threshold=8'h20;
 endcase
end
wire [7:0] history_value=debug_event_history[(((cx-11'd176)>>3)*8) +: 8];
// Two fixed-width six-digit hexadecimal readouts. C = most recently
// completed frame; H = maximum from the most recently completed 32-frame
// statistics block (same block as the existing min/max/average statistics).
wire [2:0] readout_digit_index=(cx-11'd200)/20;
wire [4:0] readout_px=(cx-11'd200)%20;
wire [4:0] readout_py=(cy<10'd304)?(cy-10'd276):(cy-10'd304);
wire [23:0] readout_value=(cy<10'd304)?debug_current_event_count:debug_block_max_event_count;
// Pixel scan advances left-to-right; show the low hex digit first.
wire [3:0] readout_nibble=readout_value[(readout_digit_index*4) +: 4];
wire [23:0] readout_rgb=draw_hex_digit(readout_nibble,readout_px,readout_py);
// D/E duration readouts live in the unused upper-right diagnostic margin.
// D is a 24-bit per-frame total; E is a zero-extended 16-bit longest run.
// Digits are shown least-significant first to correct the reversed readouts.
wire [2:0] duration_digit_index=(cx-11'd440)/20;
wire [4:0] duration_px=(cx-11'd440)%20;
wire [4:0] duration_py=(cy<10'd30)?(cy-10'd4):(cy-10'd32);
wire [23:0] duration_value=(cy<10'd30)?debug_m1_wait_sysclks:{8'd0,debug_m1_wait_max_sysclks};
wire [3:0] duration_nibble=duration_value[(duration_digit_index*4) +: 4];
wire [23:0] duration_rgb=draw_hex_digit(duration_nibble,duration_px,duration_py);
// textdisp updates its first valid pixel at cx256 on this same edge.
// The compositor sees the preceding registered color, as in the NES scanout.
wire text_window=cx>=257&&cx<1024&&cy>=24&&cy<696;
always @(posedge clk_pixel)begin
 rgb<=game_rgb;
 // Sixteen binary rows: original diagnostics plus 24-bit event count and
 // 32-frame block min/max/average statistics. Each metric is shown low 16
 // bits followed by its high 8 bits in a separate row.
 if(debug_enable && !overlay && !overlay_pixel && cy>=4 && cy<132 && cx>=176 && cx<432) begin
  if(cy<12) begin
   if(debug_cpu_count[15-((cx-176)>>4)]) rgb<=24'h00FF00;
   else rgb<=24'h001800;
  end else if(cy<20) begin
   if(debug_stall_count[15-((cx-176)>>4)]) rgb<=24'hFF2020;
   else rgb<=24'h180000;
  end else if(cy<28) begin
   if(debug_m1_wait_count[15-((cx-176)>>4)]) rgb<=24'h2080FF;
   else rgb<=24'h001020;
  end else if(cy<36) begin
   if(debug_mem_wait_count[15-((cx-176)>>4)]) rgb<=24'hFFFF00;
   else rgb<=24'h181800;
  end else if(cy<44) begin
   if(debug_io_wait_count[15-((cx-176)>>4)]) rgb<=24'h00FFFF;
   else rgb<=24'h001818;
  end else if(cy<52) begin
   if(debug_m1_max_run[15-((cx-176)>>4)]) rgb<=24'hFF40FF;
   else rgb<=24'h180018;
  end else if(cy<60) begin
   // Orange: total system-clock cycles WAIT remains low during M1/T2.
   if(debug_m1_wait_sysclks[15-((cx-176)>>4)]) rgb<=24'hFF8000; else rgb<=24'h201000;
  end else if(cy<68) begin
   // White: longest single continuous M1/T2 WAIT assertion, in sysclks.
   if(debug_m1_wait_max_sysclks[15-((cx-176)>>4)]) rgb<=24'hFFFFFF; else rgb<=24'h181818;
  end else if(cy<76) begin
   // Light green: low 16 bits of 24-bit distinct assertion count.
   if(debug_m1_wait_assertions[15-((cx-176)>>4)]) rgb<=24'h80FF80; else rgb<=24'h102010;
  end else if(cy<84) begin
   if(debug_m1_wait_assertions_hi[15-((cx-176)>>4)]) rgb<=24'h80FF80; else rgb<=24'h102010;
  end else if(cy<92) begin
   if(debug_m1_event_min_lo[15-((cx-176)>>4)]) rgb<=24'h40A0FF; else rgb<=24'h101820;
  end else if(cy<100) begin
   if(debug_m1_event_min_hi[15-((cx-176)>>4)]) rgb<=24'h40A0FF; else rgb<=24'h101820;
  end else if(cy<108) begin
   if(debug_m1_event_max_lo[15-((cx-176)>>4)]) rgb<=24'hFFFF40; else rgb<=24'h181800;
  end else if(cy<116) begin
   if(debug_m1_event_max_hi[15-((cx-176)>>4)]) rgb<=24'hFFFF40; else rgb<=24'h181800;
  end else if(cy<124) begin
   if(debug_m1_event_avg_lo[15-((cx-176)>>4)]) rgb<=24'h40FFFF; else rgb<=24'h101818;
  end else begin
   if(debug_m1_event_avg_hi[15-((cx-176)>>4)]) rgb<=24'h40FFFF; else rgb<=24'h101818;
  end
 end
  // D = total WAIT-low system clocks in the latest frame (24-bit);
  // E = longest uninterrupted WAIT-low run (16-bit, zero-extended).
  // Six digit cells fit in the unused upper-right diagnostic band.
  if(debug_enable && !overlay && !overlay_pixel && cx>=440 && cx<560 &&
     ((cy>=4 && cy<28)||(cy>=32 && cy<56))) begin
   if(duration_rgb==24'hFFFFFF) rgb<=((cy<28)?24'hFF9020:24'hFFFFFF);
   else rgb<=((cy<28)?24'h201000:24'h181818);
  end
  if(debug_enable && !overlay && !overlay_pixel && cx>=420 && cx<436 &&
     ((cy>=4 && cy<28)||(cy>=32 && cy<56))) begin
   if(cy<28) begin
    if((cx>=423&&cx<=432&&(cy==8||cy==23)) || (cx>=421&&cx<=424&&cy>=8&&cy<=23) || (cx>=430&&cx<=433&&cy>=10&&cy<=21)) rgb<=24'hFF9020; // D
   end else begin
    if((cx>=421&&cx<=433&&(cy==36||cy==43||cy==51)) || (cx>=421&&cx<=424&&cy>=36&&cy<=51)) rgb<=24'hFFFFFF; // E
   end
  end
  // Readable 32-frame bar chart. Each 8-pixel-wide bar is one completed
 // frame; oldest is left, newest right. Fixed full scale is 0..4080 events,
 // in 16-event buckets; each horizontal band is a 512-event threshold.
 if(debug_enable && !overlay && !overlay_pixel && cy>=140 && cy<268 && cx>=176 && cx<432) begin
  if((cy[3:0]==4'd0) || (((cx-11'd176)&11'd31)==0))
   rgb<=24'h303030;
  else if(history_value!=0 && history_value>=history_threshold)
   rgb<=24'hFFFF40;
  else
   rgb<=24'h181800;
 end
 // Six-digit hexadecimal readouts below the history graph.
 if(debug_enable && !overlay && !overlay_pixel && cx>=200 && cx<320 &&
    ((cy>=276 && cy<300)||(cy>=304 && cy<328))) begin
  if(cy<300) begin
   if(readout_rgb==24'hFFFFFF) rgb<=24'h80FF80;
   else rgb<=24'h081808;
  end else begin
   if(readout_rgb==24'hFFFFFF) rgb<=24'hFFFF40;
   else rgb<=24'h181800;
  end
 end
 // C = current frame (green); H = 32-frame block high-water mark (yellow).
 if(debug_enable && !overlay && !overlay_pixel && cx>=180 && cx<196 &&
    ((cy>=276 && cy<300)||(cy>=304 && cy<328))) begin
  if(cy<300) begin
   if((cx>=183&&cx<=192&&(cy==280||cy==295)) ||
      (cx>=181&&cx<=184&&cy>=280&&cy<=295)) rgb<=24'h80FF80;
  end else begin
   if((cx>=183&&cx<=192&&(cy==308||cy==323)) ||
      (cx>=181&&cx<=184&&cy>=308&&cy<=323) ||
      (cx>=192&&cx<=195&&cy>=308&&cy<=323)) rgb<=24'hFFFF40;
  end
 end
 if(overlay_pixel)begin
  rgb<={2'b0,game_rgb[23:18],2'b0,game_rgb[15:10],2'b0,game_rgb[7:2]};
  if(background_valid)begin
   rgb<=background_rgb;
   if(text_window&&!overlay_color[15]&&overlay_color[0])
    rgb<={1'b0,background_rgb[23:17],1'b0,background_rgb[15:9],1'b0,background_rgb[7:1]};
  end
  if(text_window&&!overlay_color[15]&&overlay_color[1])begin
   if(background_valid)begin
    if(overlay_color[0])rgb<={2'b0,background_rgb[23:18],2'b0,background_rgb[15:10],2'b0,background_rgb[7:2]};
    else rgb<={1'b0,background_rgb[23:17],1'b0,background_rgb[15:9],1'b0,background_rgb[7:1]};
   end else rgb<={2'b01,game_rgb[23:18],2'b01,game_rgb[15:10],2'b01,game_rgb[7:2]};
  end
  if(text_window&&overlay_color[15])rgb<={overlay_color[4:0],3'b0,overlay_color[9:5],3'b0,overlay_color[14:10],3'b0};
 end
 if(!pixel_resetn)rgb<=0;
end
wire[31:0]coherent_audio;
cdc_mailbox #(.WIDTH(32))audio_cdc(.src_clk(clk),.src_resetn(resetn),.src_data({audio_r,audio_l}),
 .dst_clk(clk_pixel),.dst_resetn(pixel_resetn),.dst_data(coherent_audio));
wire[15:0]samples[1:0];assign samples[0]=coherent_audio[15:0];assign samples[1]=coherent_audio[31:16];
reg[31:0]audio_fraction=0;reg clk_audio=0;
wire[32:0]audio_next={1'b0,audio_fraction}+33'd5553089;
always @(posedge clk_pixel)begin
 audio_fraction<=audio_next[31:0];if(audio_next[32])clk_audio<=~clk_audio;
 if(!pixel_resetn)begin audio_fraction<=0;clk_audio<=0;end
end
wire[2:0]tmds;wire tmds_clock;
// Restore the standard 720p HDMI raster used by the original SMSTang,
// the shared IOSys design. Active picture, sync geometry, and the
// 74.25 MHz pixel clock remain unchanged. ce_pix and all SMS/core timing
// enables remain untouched.
// 1650 x 750 at 74.25 MHz = exactly 60.0000000 Hz.
hdmi #(.VIDEO_ID_CODE(4),.DVI_OUTPUT(0),.VIDEO_REFRESH_RATE(59.92736),
 .FRAME_WIDTH_OVERRIDE(1652),.FRAME_HEIGHT_OVERRIDE(750),
 .IT_CONTENT(1),.AUDIO_RATE(48000),
 .AUDIO_BIT_WIDTH(16),.START_X(0),.START_Y(0)) hdmi_out(
 .clk_pixel_x5(clk_5x_pixel),.clk_pixel(clk_pixel),.clk_audio(clk_audio),.rgb(rgb),
 .reset(!pixel_resetn),.reset_serializer(!pixel_resetn),.audio_sample_word(samples),
 .tmds(tmds),.tmds_clock(tmds_clock),.cx(cx),.cy(cy),.frame_width(),.frame_height());
ELVDS_OBUF tmds_buffers[3:0](.I({clk_pixel,tmds}),.O({tmds_clk_p,tmds_d_p}),.OB({tmds_clk_n,tmds_d_n}));
endmodule
