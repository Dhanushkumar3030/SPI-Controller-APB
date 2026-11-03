`timescale 1ns / 1ps

module spi_top
(
    //============================================================
    // APB clock and reset
    //============================================================

    input        pclk,
    input        preset_n,

    //============================================================
    // APB interface
    //============================================================

    input  [2:0] paddr_i,
    input        psel_i,
    input        penable_i,
    input        pwrite_i,
    input  [7:0] pwdata_i,

    output [7:0] prdata_o,
    output       pready_o,
    output       pslverr_o,

    //============================================================
    // SPI pins
    //============================================================

    input        miso_i,

    output       mosi_o,
    output       sclk_o,
    output       ss_o,

    //============================================================
    // Interrupt
    //============================================================

    output       spi_interrupt_request_o
);

    //============================================================
    // Internal signals from APB interface
    //============================================================

    wire       send_data_w;
    wire [7:0] data_mosi_w;
    wire [7:0] data_miso_w;

    wire       receive_data_w;
    wire       tip_w;
    wire       ss_w;

    wire       spie_w;
    wire       spe_w;
    wire       sptie_w;
    wire       mstr_w;
    wire       cpol_w;
    wire       cpha_w;
    wire       modfen_w;
    wire       spiswai_w;

    wire [2:0] sppr_w;
    wire [2:0] spr_w;

    //============================================================
    // Internal SPI timing signals
    //============================================================

    wire sclk_w;

    wire miso_receive_sclk_w;
    wire miso_receive_sclk0_w;

    wire mosi_send_sclk_w;
    wire mosi_send_sclk0_w;

    wire [11:0] baud_rate_divisor_w;

    //============================================================
    // APB interface
    //============================================================

    spi_apb_interface u_spi_apb_interface
    (
        .pclk                    (pclk),
        .preset_n                (preset_n),

        .psel_i                  (psel_i),
        .penable_i               (penable_i),
        .pwrite_i                (pwrite_i),
        .paddr_i                 (paddr_i),
        .pwdata_i                (pwdata_i),

        .prdata_o                (prdata_o),
        .pready_o                (pready_o),
        .pslverr_o               (pslverr_o),

        .send_data_o             (send_data_w),
        .data_mosi_o             (data_mosi_w),

        .data_miso_i             (data_miso_w),
        .receive_data_i          (receive_data_w),

        .tip_i                   (tip_w),
        .ss_i                    (ss_w),

        .spie_o                  (spie_w),
        .spe_o                   (spe_w),
        .sptie_o                 (sptie_w),
        .mstr_o                  (mstr_w),
        .cpol_o                  (cpol_w),
        .cpha_o                  (cpha_w),
        .modfen_o                (modfen_w),
        .spiswai_o               (spiswai_w),

        .sppr_o                  (sppr_w),
        .spr_o                   (spr_w),

        .spi_interrupt_request_o (spi_interrupt_request_o)
    );

    //============================================================
    // SPI baud generator
    //============================================================

    spi_baud_generator u_spi_baud_generator
    (
        .PCLK                    (pclk),
        .PRESET_n                (preset_n),

        .spi_mode_i              (2'b00),

        .spiswai_i               (spiswai_w),

        .sppr_i                  (sppr_w),
        .spr_i                   (spr_w),

        .cpol_i                  (cpol_w),
        .cpha_i                  (cpha_w),

        .ss_i                    (ss_w),

        .sclk_o                  (sclk_w),

        .miso_receive_sclk_o     (miso_receive_sclk_w),
        .miso_receive_sclk0_o    (miso_receive_sclk0_w),

        .mosi_send_sclk_o        (mosi_send_sclk_w),
        .mosi_send_sclk0_o       (mosi_send_sclk0_w),

        .BaudRateDivisor_o       (baud_rate_divisor_w)
    );

    //============================================================
    // SPI slave-select / transfer controller
    //============================================================

    spi_slave_select u_spi_slave_select
    (
        .PRESET_n                (preset_n),

        .spi_mode_i              (2'b00),

        .mstr_i                  (mstr_w),
        .spiswai_i               (spiswai_w),

        .PCLK                    (pclk),

        .send_data_i             (send_data_w),

        .BaudRateDivisor_i       (baud_rate_divisor_w),

        .ss_o                    (ss_w),
        .receive_data_o          (receive_data_w),

        .tip_o                   (tip_w)
    );

    //============================================================
    // SPI shift register
    //============================================================

    spi_shifter u_spi_shifter
    (
        .PRESET_n                (preset_n),
        .PCLK                    (pclk),

        .ss_i                    (ss_w),

        // MSB-first operation
        .lsbfe_i                 (1'b0),

        .cpha_i                  (cpha_w),
        .cpol_i                  (cpol_w),

        .data_mosi_i             (data_mosi_w),
        .miso_i                  (miso_i),

        .data_miso_o             (data_miso_w),
        .mosi_o                  (mosi_o),

        .send_data_i             (send_data_w),
        .receive_data_i          (receive_data_w),

        .miso_receive_sclk_i     (miso_receive_sclk_w),
        .miso_receive_sclk0_i    (miso_receive_sclk0_w),

        .mosi_send_sclk0_i       (mosi_send_sclk0_w),
        .mosi_send_sclk_i        (mosi_send_sclk_w)
    );

    //============================================================
    // Top-level SPI outputs
    //============================================================

    assign sclk_o = sclk_w;
    assign ss_o   = ss_w;

endmodule