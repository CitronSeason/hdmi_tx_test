`default_nettype none

module test_pattern_generator #(
    parameter int HSYNC   = 40,
    parameter int HBACK   = 220,
    parameter int HACTIVE = 1280,
    parameter int HFRONT  = 110,
    parameter int VSYNC = 5,
    parameter int VBACK = 20,
    parameter int VACTIVE = 720,
    parameter int VFRONT = 5,
    parameter bit BOUNCE_LOG = 0,   /* ロゴを出力するか */
    parameter int LOGO_COLOR = 0,   /* ロゴの出力色 */
    parameter     LOGO_PATH = "",   /* ロゴデータパス */
    parameter int LOGO_WIDTH = 24,  /* ロゴの幅 */
    parameter int LOGO_HEIGHT = 24  /* ロゴの高さ */
) (
    input wire clock,
    input wire reset,

    output logic [23:0] video_data,     /* ピクセルデータ出力 */
    output logic        video_de,       /* データイネーブル出力 */
    output logic        video_hsync,    /* 垂直同期出力 */
    output logic        video_vsync     /* 水平同期出力 */
);

logic   [23:0] video_data_value;

/* 水平方向最大カウント数 */
localparam int HTOTAL = HSYNC + HBACK + HACTIVE + HFRONT;
/* 垂直方向最大カウント数 */
localparam int VTOTAL = VSYNC + VBACK + VACTIVE + VFRONT;
localparam int HCOUNTER_BITS = $clog2(HTOTAL);
localparam int VCOUNTER_BITS = $clog2(VTOTAL);

typedef logic [HCOUNTER_BITS-1:0] hcounter_t;
typedef logic [VCOUNTER_BITS-1:0] vcounter_t;

/* カウンタ */
hcounter_t hcounter = 0;
vcounter_t vcounter = 0;

localparam int LOGO_STRIDE  = (LOGO_WIDTH + 7) & ~7; /* ロゴ1列の幅 8単位の切り上げ */
localparam int LOGO_BITS    = LOGO_STRIDE*LOGO_HEIGHT;
localparam int LOGO_BYTES   = LOGO_BITS >> 3;

typedef logic [$clog2(LOGO_BITS)-1:0] logo_address_t;

/* ロゴ画像ROM本体、幅8bit 深さLOGO_BYTES */
logic [7:0] logo_memory[LOGO_BYTES-1:0];

/* ロゴの現在の左上XY座標 */
hcounter_t logo_x = 0;
vcounter_t logo_y = 0;
/* ロゴのXY座標進行方向 0: +1, 1: -1 */
logic logo_dx = 0;
logic logo_dy = 0;

/* 現在のロゴ画像内のアドレス 下位3ビット: ビット位置、残り: ROMアドレス */
logo_address_t logo_address = 0;
/* 現在出力中のロゴ画像のアドレスのピクセルデータ8ビット分をメモリから読み出したバッファ */
logic [7:0] logo_pixels = 0;
/* 現在出力中のロゴ画像のピクセルデータ */
logic logo_pixel = 0;
/* 現在出力中の画像がロゴの領域内かどうか */
logic within_logo = 0;

/* ロゴ出力が有効なら、ロゴ画像のメモリ回路を生成 */
if( BOUNCE_LOG ) begin : bounce_logo_memory_load
    initial begin
        /* ロゴ画像のメモリ初期値を`LOGO_PATH`のファイルから読み出す */
        $readmemh(LOGO_PATH, logo_memory);
    end
    always_ff @( posedge clock ) begin 
        if( reset ) begin
            logo_pixels <= 0;
        end
        else begin
            /* 次のアドレスのロゴの画素を読み出す */
            logo_pixels <= logo_memory[(logo_address + 1) >> 3];
        end
    end
end 

always_ff @( posedge clock ) begin
    if ( reset ) begin
        hcounter     <= '0;
        vcounter     <= '0;
        logo_address <= '0;
        video_de     <= '0;
        video_hsync  <= '0;
        video_vsync  <= '0;
        video_data   <= '0;
    end
    else begin
        /* ロゴ範囲内ならアドレスを進める */
        if( within_logo ) begin
            logo_address <= logo_address + 1;
        end
        /* 水平カウンタが右端に到達 */
        if( hcounter == HTOTAL - 1 ) begin
            hcounter <= '0;
            /* 垂直カウンタが下端に到達 */
            if( vcounter == VTOTAL - 1 ) begin
                vcounter <= '0;
                logo_address <= '0;

                /* 次のフレームのロゴ座標を更新 */
                /* ロゴが左端または右端に当たったら移動方向反転 */
                if(  logo_dx && logo_x == 0 || 
                    !logo_dx && logo_x == (HACTIVE - LOGO_WIDTH - 1)) begin
                    logo_dx <= !logo_dx;
                end
                /* ロゴが上端または下端に当たったら移動方向反転 */
                if(  logo_dy && logo_y == 0 ||
                    !logo_dy && logo_y == (VACTIVE - LOGO_HEIGHT -1 )) begin
                        logo_dy <= !logo_dy;
                end
                /* ロゴを移動方向に移動する */
                logo_x <= logo_dx ? logo_x - 1 : logo_x + 1;
                logo_y <= logo_dy ? logo_y - 1 : logo_y + 1;
            end
            else begin
                /* ロゴのアドレスをメモリアドレス単位に切り上げる */
                logo_address <= ( logo_address + logo_address_t'(7) ) & ~logo_address_t'(7);
                /* 垂直カウンタインクリメント */
                vcounter <= vcounter + vcounter_t'(1);
            end
        end
        else begin
            /* 水平カウンタインクリメント */
            hcounter <= hcounter + hcounter_t'(1);
        end

        /* 水平・垂直カウンタが有効画素範囲内ならDEに'1'を出力 */
        video_de <= HSYNC + HBACK <= hcounter && hcounter < HSYNC + HBACK + HACTIVE
                 && VSYNC + VBACK <= vcounter && vcounter < VSYNC + VBACK + VACTIVE;
        video_hsync <= hcounter < HSYNC;
        video_vsync <= vcounter < VSYNC;

        if( BOUNCE_LOGO && within_logo && logo_pixel ) begin
            video_data <= LOGO_COLOR;
        end
        else if( hcounter < HSYNC + HBACK + (HACTIVE*1/7) ) begin
            video_data <= 24'hffffff;
        end
        else if( hcounter < HSYNC + HBACK + (HACTIVE*2/7) ) begin
            video_data <= 24'hff0000;
        end
        else if( hcounter < HSYNC + HBACK + (HACTIVE*3/7) ) begin
            video_data <= 24'hffff00;
        end
        else if( hcounter < HSYNC + HBACK + (HACTIVE*4/7) ) begin
            video_data <= 24'h00ff00;
        end
        else if( hcounter < HSYNC + HBACK + (HACTIVE*5/7) ) begin
            video_data <= 24'h00ffff;
        end
        else if( hcounter < HSYNC + HBACK + (HACTIVE*6/7) ) begin
            video_data <= 24'h0000ff;
        end
        else begin
            video_data <= 24'hff00ff;
        end
    end
end

endmodule
`default_nettype wire