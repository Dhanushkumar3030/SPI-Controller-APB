`timescale 1ns / 1ps

module spi_top_tb;

    //============================================================
    // APB signals
    //============================================================

    reg         pclk;
    reg         preset_n;

    reg  [2:0]  paddr_i;
    reg         psel_i;
    reg         penable_i;
    reg         pwrite_i;
    reg  [7:0]  pwdata_i;

    wire [7:0]  prdata_o;
    wire        pready_o;
    wire        pslverr_o;

    //============================================================
    // SPI signals
    //============================================================

    reg         miso_i;

    wire        mosi_o;
    wire        sclk_o;
    wire        ss_o;

    wire        spi_interrupt_request_o;

    //============================================================
    // Test data
    //============================================================

    reg [7:0] tx_data;
    reg [7:0] expected_miso;

    reg [7:0] observed_mosi;
    reg [7:0] received_data;
    reg [7:0] cr1_readback;

    //============================================================
    // DUT
    //============================================================

    spi_top dut
    (
        .pclk                    (pclk),
        .preset_n                (preset_n),

        .paddr_i                 (paddr_i),
        .psel_i                  (psel_i),
        .penable_i               (penable_i),
        .pwrite_i                (pwrite_i),
        .pwdata_i                (pwdata_i),

        .prdata_o                (prdata_o),
        .pready_o                (pready_o),
        .pslverr_o               (pslverr_o),

        .miso_i                  (miso_i),

        .mosi_o                  (mosi_o),
        .sclk_o                  (sclk_o),
        .ss_o                    (ss_o),

        .spi_interrupt_request_o (spi_interrupt_request_o)
    );

    //============================================================
    // Clock generation
    //============================================================

    initial
    begin
        pclk = 1'b0;
    end

    always #5 pclk = ~pclk;

    //============================================================
    // Monitor
    //============================================================

    always @(posedge pclk)
    begin
        $display(
            "TIME=%0t | ADDR=%h | PWRITE=%b | PSEL=%b | PENABLE=%b | PRDATA=%h | PREADY=%b | PSLVERR=%b | MOSI=%b | MISO=%b | SCLK=%b | SS=%b | IRQ=%b",
            $time,
            paddr_i,
            pwrite_i,
            psel_i,
            penable_i,
            prdata_o,
            pready_o,
            pslverr_o,
            mosi_o,
            miso_i,
            sclk_o,
            ss_o,
            spi_interrupt_request_o
        );
    end

    //============================================================
    // APB WRITE TASK
    //============================================================

    task apb_write;

        input [2:0] addr;
        input [7:0] data;

        begin

            // SETUP phase
            @(posedge pclk);

            paddr_i   = addr;
            pwdata_i  = data;
            pwrite_i  = 1'b1;
            psel_i    = 1'b1;
            penable_i = 1'b0;

            // ACCESS phase
            @(posedge pclk);

            penable_i = 1'b1;

            // Wait until APB transfer completes
            wait (pready_o == 1'b1);

            #1;

            $display(
                "APB WRITE | ADDR=%h | DATA=%h | PREADY=%b | PSLVERR=%b",
                addr,
                data,
                pready_o,
                pslverr_o
            );

            // Return to IDLE
            @(posedge pclk);

            psel_i    = 1'b0;
            penable_i = 1'b0;
            pwrite_i  = 1'b0;
            paddr_i   = 3'b000;
            pwdata_i  = 8'h00;

        end

    endtask

    //============================================================
    // APB READ TASK
    //============================================================

    task apb_read;

        input  [2:0] addr;
        output [7:0] data;

        begin

            // SETUP phase
            @(posedge pclk);

            paddr_i   = addr;
            pwrite_i  = 1'b0;
            psel_i    = 1'b1;
            penable_i = 1'b0;

            // ACCESS phase
            @(posedge pclk);

            penable_i = 1'b1;

            // Wait for APB response
            wait (pready_o == 1'b1);

            #1;

            data = prdata_o;

            $display(
                "APB READ  | ADDR=%h | DATA=%h | PREADY=%b | PSLVERR=%b",
                addr,
                data,
                pready_o,
                pslverr_o
            );

            // Return to IDLE
            @(posedge pclk);

            psel_i    = 1'b0;
            penable_i = 1'b0;
            pwrite_i  = 1'b0;
            paddr_i   = 3'b000;

        end

    endtask

    //============================================================
    // Invalid APB address test
    //============================================================

    task apb_invalid_access;

        input [2:0] addr;

        begin

            @(posedge pclk);

            paddr_i   = addr;
            pwdata_i  = 8'hAA;
            pwrite_i  = 1'b0;
            psel_i    = 1'b1;
            penable_i = 1'b0;

            @(posedge pclk);

            penable_i = 1'b1;

            wait (pready_o == 1'b1);

            #1;

            $display(
                "INVALID ACCESS | ADDR=%h | PREADY=%b | PSLVERR=%b",
                addr,
                pready_o,
                pslverr_o
            );

            if (pslverr_o == 1'b1)
                $display("PSLVERR CHECK : PASS");
            else
                $display("PSLVERR CHECK : FAIL");

            @(posedge pclk);

            psel_i    = 1'b0;
            penable_i = 1'b0;
            pwrite_i  = 1'b0;
            paddr_i   = 3'b000;

        end

    endtask

    //============================================================
    // DRIVE MISO TASK
    //
    // SPI Mode 0:
    // First bit before first rising edge.
    // Remaining bits change on falling edge.
    //============================================================

    task drive_miso;

        input [7:0] data;

        integer j;

        begin

            wait (ss_o == 1'b0);

            // First MSB before first rising edge
            miso_i = data[7];

            $display(
                "MISO DRIVE | TIME=%0t | BIT[7]=%b",
                $time,
                data[7]
            );

            for (j = 6; j >= 0; j = j - 1)
            begin

                @(negedge sclk_o);

                miso_i = data[j];

                $display(
                    "MISO DRIVE | TIME=%0t | BIT[%0d]=%b",
                    $time,
                    j,
                    data[j]
                );

            end

        end

    endtask

    //============================================================
    // SAMPLE MOSI TASK
    //============================================================

    task sample_mosi;

        output [7:0] data;

        integer j;

        begin

            data = 8'h00;

            wait (ss_o == 1'b0);

            for (j = 7; j >= 0; j = j - 1)
            begin

                @(posedge sclk_o);

                data[j] = mosi_o;

                $display(
                    "MOSI SAMPLE | TIME=%0t | BIT[%0d]=%b",
                    $time,
                    j,
                    mosi_o
                );

            end

        end

    endtask

    //============================================================
    // MAIN TEST
    //============================================================

    initial
    begin

        //========================================================
        // Initial values
        //========================================================

        preset_n  = 1'b0;

        paddr_i   = 3'b000;
        psel_i    = 1'b0;
        penable_i = 1'b0;
        pwrite_i  = 1'b0;
        pwdata_i  = 8'h00;

        miso_i = 1'b0;

        tx_data       = 8'hA5;
        expected_miso = 8'h3C;

        observed_mosi = 8'h00;
        received_data = 8'h00;
        cr1_readback  = 8'h00;

        //========================================================
        // Reset
        //========================================================

        repeat (4) @(posedge pclk);

        preset_n = 1'b1;

        $display("================================================");
        $display("RESET RELEASED");
        $display("================================================");

        repeat (2) @(posedge pclk);

        //========================================================
        // Configure CR1
        //========================================================

        apb_write(3'b000, 8'h50);

        //========================================================
        // Configure baud rate
        //========================================================

        apb_write(3'b010, 8'h10);

        //========================================================
        // Read CR1
        //========================================================

        apb_read(3'b000, cr1_readback);

        $display("CR1 READBACK = %h", cr1_readback);

        //========================================================
        // Enable SPI and interrupt
        //========================================================

        apb_write(3'b000, 8'hD0);

        //========================================================
        // Invalid address checks
        //========================================================

        apb_invalid_access(3'b100);
        apb_invalid_access(3'b110);
        apb_invalid_access(3'b111);

        $display("================================================");
        $display("STARTING SPI TRANSFER");
        $display("================================================");

        //========================================================
        // Run all transfer tasks simultaneously
        //========================================================

        fork

            begin
                drive_miso(expected_miso);
            end

            begin
                sample_mosi(observed_mosi);
            end

            begin
                apb_write(3'b101, tx_data);
            end

        join

        //========================================================
        // Wait for transfer completion
        //========================================================

        wait (ss_o == 1'b1);

        repeat (4) @(posedge pclk);

        //========================================================
        // Read received data
        //========================================================

        apb_read(3'b101, received_data);

        //========================================================
        // Final results
        //========================================================

        $display("");
        $display("================================================");
        $display("FINAL RESULTS");
        $display("================================================");

        $display("Expected MOSI = %h", tx_data);
        $display("Observed MOSI = %h", observed_mosi);

        if (observed_mosi == tx_data)
            $display("MOSI CHECK : PASS");
        else
            $display("MOSI CHECK : FAIL");

        $display("Expected MISO = %h", expected_miso);
        $display("Received MISO = %h", received_data);

        if (received_data == expected_miso)
            $display("MISO CHECK : PASS");
        else
            $display("MISO CHECK : FAIL");

        if (ss_o == 1'b1)
            $display("SS CHECK : PASS");
        else
            $display("SS CHECK : FAIL");

        if (spi_interrupt_request_o == 1'b1)
            $display("SPI IRQ = 1");
        else
            $display("SPI IRQ = 0");

        $display("================================================");
        $display("SIMULATION COMPLETED");
        $display("================================================");

        #50;

        $finish;

    end

endmodule