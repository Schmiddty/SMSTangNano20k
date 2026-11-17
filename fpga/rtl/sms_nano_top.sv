module sms_nano_top(
 input sys_clk,s1,reset2,UART_RXD,output UART_TXD,output[1:0]led,
 output O_sdram_clk,O_sdram_cke,O_sdram_cs_n,O_sdram_cas_n,O_sdram_ras_n,O_sdram_wen_n,
 inout[31:0]IO_sdram_dq,output[10:0]O_sdram_addr,output[1:0]O_sdram_ba,output[3:0]O_sdram_dqm,
 output sd_clk,inout sd_cmd,input sd_dat0,output sd_dat1,sd_dat2,sd_dat3,
 output flash_spi_cs_n,flash_spi_mosi,flash_spi_clk,flash_spi_wp_n,flash_spi_hold_n,input flash_spi_miso,
 output joy1_strb,joy1_clk,input joy1_data,output joy2_strb,joy2_clk,input joy2_data,
 output ds_clk,ds_mosi,ds_cs,input ds_miso,output ds_clk2,ds_mosi2,ds_cs2,input ds_miso2,
 output tmds_clk_n,tmds_clk_p,output[2:0]tmds_d_n,tmds_d_p
);
wire clk,hclk,hclk5,main_locked,hdmi_locked,resetn,pixel_resetn;
wire running,fault;
sms_nano_pll main_pll(.clkin(sys_clk),.clkout(clk),.clkoutp(O_sdram_clk),.clkoutd3(),.lock(main_locked));
gowin_pll_hdmi video_pll(.clkin(sys_clk),.clkout(hclk5),.lock(hdmi_locked));
CLKDIV #(.DIV_MODE(5),.GSREN("true"))video_div(.HCLKIN(hclk5),.CLKOUT(hclk),.RESETN(1'b1),.CALIB(1'b0));
// Allow clocked configuration startup without gating all I/O on
// unused external reset pins or a PLL LOCK indication. Hold for ~1ms first.
wire startup_ready;
sms_nano_startup startup(.clk(clk),.ready(startup_ready));
reset_release main_reset(.clk(clk),.async_resetn(startup_ready),.resetn(resetn));
reset_release pixel_reset(.clk(hclk),.async_resetn(resetn && hdmi_locked),.resetn(pixel_resetn));
// The shared IOSys owns the SPI flash and SD card pins.
wire[11:0]pad1,pad2,ds1,ds2;
wire[11:0]hid1=12'd0,hid2=12'd0;
controller_snes #(.FREQ(64_800_000))snes1(.clk(clk),.resetn(resetn),.buttons(pad1),.joy_strb(joy1_strb),.joy_clk(joy1_clk),.joy_data(joy1_data));
controller_snes #(.FREQ(64_800_000))snes2(.clk(clk),.resetn(resetn),.buttons(pad2),.joy_strb(joy2_strb),.joy_clk(joy2_clk),.joy_data(joy2_data));
controller_ds2 #(.FREQ(64_800_000))dualshock1(.clk(clk),.snes_buttons(ds1),.ds_clk(ds_clk),.ds_miso(ds_miso),.ds_mosi(ds_mosi),.ds_cs(ds_cs));
controller_ds2 #(.FREQ(64_800_000))dualshock2(.clk(clk),.snes_buttons(ds2),.ds_clk(ds_clk2),.ds_miso(ds_miso2),.ds_mosi(ds_mosi2),.ds_cs(ds_cs2));
wire overlay,loading,load_valid,load_ready;
// This integration targets the SMS mode. The shared IOSys firmware controls ROM selection/loading;
// PAL/Game Gear options remain fixed to NTSC SMS in this release.
wire pal=1'b0;
wire game_gear=1'b0;
wire [7:0] gamegear_top; // Driven by sms_nano_core; do not tie off the core output.
wire [10:0] overlay_x; wire [9:0] overlay_y; wire [15:0] overlay_color;
wire [7:0] load_data;
wire iosys_rv_valid,iosys_rv_ready; wire [22:0] iosys_rv_addr; wire [31:0] iosys_rv_wdata,iosys_rv_rdata; wire [3:0] iosys_rv_wstrb;
wire flash_loaded_debug,cpu_started_debug;
wire iosys_flash_cs_n,iosys_flash_mosi,iosys_flash_clk,iosys_flash_wp_n,iosys_flash_hold_n;
wire iosys_sd_clk,iosys_sd_dat1,iosys_sd_dat2,iosys_sd_dat3;
// The shared PicoRV32 IOSys provides the SD ROM menu, ROM streamer, OSD, and .bin core-switch path.
iosys #(.FREQ(64_800_000), .CORE_ID(5)) menu_core_switch (
 .clk(clk), .hclk(hclk), .resetn(resetn),
 .overlay(overlay), .overlay_x(overlay_x), .overlay_y(overlay_y), .overlay_color(overlay_color),
 .joy1(pad1|ds1), .joy2(pad2|ds2),
 .rom_loading(loading), .rom_do(load_data), .rom_do_valid(load_valid), .rom_stream_ready(load_ready),
 .rv_valid(iosys_rv_valid), .rv_ready(iosys_rv_ready), .rv_addr(iosys_rv_addr),
 .rv_wdata(iosys_rv_wdata), .rv_wstrb(iosys_rv_wstrb), .rv_rdata(iosys_rv_rdata), .ram_busy(!ram_ready),
 .flash_loaded_debug(flash_loaded_debug), .cpu_started_debug(cpu_started_debug),
 .flash_spi_cs_n(iosys_flash_cs_n), .flash_spi_miso(flash_spi_miso), .flash_spi_mosi(iosys_flash_mosi),
 .flash_spi_clk(iosys_flash_clk), .flash_spi_wp_n(iosys_flash_wp_n), .flash_spi_hold_n(iosys_flash_hold_n),
 .uart_rx(UART_RXD), .uart_tx(UART_TXD),
 .sd_clk(iosys_sd_clk), .sd_cmd(sd_cmd), .sd_dat0(sd_dat0), .sd_dat1(iosys_sd_dat1), .sd_dat2(iosys_sd_dat2), .sd_dat3(iosys_sd_dat3)
);
assign flash_spi_cs_n=iosys_flash_cs_n;
assign flash_spi_mosi=iosys_flash_mosi;
assign flash_spi_clk=iosys_flash_clk;
assign flash_spi_wp_n=iosys_flash_wp_n;
assign flash_spi_hold_n=iosys_flash_hold_n;
assign sd_clk=iosys_sd_clk;
assign sd_dat1=iosys_sd_dat1;
assign sd_dat2=iosys_sd_dat2;
assign sd_dat3=iosys_sd_dat3;
wire unused_core_rv_ready;
wire rom_rd,save_rd,save_we,cpu_wait_n,ram_ready,wait_rom,wait_save;
wire[21:0]rom_addr;wire[7:0]rom_data,save_din,save_dout;wire[14:0]save_addr;
wire ram_req,ram_ack,ram_wr;wire[22:0]ram_addr;wire[7:0]ram_din,ram_dout;
sms_nano_memory memory(
 .clk(clk),.resetn(resetn),.loading(loading),.load_valid(load_valid),.load_data(load_data),
 .rom_rd(rom_rd),.rom_addr(rom_addr),.rom_data(rom_data),
 .save_rd(save_rd),.save_we(save_we),.save_addr(save_addr),.save_din(save_din),.save_dout(save_dout),
 .cpu_wait_n(cpu_wait_n),.running(running),.wait_rom(wait_rom),.wait_save(wait_save),.fault(fault),.load_ready(load_ready),
 .rv_valid(1'b0),.rv_addr(23'd0),.rv_wdata(32'd0),.rv_wstrb(4'd0),.rv_ready(unused_core_rv_ready),
 .req(ram_req),.wr(ram_wr),.addr(ram_addr),.din(ram_din),.ack(ram_ack),.dout(ram_dout),.ready(ram_ready));
wire ce_cpu,ce_vdp,ce_pix,ce_sp;
// Per-frame diagnostics, sampled at the verified raster boundary.
// Red is total real T80 T2 WAIT insertions; blue is opcode-fetch WAIT count;
// magenta is the longest consecutive opcode-fetch WAIT run across T2 samples.
reg [15:0] frame_cpu_pulses=0, frame_stall_pulses=0;
reg [15:0] frame_m1_waits=0, frame_mem_waits=0, frame_io_waits=0;
reg [15:0] frame_m1_run=0, frame_m1_max_run=0;
reg [15:0] last_cpu_pulses=0, last_stall_pulses=0;
reg [15:0] last_m1_waits=0, last_mem_waits=0, last_io_waits=0;
reg [15:0] last_m1_max_run=0;
// Raw T80 hierarchy capture: WAIT-low M1 samples grouped by actual T-state.
reg [15:0] frame_raw_m1_t1=0, frame_raw_m1_t2=0, frame_raw_m1_t3=0;
reg [15:0] last_raw_m1_t1=0, last_raw_m1_t2=0, last_raw_m1_t3=0;
// Measure the physical WAIT-low duration in system-clock cycles while the
// T80 is in an M1 fetch's T2 state. These are NOT CPU-enable samples.
reg [23:0] frame_m1_wait_sysclks=0;
reg [15:0] frame_m1_wait_run_sysclks=0;
reg [15:0] frame_m1_wait_max_sysclks=0;
// 24-bit event counter avoids the 16-bit saturation seen in Fix37E.
reg [23:0] frame_m1_wait_assertions=0, last_m1_wait_assertions=0;
reg [23:0] last_m1_wait_sysclks=0;
reg [15:0] last_m1_wait_max_sysclks=0;
// Completed 32-frame block statistics for per-frame M1/T2 WAIT assertions.
reg [4:0] stat_frames=0;
reg [28:0] stat_event_sum=0;
reg [23:0] stat_event_min=24'hffffff, stat_event_max=0;
reg [23:0] last_event_min=0, last_event_max=0, last_event_avg=0;
// Most-recent 32 completed frames as compact fixed-scale graph buckets.
// Each bucket stores count[11:4], representing 0..4080 events in steps of 16.
reg [7:0] event_history [0:31];
wire [255:0] event_history_flat;
genvar hist_i;
generate for (hist_i=0; hist_i<32; hist_i=hist_i+1) begin: EVENT_HISTORY_PACK
 assign event_history_flat[hist_i*8 +: 8] = event_history[hist_i];
end endgenerate
integer hist_reset_i;
wire [23:0] frame_event_count_final = frame_m1_wait_assertions +
    ((m1_wait_sysclk && !m1_wait_active_d && frame_m1_wait_assertions!=24'hffffff) ? 24'd1 : 24'd0);
wire [28:0] stat_event_sum_next = stat_event_sum + {5'd0,frame_event_count_final};
wire [23:0] stat_event_min_next = (frame_event_count_final < stat_event_min) ? frame_event_count_final : stat_event_min;
wire [23:0] stat_event_max_next = (frame_event_count_final > stat_event_max) ? frame_event_count_final : stat_event_max;
reg m1_wait_active_d=0;
wire m1_wait_sysclk = running && !cpu_wait_n && !z80_debug_m1_n &&
                      (z80_debug_mcycle==3'd1) && (z80_debug_tstate==3'd2);
always @(posedge clk) begin
 if (!resetn || !running) begin
  frame_cpu_pulses<=0; frame_stall_pulses<=0;
  frame_m1_waits<=0; frame_mem_waits<=0; frame_io_waits<=0;
  frame_m1_run<=0; frame_m1_max_run<=0;
  last_cpu_pulses<=0; last_stall_pulses<=0;
  last_m1_waits<=0; last_mem_waits<=0; last_io_waits<=0;
  last_m1_max_run<=0;
  frame_raw_m1_t1<=0; frame_raw_m1_t2<=0; frame_raw_m1_t3<=0;
  last_raw_m1_t1<=0; last_raw_m1_t2<=0; last_raw_m1_t3<=0;
  frame_m1_wait_sysclks<=0; frame_m1_wait_run_sysclks<=0;
  frame_m1_wait_max_sysclks<=0; frame_m1_wait_assertions<=0;
  last_m1_wait_sysclks<=0; last_m1_wait_max_sysclks<=0;
  last_m1_wait_assertions<=0; m1_wait_active_d<=0;
  stat_frames<=0; stat_event_sum<=0; stat_event_min<=24'hffffff; stat_event_max<=0;
  last_event_min<=0; last_event_max<=0; last_event_avg<=0;
  for (hist_reset_i=0; hist_reset_i<32; hist_reset_i=hist_reset_i+1)
   event_history[hist_reset_i]<=8'd0;
 end else begin
  if (ce_cpu) frame_cpu_pulses<=frame_cpu_pulses+1'b1;
  if (z80_wait_stall) frame_stall_pulses<=frame_stall_pulses+1'b1;
  // Count only T2 samples. T1/T3 CPU enables are not WAIT opportunities
  // and must not reset a burst between repeated WAIT-held T2 states.
  if (z80_wait_t2_sample) begin
   if (z80_wait_m1) begin
    frame_m1_waits<=frame_m1_waits+1'b1;
    frame_m1_run<=frame_m1_run+1'b1;
    if ((frame_m1_run+16'd1)>frame_m1_max_run)
     frame_m1_max_run<=frame_m1_run+16'd1;
   end else frame_m1_run<=0;
  end
  if (z80_wait_mem) frame_mem_waits<=frame_mem_waits+1'b1;
  if (z80_wait_io) frame_io_waits<=frame_io_waits+1'b1;
  // Count every 64.8 MHz system-clock tick for which the real cartridge WAIT
  // is low during an M1/T2 fetch. Track each contiguous assertion separately.
  if (m1_wait_sysclk) begin
   if (frame_m1_wait_sysclks != 24'hffffff)
    frame_m1_wait_sysclks<=frame_m1_wait_sysclks+1'b1;
   if (frame_m1_wait_run_sysclks != 16'hffff)
    frame_m1_wait_run_sysclks<=frame_m1_wait_run_sysclks+1'b1;
   if ((frame_m1_wait_run_sysclks+16'd1)>frame_m1_wait_max_sysclks)
    frame_m1_wait_max_sysclks<=frame_m1_wait_run_sysclks+16'd1;
   if (!m1_wait_active_d && frame_m1_wait_assertions != 24'hffffff)
    frame_m1_wait_assertions<=frame_m1_wait_assertions+1'b1;
  end else frame_m1_wait_run_sysclks<=0;
  m1_wait_active_d<=m1_wait_sysclk;
  // Capture the raw T80 state, not the derived T2 qualifier. These counters
  // expose whether WAIT is low in T1/T2/T3 while the core identifies an M1.
  if (ce_cpu && !cpu_wait_n && z80_debug_mcycle==3'd1 && !z80_debug_m1_n) begin
   case (z80_debug_tstate)
    3'd1: frame_raw_m1_t1<=frame_raw_m1_t1+1'b1;
    3'd2: frame_raw_m1_t2<=frame_raw_m1_t2+1'b1;
    3'd3: frame_raw_m1_t3<=frame_raw_m1_t3+1'b1;
   endcase
  end
  if (ce_pix && x==9'd487 && y==9'd511) begin
   // Shift one completed per-frame count into the 32-frame history.
   for (hist_reset_i=0; hist_reset_i<31; hist_reset_i=hist_reset_i+1)
    event_history[hist_reset_i]<=event_history[hist_reset_i+1];
   event_history[31]<=frame_event_count_final[11:4];
   last_cpu_pulses<=frame_cpu_pulses + (ce_cpu ? 16'd1 : 16'd0);
   last_stall_pulses<=frame_stall_pulses + (z80_wait_stall ? 16'd1 : 16'd0);
   last_m1_waits<=frame_m1_waits + (z80_wait_m1 ? 16'd1 : 16'd0);
   last_mem_waits<=frame_mem_waits + (z80_wait_mem ? 16'd1 : 16'd0);
   last_io_waits<=frame_io_waits + (z80_wait_io ? 16'd1 : 16'd0);
   last_m1_max_run<=z80_wait_m1 && (frame_m1_run+16'd1)>frame_m1_max_run ?
                    frame_m1_run+16'd1 : frame_m1_max_run;
   last_raw_m1_t1<=frame_raw_m1_t1; last_raw_m1_t2<=frame_raw_m1_t2; last_raw_m1_t3<=frame_raw_m1_t3;
   last_m1_wait_sysclks<=frame_m1_wait_sysclks + (m1_wait_sysclk && frame_m1_wait_sysclks!=24'hffffff ? 24'd1 : 24'd0);
   last_m1_wait_max_sysclks<=((m1_wait_sysclk && (frame_m1_wait_run_sysclks+16'd1)>frame_m1_wait_max_sysclks) ? frame_m1_wait_run_sysclks+16'd1 : frame_m1_wait_max_sysclks);
   last_m1_wait_assertions<=frame_event_count_final;
   // Publish min/max/average for each completed block of 32 frames.
   if (stat_frames==5'd31) begin
    last_event_min<=stat_event_min_next;
    last_event_max<=stat_event_max_next;
    last_event_avg<=stat_event_sum_next[28:5];
    stat_frames<=0; stat_event_sum<=0; stat_event_min<=24'hffffff; stat_event_max<=0;
   end else begin
    stat_frames<=stat_frames+1'b1;
    stat_event_sum<=stat_event_sum_next;
    stat_event_min<=stat_event_min_next;
    stat_event_max<=stat_event_max_next;
   end
   frame_m1_wait_sysclks<=0; frame_m1_wait_run_sysclks<=0;
   frame_m1_wait_max_sysclks<=0; frame_m1_wait_assertions<=0; m1_wait_active_d<=0;
   frame_cpu_pulses<=0; frame_stall_pulses<=0;
   frame_m1_waits<=0; frame_mem_waits<=0; frame_io_waits<=0;
   frame_m1_run<=0; frame_m1_max_run<=0;
   frame_raw_m1_t1<=0; frame_raw_m1_t2<=0; frame_raw_m1_t3<=0;
  end
 end
end
sms_nano_ce enables(.clk(clk),.resetn(resetn&&running),.enable(running&&!overlay),
 .ce_cpu(ce_cpu),.ce_vdp(ce_vdp),.ce_pix(ce_pix),.ce_sp(ce_sp));
wire[8:0]x,y,height;wire[11:0]color;wire[15:0]audio_l,audio_r;
wire z80_wait_stall,z80_wait_t2_sample,z80_wait_m1,z80_wait_mem,z80_wait_io;
wire [2:0] z80_debug_mcycle,z80_debug_tstate; wire z80_debug_m1_n;
sms_nano_core #(.EXTERNAL_SAVE_RAM(1))engine(
 .clk(clk),.resetn(resetn&&running),.ce_cpu(ce_cpu),.ce_vdp(ce_vdp),.ce_pix(ce_pix),.ce_sp(ce_sp),
 .pal(pal),.region(!game_gear),.game_gear(game_gear),.joy1(pad1|ds1|hid1),.joy2(pad2|ds2|hid2),
 .memory_wait_n(cpu_wait_n),.debug_wait_stall(z80_wait_stall),.debug_wait_t2_sample(z80_wait_t2_sample),.debug_wait_m1(z80_wait_m1),.debug_wait_mem(z80_wait_mem),.debug_wait_io(z80_wait_io),
 .debug_MCycle(z80_debug_mcycle),.debug_TState(z80_debug_tstate),.debug_M1_n(z80_debug_m1_n),.rom_rd(rom_rd),.rom_addr(rom_addr),.rom_data(rom_data),
 .save_rd(save_rd),.save_write(save_we),.save_address(save_addr),.save_wdata(save_din),.save_rdata(save_dout),
 .x(x),.y(y),.frame_height(height),.gamegear_top(gamegear_top),.color(color),.audio_l(audio_l),.audio_r(audio_r));
wire bg_req = 1'b0;
wire bg_ack;
wire bg_valid;
wire [19:0] bg_addr = 20'd0;
wire [31:0] bg_data;
wire [8:0] bg_word;
// The shared IOSys owns the 32-bit SDRAM client. The legacy artwork channel is disabled.
sms_nano_sdram #(.FREQ(64_800_000))ram(
 .clk(clk),.resetn(resetn),.req(ram_req),.wr(ram_wr),.addr(ram_addr),.din(ram_din),
 .ack(ram_ack),.dout(ram_dout),.ready(ram_ready),
 .rv_valid(iosys_rv_valid),.rv_addr(iosys_rv_addr),.rv_wdata(iosys_rv_wdata),.rv_wstrb(iosys_rv_wstrb),
 .rv_ready(iosys_rv_ready),.rv_rdata(iosys_rv_rdata),
 .bg_enable(1'b0),.bg_req(bg_req),.bg_addr(bg_addr),.bg_ack(bg_ack),.bg_valid(bg_valid),.bg_data(bg_data),.bg_word(bg_word),
 .sdram_dq(IO_sdram_dq),.sdram_a(O_sdram_addr),.sdram_ba(O_sdram_ba),.sdram_dqm(O_sdram_dqm),
 .sdram_cs_n(O_sdram_cs_n),.sdram_ras_n(O_sdram_ras_n),.sdram_cas_n(O_sdram_cas_n),.sdram_we_n(O_sdram_wen_n),.sdram_cke(O_sdram_cke));
sms_nano_hdmi video(
 .debug_enable(1'b0),
 .clk(clk),.resetn(resetn),.pixel_resetn(pixel_resetn),.clk_pixel(hclk),.clk_5x_pixel(hclk5),
 .game_gear(game_gear),.gamegear_top(gamegear_top),.ce_pix(ce_pix),.x(x),.y(y),.color(color),.height(height),
 .audio_l(overlay?16'd0:audio_l),.audio_r(overlay?16'd0:audio_r),
 .overlay(overlay),.overlay_x(overlay_x),.overlay_y(overlay_y),.overlay_color(overlay_color),
 .background_rgb(24'd0),.background_valid(1'b0),
 .debug_cpu_count(last_cpu_pulses),.debug_stall_count(last_stall_pulses),
 .debug_m1_wait_count(last_m1_waits),.debug_mem_wait_count(last_mem_waits),.debug_io_wait_count(last_io_waits),
 .debug_m1_max_run(last_m1_max_run),
 .debug_raw_m1_t1(last_raw_m1_t1),.debug_raw_m1_t2(last_raw_m1_t2),.debug_raw_m1_t3(last_raw_m1_t3),
 .debug_m1_wait_sysclks(last_m1_wait_sysclks),.debug_m1_wait_max_sysclks(last_m1_wait_max_sysclks),
 .debug_m1_wait_assertions(last_m1_wait_assertions[15:0]),
 .debug_m1_wait_assertions_hi({8'd0,last_m1_wait_assertions[23:16]}),
 .debug_m1_event_min_lo(last_event_min[15:0]),.debug_m1_event_min_hi({8'd0,last_event_min[23:16]}),
 .debug_m1_event_max_lo(last_event_max[15:0]),.debug_m1_event_max_hi({8'd0,last_event_max[23:16]}),
 .debug_m1_event_avg_lo(last_event_avg[15:0]),.debug_m1_event_avg_hi({8'd0,last_event_avg[23:16]}),
 .debug_event_history(event_history_flat),
 .debug_current_event_count(last_m1_wait_assertions),.debug_block_max_event_count(last_event_max),
 .tmds_clk_n(tmds_clk_n),.tmds_clk_p(tmds_clk_p),.tmds_d_n(tmds_d_n),.tmds_d_p(tmds_d_p));
assign led=~{fault,running};
endmodule
