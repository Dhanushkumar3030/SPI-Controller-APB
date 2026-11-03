module spi_apb_interface
(
    spi_interface.apb bus,

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
        pready_o  = 1'b0;
        pslverr_o = 1'b0;
        prdata_o  = 8'h00;

        if (current_state == ACCESS)
        begin
            pready_o = 1'b1;

            if ((apb_addr_reg == 3'b100) ||
                (apb_addr_reg == 3'b110) ||
                (apb_addr_reg == 3'b111))
            begin
                pslverr_o = 1'b1;
            end

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
                        prdata_o    = 8'h00;
                        prdata_o[7] = spi_interrupt_request_o;
                        prdata_o[6] = bus.tip;
                        prdata_o[0] = ~bus.ss;
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

            bus.send_data <= 1'b0;

            bus.spie   <= 1'b0;
            bus.spe    <= 1'b0;
            bus.sptie  <= 1'b0;
            bus.mstr   <= 1'b0;
            bus.cpol   <= 1'b0;
            bus.cpha   <= 1'b0;
            bus.modfen <= 1'b0;
            bus.spiswai <= 1'b0;

            bus.sppr <= 3'b000;
            bus.spr  <= 3'b000;

            spi_interrupt_request_o <= 1'b0;
        end
        else
        begin
            bus.send_data <= 1'b0;

            //====================================================
            // Capture received data after SPI transfer
            //====================================================

            if (bus.receive_data)
            begin
                rx_data_reg <= bus.data_miso;
            end

            //====================================================
            // Generate SPI interrupt
            //====================================================

            if (bus.receive_data && bus.spie)
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
                    //================================================

                    ADDR_CR1:
                    begin
                        control_reg1 <= apb_wdata_reg;

                        bus.spie   <= apb_wdata_reg[7];
                        bus.spe    <= apb_wdata_reg[6];
                        bus.mstr   <= apb_wdata_reg[4];
                        bus.cpol   <= apb_wdata_reg[3];
                        bus.cpha   <= apb_wdata_reg[2];
                        bus.modfen <= apb_wdata_reg[1];
                    end

                    //================================================
                    // CR2 register
                    //================================================

                    ADDR_CR2:
                    begin
                        control_reg2 <= apb_wdata_reg;

                        bus.sptie   <= apb_wdata_reg[7];
                        bus.spiswai <= apb_wdata_reg[6];
                    end

                    //================================================
                    // Baud-rate register
                    //================================================

                    ADDR_BR:
                    begin
                        baud_rate_reg <= apb_wdata_reg;

                        bus.sppr <= apb_wdata_reg[5:3];
                        bus.spr  <= apb_wdata_reg[2:0];
                    end

                    //================================================
                    // Status register is read-only
                    //================================================

                    ADDR_SR:
                    begin
                    end

                    //================================================
                    // Data register
                    //================================================

                    ADDR_DR:
                    begin
                        tx_data_reg <= apb_wdata_reg;
                        bus.send_data <= 1'b1;
                    end

                    //================================================
                    // Invalid address
                    //================================================

                    default:
                    begin
                    end

                endcase
            end
        end
    end

    //============================================================
    // Output assignment
    //============================================================

    always @(*)
    begin
        bus.data_mosi = tx_data_reg;
    end

endmodule