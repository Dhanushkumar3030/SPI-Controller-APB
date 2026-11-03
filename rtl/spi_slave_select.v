`timescale 1ns / 1ps

module spi_slave_select (
    input        PRESET_n,
    input  [1:0]  spi_mode_i,
    input        mstr_i,
    input        spiswai_i,
    input        PCLK,
    input        send_data_i,
    input [11:0] BaudRateDivisor_i,

    output reg   ss_o,
    output reg   receive_data_o,
    output       tip_o
);

    reg [15:0] count_s;
    reg        transfer_done_s;

    wire active_mode;
    wire [15:0] transfer_count_limit;

    assign active_mode =
        mstr_i &&
        (
            (spi_mode_i == 2'b00) ||
            ((spi_mode_i == 2'b01) && !spiswai_i)
        );

    // 8 SPI clock periods.
    assign transfer_count_limit =
        ({4'b0000, BaudRateDivisor_i} * 16'd8);

    assign tip_o = !ss_o;

    always @(posedge PCLK or negedge PRESET_n) begin

        if (!PRESET_n) begin
            count_s         <= 16'd0;
            ss_o            <= 1'b1;
            transfer_done_s <= 1'b0;
        end else begin

            transfer_done_s <= 1'b0;

            if (!active_mode) begin

                ss_o    <= 1'b1;
                count_s <= 16'd0;

            end else begin

                // Start a new transfer only when SS is idle.
                if (send_data_i && ss_o) begin

                    ss_o    <= 1'b0;
                    count_s <= 16'd0;

                end else if (!ss_o) begin

                    if (count_s >= transfer_count_limit - 1'b1) begin

                        ss_o            <= 1'b1;
                        count_s         <= 16'd0;
                        transfer_done_s <= 1'b1;

                    end else begin

                        ss_o    <= 1'b0;
                        count_s <= count_s + 1'b1;

                    end

                end else begin

                    ss_o    <= 1'b1;
                    count_s <= 16'd0;

                end

            end

        end
    end

    // Completion pulse
    always @(posedge PCLK or negedge PRESET_n) begin

        if (!PRESET_n)
            receive_data_o <= 1'b0;
        else
            receive_data_o <= transfer_done_s;

    end

endmodule