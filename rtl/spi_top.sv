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
    // SPI interface
    //============================================================

    spi_interface spi_if
    (
        pclk,
        preset_n
    );

    //============================================================
    // APB interface
    //============================================================

    spi_apb_interface u_spi_apb_interface
    (
        .bus                     (spi_if),

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

        .spi_interrupt_request_o (spi_interrupt_request_o)
    );

    //============================================================
    // SPI baud generator
    //============================================================

    spi_baud_generator u_spi_baud_generator
    (
        .bus          (spi_if),

        .PCLK         (pclk),
        .PRESET_n     (preset_n),

        .spi_mode_i   (2'b00)
    );

    //============================================================
    // SPI slave-select / transfer controller
    //============================================================

    spi_slave_select u_spi_slave_select
    (
        .bus          (spi_if),

        .PRESET_n     (preset_n),
        .spi_mode_i   (2'b00),
        .PCLK         (pclk)
    );

    //============================================================
    // SPI shift register
    //============================================================

    spi_shifter u_spi_shifter
    (
        .bus          (spi_if),

        .PRESET_n     (preset_n),
        .PCLK         (pclk),

        // MSB-first operation
        .lsbfe_i      (1'b0),

        .miso_i       (miso_i)
    );

    //============================================================
    // Top-level SPI outputs
    //============================================================

    assign mosi_o = spi_if.mosi;
    assign sclk_o = spi_if.sclk;
    assign ss_o   = spi_if.ss;

endmodule