`timescale 1ns / 1ps

module spi_shifter
(
    spi_interface.shifter bus,

    input        PRESET_n,
    input        PCLK,

    input        lsbfe_i,
    input        miso_i
);

    reg [7:0] tx_shift_reg;
    reg [7:0] rx_shift_reg;

    reg [3:0] bit_count;

    assign bus.data_miso = rx_shift_reg;

    // The MSB or LSB remains continuously available on MOSI.
    // For MSB-first, bit 7 is transmitted first.
    assign bus.mosi = lsbfe_i ? tx_shift_reg[0] : tx_shift_reg[7];

    always @(posedge PCLK or negedge PRESET_n)
    begin

        if (!PRESET_n)
        begin

            tx_shift_reg <= 8'h00;
            rx_shift_reg <= 8'h00;
            bit_count    <= 4'd0;

        end
        else
        begin

            // Load a complete 8-bit transmit byte.
            if (bus.send_data)
            begin

                tx_shift_reg <= bus.data_mosi;
                rx_shift_reg <= 8'h00;
                bit_count    <= 4'd0;

            end

            // SPI shifting is active only while SS is LOW.
            if (!bus.ss)
            begin

                // ------------------------------------------------
                // TX SHIFT
                // For SPI mode 0:
                // Data changes on falling edge.
                // ------------------------------------------------

                if (bus.mosi_send_sclk)
                begin

                    if (lsbfe_i)
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                    else
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};

                end

                // ------------------------------------------------
                // RX SHIFT
                // For SPI mode 0:
                // Data is sampled on rising edge.
                // ------------------------------------------------

                if (bus.miso_receive_sclk)
                begin

                    if (bit_count < 4'd8)
                    begin

                        if (lsbfe_i)
                            rx_shift_reg <= {miso_i, rx_shift_reg[7:1]};
                        else
                            rx_shift_reg <= {rx_shift_reg[6:0], miso_i};

                        bit_count <= bit_count + 1'b1;

                    end

                end

            end

        end

    end

endmodule