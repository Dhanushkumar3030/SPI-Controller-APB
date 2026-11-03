module spi_apb_interface
(
    input         pclk,
    input         preset_n,

    //============================================================
    // APB interface
    //============================================================
    input         psel_i,
    input         penable_i,
    input         pwrite_i,
    input  [2:0]  paddr_i,
    input  [7:0]  pwdata_i,

    output reg [7:0] prdata_o,
    output reg       pready_o,
    output reg       pslverr_o,

    //============================================================
    // SPI data interface
    //============================================================
    output reg       send_data_o,
    output reg [7:0] data_mosi_o,

    input      [7:0] data_miso_i,
    input            receive_data_i,

    //============================================================
    // SPI status inputs
    //============================================================
    input            tip_i,
    input            ss_i,

    //============================================================
    // SPI control outputs
    //============================================================
    output reg       spie_o,
    output reg       spe_o,
    output reg       sptie_o,
    output reg       mstr_o,
    output reg       cpol_o,
    output reg       cpha_o,
    output reg       modfen_o,
    output reg       spiswai_o,

    output reg [2:0] sppr_o,
    output reg [2:0] spr_o,

    output reg       spi_interrupt_request_o
);

    //============================================================
    // APB FSM states
    //============================================================

    localparam IDLE   = 2'b00;
    localparam SETUP  = 2'b01;
    localparam ACCESS = 2'b10;

    reg [1:0] current_state;
    reg [1:0] next_state;

    //============================================================
    // APB transaction registers
    //============================================================

    reg [2:0] apb_addr_reg;
    reg [7:0] apb_wdata_reg;
    reg       apb_write_reg;

    //============================================================
    // SPI registers
    //============================================================

    reg [7:0] control_reg1;
    reg [7:0] control_reg2;
    reg [7:0] baud_rate_reg;
    reg [7:0] tx_data_reg;

    reg [7:0] rx_data_reg;

    //============================================================
    // APB address definitions
    //============================================================

    localparam ADDR_CR1 = 3'b000;
    localparam ADDR_CR2 = 3'b001;
    localparam ADDR_BR  = 3'b010;
    localparam ADDR_SR  = 3'b011;
    localparam ADDR_DR  = 3'b101;

    //============================================================
    // APB FSM state register
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    //============================================================
    // APB FSM next-state logic
    //============================================================

    always @(*)
    begin
        next_state = current_state;

        case (current_state)

            IDLE:
            begin
                if (psel_i)
                    next_state = SETUP;
                else
                    next_state = IDLE;
            end

            SETUP:
            begin
                if (!psel_i)
                    next_state = IDLE;
                else if (psel_i && penable_i)
                    next_state = ACCESS;
                else
                    next_state = SETUP;
            end

            ACCESS:
            begin
                next_state = IDLE;
            end

            default:
            begin
                next_state = IDLE;
            end

        endcase
    end

    //============================================================
    // Capture APB transaction
    //
    // Transaction is captured when entering SETUP.
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
        begin
            apb_addr_reg  <= 3'b000;
            apb_wdata_reg <= 8'h00;
            apb_write_reg <= 1'b0;
        end
        else if ((current_state == IDLE) && psel_i)
        begin
            apb_addr_reg  <= paddr_i;
            apb_wdata_reg <= pwdata_i;
            apb_write_reg <= pwrite_i;
        end
    end

    //============================================================
    // APB response generation
    //============================================================

    always @(*)
    begin
        // Default APB response
        pready_o  = 1'b0;
        pslverr_o = 1'b0;
        prdata_o  = 8'h00;

        // APB response only during ACCESS
        if (current_state == ACCESS)
        begin
            pready_o = 1'b1;

            // Invalid address detection
            if ((apb_addr_reg == 3'b100) ||
                (apb_addr_reg == 3'b110) ||
                (apb_addr_reg == 3'b111))
            begin
                pslverr_o = 1'b1;
            end

            // Read transaction
            if (!apb_write_reg)
            begin
                case (apb_addr_reg)

                    ADDR_CR1:
                        prdata_o = control_reg1;

                    ADDR_CR2:
                        prdata_o = control_reg2;

                    ADDR_BR:
                        prdata_o = baud_rate_reg;

                    ADDR_SR:
                    begin
                        // Status register
                        // Bit 7 : SPI interrupt flag
                        // Bit 6 : Transfer in progress
                        // Bit 0 : Slave select active
                        prdata_o    = 8'h00;
                        prdata_o[7] = spi_interrupt_request_o;
                        prdata_o[6] = tip_i;
                        prdata_o[0] = ~ss_i;
                    end

                    ADDR_DR:
                        prdata_o = rx_data_reg;

                    default:
                        prdata_o = 8'h00;

                endcase
            end
        end
    end

    //============================================================
    // SPI register write logic
    //============================================================

    always @(posedge pclk or negedge preset_n)
    begin
        if (!preset_n)
        begin
            control_reg1 <= 8'h00;
            control_reg2 <= 8'h00;
            baud_rate_reg <= 8'h00;
            tx_data_reg <= 8'h00;
            rx_data_reg <= 8'h00;

            send_data_o <= 1'b0;

            spie_o   <= 1'b0;
            spe_o    <= 1'b0;
            sptie_o  <= 1'b0;
            mstr_o   <= 1'b0;
            cpol_o   <= 1'b0;
            cpha_o   <= 1'b0;
            modfen_o <= 1'b0;
            spiswai_o <= 1'b0;

            sppr_o <= 3'b000;
            spr_o  <= 3'b000;

            spi_interrupt_request_o <= 1'b0;
        end
        else
        begin
            // Default: send_data is a one-clock pulse
            send_data_o <= 1'b0;

            //====================================================
            // Capture received data after SPI transfer
            //====================================================

            if (receive_data_i)
            begin
                rx_data_reg <= data_miso_i;
            end

            //====================================================
            // Generate SPI interrupt
            //
            // Interrupt is generated when:
            // - transfer is completed
            // - SPI interrupt enable is set
            //====================================================

            if (receive_data_i && spie_o)
                spi_interrupt_request_o <= 1'b1;

            // Clear interrupt when CR1 is rewritten
            if ((current_state == ACCESS) &&
                apb_write_reg &&
                (apb_addr_reg == ADDR_CR1))
            begin
                spi_interrupt_request_o <= 1'b0;
            end

            //====================================================
            // APB write operation
            //====================================================

            if ((current_state == ACCESS) && apb_write_reg)
            begin
                case (apb_addr_reg)

                    //================================================
                    // CR1 register
                    //
                    // Bit 7 : SPI interrupt enable
                    // Bit 6 : SPI enable
                    // Bit 4 : Master mode
                    // Bit 3 : CPOL
                    // Bit 2 : CPHA
                    // Bit 1 : MODFEN
                    // Bit 0 : LSBFE
                    //================================================

                    ADDR_CR1:
                    begin
                        control_reg1 <= apb_wdata_reg;

                        spie_o   <= apb_wdata_reg[7];
                        spe_o    <= apb_wdata_reg[6];
                        mstr_o   <= apb_wdata_reg[4];
                        cpol_o   <= apb_wdata_reg[3];
                        cpha_o   <= apb_wdata_reg[2];
                        modfen_o <= apb_wdata_reg[1];
                    end

                    //================================================
                    // CR2 register
                    //
                    // Bit 7 : SPTIE
                    // Bit 6 : SPISWAI
                    //================================================

                    ADDR_CR2:
                    begin
                        control_reg2 <= apb_wdata_reg;

                        sptie_o   <= apb_wdata_reg[7];
                        spiswai_o <= apb_wdata_reg[6];
                    end

                    //================================================
                    // Baud-rate register
                    //
                    // Upper 3 bits: SPPR
                    // Lower 3 bits: SPR
                    //================================================

                    ADDR_BR:
                    begin
                        baud_rate_reg <= apb_wdata_reg;

                        sppr_o <= apb_wdata_reg[5:3];
                        spr_o  <= apb_wdata_reg[2:0];
                    end

                    //================================================
                    // Status register is read-only
                    //================================================

                    ADDR_SR:
                    begin
                        // No write operation
                    end

                    //================================================
                    // Data register
                    //================================================

                    ADDR_DR:
                    begin
                        tx_data_reg  <= apb_wdata_reg;
                        send_data_o  <= 1'b1;
                    end

                    //================================================
                    // Invalid address
                    //================================================

                    default:
                    begin
                        // No register update
                    end

                endcase
            end
        end
    end

    //============================================================
    // Output assignments
    //============================================================

    always @(*)
    begin
        data_mosi_o = tx_data_reg;
    end

endmodule