`timescale 1ns / 1ps

module spi_baud_generator (

    input        PCLK,
    input        PRESET_n,

    input  [1:0] spi_mode_i,
    input        spiswai_i,

    input  [2:0] sppr_i,
    input  [2:0] spr_i,

    input        cpol_i,
    input        cpha_i,

    input        ss_i,

    output reg   sclk_o,

    output reg   miso_receive_sclk_o,
    output reg   miso_receive_sclk0_o,

    output reg   mosi_send_sclk_o,
    output reg   mosi_send_sclk0_o,

    output [11:0] BaudRateDivisor_o

);

    reg [11:0] count_s;

    wire [11:0] BaudRateDivisor;

    wire active_transfer;

    assign BaudRateDivisor =
            (sppr_i + 3'd1) << (spr_i + 3'd1);

    assign BaudRateDivisor_o = BaudRateDivisor;

    assign active_transfer =
            (!ss_i) &&
            (
                (spi_mode_i == 2'b00) ||
                ((spi_mode_i == 2'b01) && (!spiswai_i))
            );

    always @(posedge PCLK or negedge PRESET_n) begin

        if (!PRESET_n) begin

            count_s <= 12'd0;

            sclk_o <= cpol_i;

            miso_receive_sclk_o  <= 1'b0;
            miso_receive_sclk0_o <= 1'b0;

            mosi_send_sclk_o     <= 1'b0;
            mosi_send_sclk0_o    <= 1'b0;

        end
        else begin

            // All timing pulses are one-clock-cycle pulses.
            miso_receive_sclk_o  <= 1'b0;
            miso_receive_sclk0_o <= 1'b0;

            mosi_send_sclk_o     <= 1'b0;
            mosi_send_sclk0_o    <= 1'b0;

            if (active_transfer) begin

                if (BaudRateDivisor <= 12'd2) begin

                    count_s <= 12'd0;

                    sclk_o <= ~sclk_o;

                    // Mode 0: CPOL=0, CPHA=0
                    if (!cpol_i && !cpha_i) begin

                        if (sclk_o == 1'b0)
                            miso_receive_sclk_o <= 1'b1;
                        else
                            mosi_send_sclk_o <= 1'b1;

                    end

                end
                else if (count_s == ((BaudRateDivisor >> 1) - 1'b1)) begin

                    count_s <= 12'd0;

                    // Toggle SCLK.
                    sclk_o <= ~sclk_o;

                    // ------------------------------------------------
                    // SPI mode 0:
                    //
                    // Current SCLK LOW -> rising edge:
                    // RX sample
                    //
                    // Current SCLK HIGH -> falling edge:
                    // TX shift
                    // ------------------------------------------------

                    if (!cpol_i && !cpha_i) begin

                        if (sclk_o == 1'b0)
                            miso_receive_sclk_o <= 1'b1;
                        else
                            mosi_send_sclk_o <= 1'b1;

                    end
                    else begin

                        // Basic fallback for other modes.
                        // Full CPOL/CPHA-specific refinement can
                        // be added after mode 0 verification.

                        if (sclk_o == cpol_i)
                            mosi_send_sclk_o <= 1'b1;
                        else
                            miso_receive_sclk_o <= 1'b1;

                    end

                end
                else begin

                    count_s <= count_s + 1'b1;

                end

            end
            else begin

                count_s <= 12'd0;

                // Return SCLK to idle polarity.
                sclk_o <= cpol_i;

            end

        end

    end

endmodule