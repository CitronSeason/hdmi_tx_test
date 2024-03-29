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
    parameter int BOUNCE_LOG = 0,
    parameter     LOGO_PATH = "",
    parameter int LOGO_WIDTH = 24,
    parameter int LOGO_HEIGHT = 24
) (
    input wire clock,
    input wire reset,

    output logic [23:0] video_data,
    output logic        video_de,
    output logic        video_hsync,
    output logic        video_vsync
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




endmodule
`default_nettype wire