// Byte-access SDR SDRAM controller for the Nano20K integrated 8MiB x32 memory.
// Single synchronous request-toggle channel; hold request payload until ack.
// Address: bank[22:21], row[20:10], column[9:2], byte lane[1:0].
// Phase-shifted SDRAM clock is supplied by the future board PLL wrapper.
// Conservative BL1 / CL2 timing; controller supports 27..66.7MHz only.
module sms_nano_sdram #(
    parameter integer FREQ=54_000_000,
    parameter integer INIT_CYCLES=(FREQ+4999)/5000,
    parameter integer REFRESH_CYCLES=FREQ/128_000
)(
    input wire clk, resetn,
    input wire bg_enable,bg_req,input wire[19:0]bg_addr,
    output reg bg_ack=0,bg_valid=0,output reg[31:0]bg_data=0,output reg[8:0]bg_word=0,
    input wire req, wr,
    input wire [22:0] addr,
    input wire [7:0] din,
    output reg ack=0,
    output reg [7:0] dout=0,
    // PicoRV32 IOSys 32-bit memory port (firmware/softcore RAM).
    input wire rv_valid,
    input wire [22:0] rv_addr,
    input wire [31:0] rv_wdata,
    input wire [3:0] rv_wstrb,
    output reg rv_ready=0,
    output reg [31:0] rv_rdata=0,
    output reg ready=0,
    inout wire [31:0] sdram_dq,
    output reg [10:0] sdram_a=0,
    output reg [1:0] sdram_ba=0,
    output reg [3:0] sdram_dqm=4'hf,
    output wire sdram_cs_n,sdram_ras_n,sdram_cas_n,sdram_we_n,
    output wire sdram_cke
);
localparam [3:0] NOP=4'b0111, PRE=4'b0010, REF=4'b0001,
                 MODE=4'b0000, ACT=4'b0011, READ=4'b0101, WRITE=4'b0100;
reg [3:0] command=NOP;
assign {sdram_cs_n,sdram_ras_n,sdram_cas_n,sdram_we_n}=command;
assign sdram_cke=1'b1;
reg drive=0;
reg [31:0] dq_out=0;
assign sdram_dq=drive?dq_out:32'bz;
localparam integer T_RCD=2, T_RP=2, T_RFC=5, T_WR=2;
localparam [3:0] POWERUP=0, INIT_PRE=1, INIT_REF1=2, INIT_REF2=3,
                 INIT_MODE=4, IDLE=5, ACT_WAIT=6, READ_WAIT=7,
                 WRITE_HOLD=8, WRITE_WAIT=9, REF_WAIT=10,
                 BG_ACT=11,BG_READ=12,BG_DRAIN=13,BG_PRE=14;
reg [3:0] state=POWERUP;
reg [$clog2(INIT_CYCLES+1)-1:0] init_count=0;
reg [$clog2(REFRESH_CYCLES+1)-1:0] refresh_count=0;
reg [3:0] wait_count=0;
reg [22:0] address=0;
reg [7:0] data=0;
reg writing=0, request=0;
reg is_rv=0, rv_seen=0, rv_active=0;
// One-word read cache: SDRAM returns a full 32-bit word even though the SMS
// interface requests one byte at a time. Reuse adjacent lanes on sequential
// Z80 fetches instead of paying ACT/READ/auto-precharge for every byte.
reg cache_valid=0;
reg [20:0] cache_tag=0;
reg [31:0] cache_data=0;
reg [22:0] rv_saved_addr=0;
reg [31:0] rv_saved_wdata=0;
reg [3:0] rv_saved_wstrb=0;
reg [1:0] rv_index=0;
function automatic [1:0] first_rv_lane(input [3:0] strobe);
    begin
        if(strobe[0]) first_rv_lane=2'd0;
        else if(strobe[1]) first_rv_lane=2'd1;
        else if(strobe[2]) first_rv_lane=2'd2;
        else first_rv_lane=2'd3;
    end
endfunction
function automatic [2:0] next_rv_lane(input [3:0] strobe,input [1:0] current_lane);
    begin
        if(current_lane<1 && strobe[1]) next_rv_lane=3'd1;
        else if(current_lane<2 && strobe[2]) next_rv_lane=3'd2;
        else if(current_lane<3 && strobe[3]) next_rv_lane=3'd3;
        else next_rv_lane=3'd4;
    end
endfunction
wire [2:0] rv_next_lane=next_rv_lane(rv_saved_wstrb,rv_index);
reg[22:0]bg_address=0;reg[8:0]bg_issued=0,bg_received=0;
reg[2:0]bg_pipe=0;reg bg_target=0;
initial begin
    if(FREQ<27_000_000||FREQ>66_700_000) $fatal(1,"Unsupported SDRAM clock");
end
always @(posedge clk) begin
    command<=NOP;bg_valid<=0;rv_ready<=0;
    if(!rv_valid)rv_seen<=0;
    bg_pipe<={bg_pipe[1:0],1'b0};
    if(bg_pipe[2])begin
        bg_data<=sdram_dq;bg_word<=bg_received;bg_valid<=1;
        bg_received<=bg_received+1'b1;
    end
    if(ready && refresh_count<REFRESH_CYCLES) refresh_count<=refresh_count+1'b1;
    if(wait_count!=0) wait_count<=wait_count-1'b1;
    case(state)
    POWERUP: if(init_count==INIT_CYCLES-1) begin
        command<=PRE;sdram_a<=11'b10000000000;wait_count<=T_RP-1;state<=INIT_PRE;
    end else init_count<=init_count+1'b1;
    INIT_PRE: if(wait_count==0) begin command<=REF;wait_count<=T_RFC-1;state<=INIT_REF1;end
    INIT_REF1: if(wait_count==0) begin command<=REF;wait_count<=T_RFC-1;state<=INIT_REF2;end
    INIT_REF2: if(wait_count==0) begin
        command<=MODE;sdram_ba<=0;sdram_a<=11'h020; // sequential BL1, CAS2
        wait_count<=1;state<=INIT_MODE;
    end
    INIT_MODE: if(wait_count==0) begin ready<=1;refresh_count<=0;state<=IDLE;end
    IDLE: if(refresh_count==REFRESH_CYCLES) begin
        // Refresh has priority so a stream of cartridge requests cannot starve it.
        command<=REF;refresh_count<=0;wait_count<=T_RFC-1;state<=REF_WAIT;
    end else if(bg_enable&&bg_req!=bg_ack)begin
        bg_address<=23'h600000+bg_addr;bg_target<=bg_req;
        bg_issued<=0;bg_received<=0;
        sdram_ba<=2'b11;sdram_a<=bg_addr[19:10];
        command<=ACT;wait_count<=T_RCD-1;state<=BG_ACT;
    end else if(req!=ack) begin
        // The SMS Z80 shares SDRAM with the PicoRV32 firmware. Service a
        // pending cartridge/save request before continuing the next byte of
        // a multi-byte RV access. Reuse any valid lane in the last fetched
        // SDRAM word; otherwise issue a normal byte transaction.
        if(!wr && cache_valid && cache_tag==addr[22:2]) begin
            dout<=cache_data >> (8*addr[1:0]);
            ack<=req;
        end else begin
            if(wr) cache_valid<=0;
            address<=addr;data<=din;writing<=wr;request<=req;is_rv<=0;
            sdram_ba<=addr[22:21];sdram_a<=addr[20:10];
            command<=ACT;wait_count<=T_RCD-1;state<=ACT_WAIT;
        end
    end else if(rv_active) begin
        // RV reads have all-zero WSTRB; writes only issue selected byte lanes.
        // rv_addr is byte-addressed, while WSTRB selects lanes within its aligned word.
        if(rv_saved_wstrb==0 || rv_saved_wstrb[rv_index]) begin
            // Firmware is deliberately not allowed to consume the SMS word cache.
        // The shared IOSys model keeps RISC-V accesses on the lowest-priority path;
        // here each firmware byte proceeds through the normal SDRAM handshake
        // only after pending SMS requests have had first refusal at IDLE.
        if(rv_saved_wstrb[rv_index]) cache_valid<=0;
        address<={rv_saved_addr[22:2],2'b00}+rv_index;
        data<=rv_saved_wdata[rv_index*8 +: 8];
        writing<=rv_saved_wstrb[rv_index];is_rv<=1;
        sdram_ba<=({rv_saved_addr[22:2],2'b00}+rv_index)>>21;
        sdram_a<=({rv_saved_addr[22:2],2'b00}+rv_index)>>10;
        command<=ACT;wait_count<=T_RCD-1;state<=ACT_WAIT;
        end else begin
            // Defensive path for a malformed sparse strobe.
            if(next_rv_lane(rv_saved_wstrb,rv_index)==3'd4)begin rv_active<=0;rv_ready<=1;end
            else rv_index<=rv_next_lane[1:0];
        end
    end else if(rv_valid && !rv_seen) begin
        rv_seen<=1;rv_active<=1;rv_index<=(rv_wstrb==0)?2'd0:first_rv_lane(rv_wstrb);
        rv_saved_addr<=rv_addr;rv_saved_wdata<=rv_wdata;rv_saved_wstrb<=rv_wstrb;
    end
    ACT_WAIT: if(wait_count==0) begin
        sdram_a<={1'b1,2'b00,address[9:2]}; // A10 auto-precharge
        if(writing) begin
            command<=WRITE;sdram_dqm<=~(4'b0001<<address[1:0]);
            dq_out<={4{data}};drive<=1;state<=WRITE_HOLD;
        end else begin
            command<=READ;sdram_dqm<=0;wait_count<=2;state<=READ_WAIT;
        end
    end
    READ_WAIT: if(wait_count==0) begin
        // Only SMS cartridge reads populate the one-word cache. Firmware
        // reads bypass it so the two clients cannot observe each other's
        // cached state or alter the SMS cache's replacement history.
        if(!is_rv) begin
            cache_data<=sdram_dq;
            cache_tag<=address[22:2];
            cache_valid<=1;
        end
        if(is_rv) begin
            rv_rdata[rv_index*8 +: 8]<=sdram_dq >> (8*address[1:0]);
            sdram_dqm<=4'hf;state<=IDLE;
            if(rv_index==3)begin rv_active<=0;rv_ready<=1;end
            else rv_index<=rv_index+1'b1;
        end else begin
            dout<=sdram_dq >> (8*address[1:0]);
            ack<=request;sdram_dqm<=4'hf;state<=IDLE;
        end
    end
    WRITE_HOLD: begin
        drive<=0;sdram_dqm<=4'hf;
        // tWR plus tRP after the sampled WRITE before another ACT or REF.
        wait_count<=T_WR+T_RP-2;state<=WRITE_WAIT;
    end
    WRITE_WAIT: if(wait_count==0) begin
        if(is_rv) begin
            state<=IDLE;
            if(rv_next_lane==3'd4)begin rv_active<=0;rv_ready<=1;end
            else rv_index<=rv_next_lane[1:0];
        end else begin ack<=request;state<=IDLE;end
    end
    REF_WAIT: if(wait_count==0) state<=IDLE;
    BG_ACT: if(wait_count==0)state<=BG_READ;
    BG_READ:begin
        command<=READ;sdram_a<={3'b000,bg_address[9:2]};sdram_dqm<=0;
        bg_pipe[0]<=1;bg_issued<=bg_issued+1'b1;bg_address<=bg_address+4;
        if(bg_issued==319||bg_address[9:2]==255)state<=BG_DRAIN;
    end
    BG_DRAIN:if(bg_pipe==0)begin
        command<=PRE;sdram_a<=11'b10000000000;sdram_dqm<=4'hf;
        wait_count<=T_RP-1;state<=BG_PRE;
    end
    BG_PRE:if(wait_count==0)begin
        if(bg_issued==320)begin bg_ack<=bg_target;state<=IDLE;end
        else begin
            sdram_a<=bg_address[20:10];command<=ACT;
            wait_count<=T_RCD-1;state<=BG_ACT;
        end
    end
    default: state<=POWERUP;
    endcase
    if(!resetn) begin
        bg_ack<=0;bg_valid<=0;bg_data<=0;bg_word<=0;bg_address<=0;
        bg_issued<=0;bg_received<=0;bg_pipe<=0;bg_target<=0;
        state<=POWERUP;init_count<=0;refresh_count<=0;wait_count<=0;
        ack<=0;dout<=0;ready<=0;drive<=0;command<=NOP;
        cache_valid<=0;cache_tag<=0;cache_data<=0;
        is_rv<=0;rv_seen<=0;rv_active<=0;rv_saved_addr<=0;rv_saved_wdata<=0;rv_saved_wstrb<=0;rv_index<=0;rv_ready<=0;rv_rdata<=0;
        sdram_a<=0;sdram_ba<=0;sdram_dqm<=4'hf;
        address<=0;data<=0;writing<=0;request<=0;
    end
end
endmodule
