`default_nettype none
module top(
    input  wire         clock,
    input  wire         button_s2,
    output logic [5:0]  led,        /* On Board LEDs */
    output logic        tmds_clk_p,
    output logic [2:0]  tmds_data_p
);

logic clock_dvi;
logic pll_lock;
logic clock_dvi_ser;
logic pll_lcok_ser;

/* リセットボタン入力 */
logic [2:0] reset_button = '1;
always_ff @(posedge clock) begin
    reset_button <= {!button_s2, reset_button[2:1]};
end

/* リセットシーケンサ */
logic reset_ext;
reset_seq reset_seq_ext(
    .clock(clock_dvi),
    .reset_in(reset_button[0] || !pll_lock || !pll_lcok_ser),
    .reset_out(reset_ext)
);

/* ピクセル・クロック用rPLLインスタンス */
gowin_rpll_dvi rpll_dvi(
    .clkout(clock_dvi),
    .lock(pll_lock),
    .clkin(clock)
);

/* シリアライザ・クロック用rPLLインスタンス */
gowin_rpll_ser rpll_dvi_ser(
    .clkout(clock_dvi_ser),
    .lock(pll_lcok_ser),
    .clkin(clock_dvi)
);

/* ピクセルクロックドメイン用リセット */
logic reset_dvi;
reser_seq #(
    .RESET_DELAY_CYCLES(4)
) reset_seq_dvi (
    .clock(clock_dvi),
    .reset_in(reset_ext),
    .reset_out(reset_dvi)
);

/* On Board LEDs: PLLのロック信号を出力 */
assign led = ~{4'b000, pll_lock, pll_lcok_ser};

logic [9:0] dvi_clock;
logic [9:0] dvi_data0;
logic [9:0] dvi_data1;
logic [9:0] dvi_data2;

logic video_de;
logic video_hsync;
logic video_vsync;
logic [23:0] video_data;

/* テストパターン生成モジュール */
test_pattern_generator #(
    .BOUNCE_LOGO (1),
    .LOGO_PATH("../cq_logo.hex"),
    .LOGO_WIDTH(250),
    .LOGO_HEIGHT(50),
    .LOGO_COLOR(24'h000000),
) tpg_inst (
    .clock( clock_dvi ),
    .reset( reset_dvi),
    .*
);

/* TMDS エンコーダモジュール */
dvi_out dvi_out_inst (
    .clock(clock_dvi),
    .reset(reset_dvi),
    .*
);

/* 10:1シリアライザDVIチャネル0 データ */
OSER10 #(
    .GSREN("false"),
    .LSREN("true")
) oser_dvi_data0 (
    .Q(tmds_data_p[0]),
    .D0(dvi_data0[0]),
    .D1(dvi_data0[1]),
    .D2(dvi_data0[2]),
    .D3(dvi_data0[3]),
    .D4(dvi_data0[4]),
    .D5(dvi_data0[5]),
    .D6(dvi_data0[6]),
    .D7(dvi_data0[7]),
    .D8(dvi_data0[8]),
    .D9(dvi_data0[9]),
    .FCLK(clock_dvi_ser),
    .PCLK(clock_dvi),
    .RESET(reset_dvi)
);

/* 10:1シリアライザDVIチャネル1 データ */
OSER10 #(
    .GSREN("false"),
    .LSREN("true")
) oser_dvi_data1 (
    .Q(tmds_data_p[1]),
    .D0(dvi_data1[0]),
    .D1(dvi_data1[1]),
    .D2(dvi_data1[2]),
    .D3(dvi_data1[3]),
    .D4(dvi_data1[4]),
    .D5(dvi_data1[5]),
    .D6(dvi_data1[6]),
    .D7(dvi_data1[7]),
    .D8(dvi_data1[8]),
    .D9(dvi_data1[9]),
    .FCLK(clock_dvi_ser),
    .PCLK(clock_dvi),
    .RESET(reset_dvi)
);

/* 10:1シリアライザDVIチャネル2 データ */
OSER10 #(
    .GSREN("false"),
    .LSREN("true")
) oser_dvi_data2 (
    .Q(tmds_data_p[2]),
    .D0(dvi_data2[0]),
    .D1(dvi_data2[1]),
    .D2(dvi_data2[2]),
    .D3(dvi_data2[3]),
    .D4(dvi_data2[4]),
    .D5(dvi_data2[5]),
    .D6(dvi_data2[6]),
    .D7(dvi_data2[7]),
    .D8(dvi_data2[8]),
    .D9(dvi_data2[9]),
    .FCLK(clock_dvi_ser),
    .PCLK(clock_dvi),
    .RESET(reset_dvi)
);


endmodule
`default_nettype wire