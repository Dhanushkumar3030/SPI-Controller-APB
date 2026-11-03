interface spi_interface
(
    input PCLK,
    input PRESET_n
);

    logic send_data;
    logic [7:0] data_mosi;
    logic [7:0] data_miso;

    logic receive_data;
    logic tip;
    logic ss;

    logic spie;
    logic spe;
    logic sptie;
    logic mstr;
    logic cpol;
    logic cpha;
    logic modfen;
    logic spiswai;

    logic [2:0] sppr;
    logic [2:0] spr;

    logic sclk;
	logic mosi;

    logic miso_receive_sclk;
    logic miso_receive_sclk0;

    logic mosi_send_sclk;
    logic mosi_send_sclk0;

    logic [11:0] baud_rate_divisor;


    modport baud_gen
    (
        input spiswai,
        input sppr,
        input spr,
        input cpol,
        input cpha,
        input ss,

        output sclk,
        output miso_receive_sclk,
        output miso_receive_sclk0,
        output mosi_send_sclk,
        output mosi_send_sclk0,
        output baud_rate_divisor
    );


    modport slave_select
    (
        input mstr,
        input spiswai,
        input send_data,
        input baud_rate_divisor,

        output ss,
        output receive_data,
        output tip
    );


    modport shifter
    (
        input ss,
        input cpha,
        input cpol,
        input data_mosi,
        input send_data,
        input receive_data,
        input miso_receive_sclk,
        input miso_receive_sclk0,
        input mosi_send_sclk,
        input mosi_send_sclk0,

        output data_miso,
        output mosi
    );


    modport apb
    (
        input data_miso,
        input receive_data,
        input tip,
        input ss,

        output send_data,
        output data_mosi,

        output spie,
        output spe,
        output sptie,
        output mstr,
        output cpol,
        output cpha,
        output modfen,
        output spiswai,

        output sppr,
        output spr
    );

endinterface