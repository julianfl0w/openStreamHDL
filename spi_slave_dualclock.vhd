library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- THE SPI SLAVE MODULE SUPPORT ONLY SPI MODE 0 (CPOL=0, CPHA=0)!!!

entity spi_slave_dualclock is
    Port (
        CLK      : in  std_logic; -- SPI clock
        RST      : in  std_logic; -- SPI clock
        -- SPI SLAVE INTERFACE
        SCLK     : in  std_logic; -- SPI clock
        CS_N     : in  std_logic; -- SPI chip select, active in low
        MOSI     : in  std_logic_vector(0 downto 0); -- SPI serial data from master to slave
        MISO     : out std_logic_vector(0 downto 0); -- SPI serial data from slave to master
        -- USER INTERFACE
        TX_DATA  : in  std_logic_vector; -- input data for SPI master
        TX_VALID : in  std_logic; -- when TX_VALID = 1, input data are valid
        TX_READY : out std_logic; -- when TX_READY = 1, valid input data are accept
        TX_Enable: in  Std_logic;
        
        RX_DATA  : out std_logic_vector; -- output data from SPI master
        RX_VALID : out std_logic;  -- when RX_VALID = 1, output data are valid
        RX_READY : in  std_logic
    );
end spi_slave_dualclock;

architecture RTL of spi_slave_dualclock is

Signal MISO_valid : Std_logic := '0'; -- Data Valid Pulse with TX_data
Signal MISO_Ready : Std_logic := '1'; -- Transmit Ready for next byte
Signal MISO_int   : std_logic_vector(0 downto 0) := (others=>'0');

Signal MOSI_valid : Std_logic := '0'; -- Data Valid Pulse with TX_data
Signal MOSI_Ready : Std_logic := '0'; -- Transmit Ready for next byte

signal TXFIFO_DATA  : std_logic_vector(TX_DATA'high downto 0); -- input data for SPI master
signal TXFIFO_VALID : std_logic; -- when TX_VALID = 1, input data are valid
signal TXFIFO_READY : std_logic; -- when TX_READY = 1, valid input data are accept

signal TXFIFO_READY_and_enable : std_logic;

signal RXFIFO_DATA  : std_logic_vector(RX_DATA'high downto 0); -- output data from SPI master
signal RXFIFO_VALID : std_logic;  -- when RX_VALID = 1, output data are valid
signal RXFIFO_READY : std_logic;
signal rst_or_deselected : std_logic;
       
signal sclk_not : std_logic;

begin
    sclk_not   <= not sclk;
    MOSI_VALID <= not CS_N;
    MISO_Ready <= not CS_N;
    MISO <= MISO_int when MISO_valid = '1' else "0";
    rst_or_deselected <= rst or CS_N;
    TXFIFO_READY_and_enable <= TXFIFO_READY and TX_ENABLE; -- THIS SIGNAL CROSSES DOMAINS AND IDGAF
    
	-- transmit
	fs_tx : Entity work.fifo_stream_36_dual
	    Generic Map(
	       ALMOST_FULL_OFFSET => x"001F"
	    )
		Port Map(
			inclk => clk,
			outclk => sclk,
			rst => rst,
			din_ready  => TX_ready,
			din_valid  => TX_valid,
			din_data   => TX_data,
			dout_ready => TXFIFO_ready_and_enable,
			dout_valid => TXFIFO_valid,
			dout_data  => TXFIFO_data
		);
		
	ser : Entity work.serializer
		Port Map(
			clk        => sclk,
			rst        => rst,
			din_ready  => TXFIFO_ready,
			din_valid  => TXFIFO_valid,
			din_data   => TXFIFO_data ,
			dout_ready => MISO_Ready,
			dout_valid => MISO_valid,
			dout_data  => MISO_int
		);

	deser : Entity work.deserializer
		Port Map(
			clk => sclk,
			rst => rst_or_deselected, -- clear deserializer when deselected
			din_ready  => MOSI_ready,
			din_valid  => MOSI_valid,
			din_data   => MOSI,
			dout_ready => RXFIFO_READY,
			dout_valid => RXFIFO_valid,
			dout_data  => RXFIFO_data
		);
		
	-- receive
	fs_rx : Entity work.fifo_stream_36_dual
	    Generic Map(
	       ALMOST_FULL_OFFSET => x"00FF"
	    )
		Port Map(
			inclk  => sclk_not,
			outclk => clk,
			rst => rst,
			din_ready  => RXFIFO_ready,
			din_valid  => RXFIFO_valid,
			din_data   => RXFIFO_data,
			dout_ready => RX_ready,
			dout_valid => RX_valid,
			dout_data  => RX_data
		);

end RTL;