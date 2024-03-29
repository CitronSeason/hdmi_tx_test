`default_nettype none

module dvi_out (
    input  wire clock,
    input  wire reset,

    input  wire  [23:0] video_data,     /* 映像入力: データ */
    input  wire         video_de,       /* 映像入力: データ有効 */
    input  wire         video_hsync,    /* 映像入力: 水平同期 */
    input  wire         video_vsync,    /* 映像入力: 垂直同期 */

    output logic [9:0]  dvi_clock,      /* DVIクロック出力 */
    output logic [9:0]  dvi_data0,      /* DVIデータ0出力  */
    output logic [9:0]  dvi_data1,      /* DVIデータ1出力  */
    output logic [9:0]  dvi_data2       /* DVIデータ2出力  */
);
/* DVIクロック出力は常に5bit H, 5bit Lのパルス */
assign dvi_clock = 10'b00000_11111;

/* ビデオ信号のレジスタ用の型 */
typedef struct packed {
    logic           de;     /* データ有効 */
    logic           hsync;  /* 水平同期 */
    logic           vsync;  /* 垂直同期 */
    logic [26:0]    data;   /* 遷移時間最小化後のデータ */
} video_reg_t;

/* ビデオ信号のレジスタ段数 */
localparam VIDEO_REGS_DEPTH = 1;

/*
 * @brief 2ビットのビット列に含まれる'1'のビットの個数を計算する
 * @param in '1'のビットの個数を計算する長さ2のビット列
 * @return 入力のビット列に含まれる'1'のビットの個数
 */
function automatic logic [1:0] popCount2(input logic [1:0] in);
    popCount2 = {1'b0, in[0]} + {1'b0, in[1]};
endfunction

/*
 * @brief 4ビットのビット列に含まれる'1'のビットの個数を計算する
 * @param in '1'のビットの個数を計算する長さ4のビット列
 * @return 入力のビット列に含まれる'1'のビットの個数
 */
function automatic logic [2:0] popCount4(input logic [3:0] in);
    popCount4 = {1'b0, popCount2(in[3:2])} + {1'b0, popCount2(in[1:0])};
endfunction

/*
 * @brief 8ビットのビット列に含まれる'1'のビットの個数を計算する
 * @param in '1'のビットの個数を計算する長さ8のビット列
 * @return 入力のビット列に含まれる'1'のビットの個数
 */
function automatic logic [3:0] popCount8(input logic [9:0] in);
    popCount8 = {1'b0, popCount4(in[7:4])} + {1'b0, popCount4(in[3:0])};
endfunction

/*
 * @brief 8ビットの入力値に対して遷移回数が最小になるようにエンコーディングする
 */
function automatic logic [8:0] transitionMinimized(input logic [7:0] in);
begin
    logic [3:0] pop_count;
    logic       xnor_process;
    logic [7:0] bits;

    pop_count = popCount8(in);
    xnor_process = pop_count > 4'd4 || (pop_count == 4'd4 && !in[0]);

    bits[0] = in[0];
    for (int i = 0; i < 8; i++) begin
        bits[i] = (bits[i-1] ^ bits[i]) ^ xnor_process;
    end
    transitionMinimized = {!xnor_process, bits};
end
endfunction

/* DC Balancing処理の出力を表す構造体 */
typedef struct packed {
    logic [9:0] out;
    logic [7:0] counter;
} dc_balancing_t;

/*
 * @brief DC均一化のためのエンコーディング処理を行う
 * @param in エンコード対象の9ビットデータ。遷移最小化エンコード済みデータ
 * @param counter アクティブ区間中の現在までの1の個数と0の個数のカウンタ
 * @return DC均一化後の10ビットのTMDSキャラクタ
 */
function automatic dc_balancing_t dcBalancing (input logic [8:0] in, logic [7:0] counter);
begin
    logic [3:0] n1;
    logic [7:0] n0n1;
    dc_balancing_t result;

    /* 入力のうち先頭のXOR/XNOR選択ビットを除いたデータの1のビット数を計算する */
    n1 = popCount8(in[7:0]);
    /* 入力8ビットの0の個数 - 1の個数を計算 (n0 - n1 = 8 - 2n1 = 8 - (n1 << 1)) */
    n0n1 = 8'd8 - {3'b000, n1, 1'b0};

    /* カウンタが0、もしくは入力の0と1の個数が等しい */
    if(counter == '0 || n0n1 == '0) begin
        result.out = {!in[8], in[8], in[8] ? in[7:0] : ~in[7:0]};
        result.counter = in[8] ? counter + n0n1 + 8'd2 : counter + n0n1;
    end
    /* (counter < 0 && (n0-n1) > 0 || counter > 0 && (n0-n1) < 0) */
    else if ( (!counter[7] && n0n1[7]) || (counter[7] && !n0n1[7])) begin
        result.out = {1'b1, in[8], ~in[7:0]};
        result.counter = in[8] ? counter - n0n1 + 8'd2 : counter + n0n1;
    end
    else begin
        result.out = {1'b0, in[8], in[7:0]};
        result.counter = in[8] ? counter - n0n1 : counter - n0n1 - 8'd2;
    end
    dcBalancing = result;
end
endfunction

/*
 * @brief 分キング機関のエンコーディング処理を行う
 * @param in エンコード対象の2ビット・データ。
 * @return ブランキング機関のエンコーディング結果の10bit TMDSキャラクタ
 */
function automatic logic [9:0] encodeBlanking (input logic [1:0] in);
begin
    case (in)
        2'b00: encodeBlanking = 10'b1101010100;
        2'b01: encodeBlanking = 10'b0010101011;
        2'b10: encodeBlanking = 10'b0101010100;
        2'b11: encodeBlanking = 10'b1010101011;
    endcase
end
endfunction

/* TMDSエンコード処理を2サイクルに分けるために映像信号を保持するレジスタ */
video_reg_t [VIDEO_REGS_DEPTH-1:0] video_regs;
/* レジスタの入力信号 */
video_reg_t video_reg_in;
/* レジスタからの出力信号 */
video_reg_t video;
assign video = video_regs[0];

logic [7:0] counter0;
logic [7:0] counter1;
logic [7:0] counter2;
assign video_reg_in.de      = video_de;
assign video_reg_in.hsync   = video_hsync;
assign video_reg_in.vsync   = video_vsync;

assign video_reg_in.data    = {transitionMinimized(video_data[23:16]), 
                               transitionMinimized(video_data[15: 8]),
                               transitionMinimized(video_data[ 7: 0])};

always_ff @( posedge clock ) begin 
    if( reset ) begin
        video_reg_t reg_default;
        reg_default.de      = 0;
        reg_default.data    = 0;
        reg_default.hsync   = 1;
        reg_default.vsync   = 1;
        for(int i = 0; i< VIDEO_REGS_DEPTH; i++) begin
            video_regs[i] <= reg_default;
        end
    end
    else begin
        video_regs[VIDEO_REGS_DEPTH-1] <= video_reg_in;
        for(int i = 0; i < VIDEO_REGS_DEPTH-1; i++) begin
            video_regs[i] <= video_regs[i+1];
        end
    end
end

always_ff @(posedge clock) begin
    if( reset ) begin
        counter0 <= 0;
        counter1 <= 0;
        counter2 <= 0;
        dvi_data0 <= 0;
        dvi_data1 <= 0;
        dvi_data2 <= 0;
    end
    else begin
        /* ブランキング区間 */
        if( !video.de) begin
            dvi_data0 <= encodeBlanking({video.vsync, video.hsync});
            dvi_data1 <= encodeBlanking({2'b00});
            dvi_data2 <= encodeBlanking({2'b00});
            /* DC均一化のカウンタリセット */
            counter0 <= 0;
            counter1 <= 0;
            counter2 <= 0;
        end
        /* アクティブ区間 */
        else begin
            /* チャネル0 */
            begin
                dc_balancing_t result;
                result = dcBalancing(video.data[8:0], counter0);
                dvi_data0 <= result.out;
                counter0  <= result.counter;
            end
            /* チャネル1 */
            begin
                dc_balancing_t result;
                result = dcBalancing(video.data[17:9], counter1);
                dvi_data1 <= result.out;
                counter1  <= result.counter;
            end
            /* チャネル2 */
            begin
                dc_balancing_t result;
                result = dcBalancing(video.data[26:18], counter2);
                dvi_data2 <= result.out;
                counter2  <= result.counter;
            end
        end
    end
end

endmodule
`default_nettype wire