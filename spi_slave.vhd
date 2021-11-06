library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- THE SPI SLAVE MODULE SUPPORT ONLY SPI MODE 0 (CPOL=0, CPHA=0)!!!

entity SPI_SLAVE is
    Port (
        CLK      : in  std_logic; -- system clock
        RST      : in  std_logic; -- high active synchronous reset
        -- SPI SLAVE INTERFACE
        SCLK     : in  std_logic; -- SPI clock
        CS_N     : in  std_logic; -- SPI chip select, active in low
        MOSI     : in  std_logic; -- SPI serial data from master to slave
        MISO     : out std_logic; -- SPI serial data from slave to master
        -- USER INTERFACE
        TX_DATA   : in  std_logic_vector(7 downto 0); -- input data for SPI master
        TX_VALID  : in  std_logic; -- when TX_VALID = 1, input data are valid
        TX_READY  : out std_logic; -- when TX_READY = 1, valid input data are accept
        
        RX_DATA  : out std_logic_vector(7 downto 0); -- output data from SPI master
        RX_VALID : out std_logic;  -- when RX_VALID = 1, output data are valid
        RX_READY : in  std_logic 
    );
end SPI_SLAVE;

architecture RTL of SPI_SLAVE is

    signal SCLK_LAST        : std_logic;
    signal spi_clk_redge    : std_logic;
    signal spi_clk_fedge    : std_logic;
    signal bit_number       : unsigned(2 downto 0);
    signal TX_DATA_INT      : std_logic_vector(7 downto 0);
    signal TX_READY_INT     : std_logic;
    signal RX_VALID_INT     : std_logic;
    signal RX_DATA_INT      : std_logic_vector(7 downto 0); -- output data from SPI master

    signal SCLK_SYNC     : std_logic; -- SPI clock
    signal CS_N_SYNC     : std_logic; -- SPI chip select, active in low
    signal MOSI_SYNC     : std_logic; -- SPI serial data from master to slave
        
    attribute mark_debug : string;
    attribute mark_debug of SCLK_SYNC   : signal is "true";
    attribute mark_debug of CS_N_SYNC   : signal is "true";
    attribute mark_debug of MOSI_SYNC   : signal is "true";
    attribute mark_debug of spi_clk_redge : signal is "true";
    attribute mark_debug of spi_clk_fedge : signal is "true";
    attribute mark_debug of bit_number       : signal is "true";
    attribute mark_debug of SCLK_LAST        : signal is "true";
    
begin
    MISO     <= TX_DATA_INT(7);
    TX_READY <= TX_READY_INT;
    RX_VALID <= RX_VALID_INT;

    -- spi_clk_fedge <= not SCLK and SCLK_LAST;
    -- spi_clk_redge <= SCLK and not SCLK_LAST;
    -- the above confuses synthesis?
    
    -- The counter counts received bits from the master. Counter is enabled when
    -- falling edge of SPI clock is detected and not asserted CS_N.
    bit_number_p : process (CLK)
    begin
        if (rising_edge(CLK)) then
        
            SCLK_SYNC <= SCLK;
            CS_N_SYNC <= CS_N;
            MOSI_SYNC <= MOSI;
            SCLK_LAST <= SCLK_SYNC;
            
            spi_clk_fedge <= (not SCLK_SYNC) and SCLK_LAST;   
            spi_clk_redge <= (not SCLK_LAST) and SCLK_SYNC; 
    
            if(RX_READY = '1' ) then 
                RX_VALID_INT <= '0';
            end if;
            -- CPOL = 0: both sides sample on rising edge
            TX_READY_INT <= '0';
            
            if (RST = '1' or CS_N_SYNC = '1') then
                bit_number <= to_unsigned(7, bit_number'length);
                RX_VALID_INT <= '0';
            else
                
                if (spi_clk_fedge = '1') then
                    
                    -- Switch data on falling edge
                    TX_DATA_INT <= TX_DATA_INT(6 downto 0) & '0';
                    
                    if bit_number = 0 then
                        TX_READY_INT <= '1';
                        RX_VALID_INT <= '1';
                        RX_DATA      <= RX_DATA_INT;
                    end if;
                    
                    bit_number <= bit_number - 1;
                end if;
                if (spi_clk_redge = '1') then
                    -- sample data on rising edge
                    RX_DATA_INT <= RX_DATA_INT(6 downto 0) & MOSI_SYNC;
                end if;
            end if;
        end if;
    end process;


end RTL;