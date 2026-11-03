`timescale 1ns / 1ps

module spi_slave_select
(
    spi_interface.slave_select bus,

    input        PRESET_n,
    input  [1:0] spi_mode_i,
    input        PCLK
);

    reg [15:0] count_s;
    reg        transfer_done_s;

    wire active_mode;
    wire [15:0] transfer_count_limit;

    assign active_mode =
        bus.mstr &&
        (
            (spi_mode_i == 2'b00) ||
            ((spi_mode_i == 2'b01) && !bus.spiswai)
        );

    // 8 SPI clock periods.
    assign transfer_count_limit =
        ({4'b0000, bus.baud_rate_divisor} * 16'd8);

    assign bus.tip = !bus.ss;

    always @(posedge PCLK or negedge PRESET_n)
    begin

        if (!PRESET_n)
        begin
            count_s         <= 16'd0;
            bus.ss          <= 1'b1;
            transfer_done_s <= 1'b0;
        end
        else
        begin

            transfer_done_s <= 1'b0;

            if (!active_mode)
            begin

                bus.ss  <= 1'b1;
                count_s <= 16'd0;

            end
            else
            begin

                // Start a new transfer only when SS is idle.
                if (bus.send_data && bus.ss)
                begin

                    bus.ss  <= 1'b0;
                    count_s <= 16'd0;

                end
                else if (!bus.ss)
                begin

                    if (count_s >= transfer_count_limit - 1'b1)
                    begin

                        bus.ss          <= 1'b1;
                        count_s         <= 16'd0;
                        transfer_done_s <= 1'b1;

                    end
                    else
                    begin

                        bus.ss  <= 1'b0;
                        count_s <= count_s + 1'b1;

                    end

                end
                else
                begin

                    bus.ss  <= 1'b1;
                    count_s <= 16'd0;

                end

            end

        end
    end

    // Completion pulse
    always @(posedge PCLK or negedge PRESET_n)
    begin

        if (!PRESET_n)
            bus.receive_data <= 1'b0;
        else
            bus.receive_data <= transfer_done_s;

    end

endmodule