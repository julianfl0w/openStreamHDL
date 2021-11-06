library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY rationalize_tb IS 
END rationalize_tb;

ARCHITECTURE behavior OF rationalize_tb IS
-- Component Declaration for the Unit Under Test (UUT)
--just copy and paste the input and output ports of your module as such. 
COMPONENT rationalize
Port ( 
    clk100       : in STD_LOGIC;

    ZN3_ADDR     : in unsigned (RAMADDR_WIDTH -1 downto 0); -- Z01
    Z00_IRRATIONAL: in signed (ram_width18 -1 downto 0); -- Z01
    OSC_HARMONICITY_WREN   : in std_logic;
    OSC_HARMONICITY_ALPHA_WREN: in std_logic;
    MEM_IN       : in std_logic_vector(ram_width18 -1 downto 0);
    MEM_WRADDR   : in std_logic_vector(RAMADDR_WIDTH -1 downto 0);
    
    Z02_RATIONAL_oscdet : out std_logic_vector(ram_width18-1 downto 0) := (others=>'0');
    
    ALPHA_WRITE  : in unsigned(5 downto 0);
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
END COMPONENT;


component ram_active_rst is
Port ( 
    clkin       : in STD_LOGIC;
    ram_rst     : out STD_LOGIC;
    clksRdy     : in STD_LOGIC;
    initializeRam_out : out std_logic
    );
end component;
   
-- Clock period definitions
constant clk100_period : time := 10 ns;

signal clk100       : STD_LOGIC := '0';

signal OUTSAMPLEF_ALMOSTFULL : std_logic := '0';
    
signal ZN3_ADDR : unsigned (RAMADDR_WIDTH -1 downto 0) := (others=>'0'); -- Z01
    
signal OSC_HARMONICITY_WREN   : std_logic;
signal OSC_HARMONICITY_ALPHA_WREN: std_logic;
signal MEM_IN       : std_logic_vector(ram_width18 -1 downto 0);
signal MEM_WRADDR   : std_logic_vector(RAMADDR_WIDTH -1 downto 0);
    
signal clksRdy    : std_logic := '1';
signal initRam100    : std_logic;
signal ram_rst100 : std_logic;

signal Z00_IRRATIONAL: signed (ram_width18 -1 downto 0) := (others=>'0');
signal Z02_RATIONAL_oscdet : std_logic_vector(ram_width18-1 downto 0) := (others=>'0');
signal ALPHA_WRITE  : unsigned(5 downto 0) := (others=>'0');

signal initTimer : integer := 0;

BEGIN

i_rationalize: rationalize Port map ( 
    clk100         => clk100,
    
    ZN3_ADDR       => ZN3_ADDR,
    Z00_IRRATIONAL => Z00_IRRATIONAL,
    OSC_HARMONICITY_WREN   => OSC_HARMONICITY_WREN, 
    OSC_HARMONICITY_ALPHA_WREN => OSC_HARMONICITY_ALPHA_WREN,
    MEM_IN       => MEM_IN,
    MEM_WRADDR   => MEM_WRADDR,
    
    Z02_RATIONAL_oscdet   => Z02_RATIONAL_oscdet,
    
    ALPHA_WRITE => ALPHA_WRITE,
    
    initRam100     => initRam100,
    ram_rst100  => ram_rst100,
    OUTSAMPLEF_ALMOSTFULL   => OUTSAMPLEF_ALMOSTFULL
    );
    
i_ram_active_rst: ram_active_rst port map(
    clkin              => clk100,
    ram_rst            => ram_rst100,
    clksRdy            => clksRdy,
    initializeRam_out  => initRam100
    );

-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

timing_proc: process(clk100)
begin
    if rising_edge(clk100) then
        ZN3_ADDR <= ZN3_ADDR +1;
        --Z00_IRRATIONAL <= Z00_IRRATIONAL + 1;
        Z00_IRRATIONAL <= to_signed(2**12, RAM_WIDTH18);
        --Z00_IRRATIONAL <= to_signed(21500, RAM_WIDTH18); 
    end if;
end process;

init_proc: process(clk100)
begin
    if rising_edge(clk100) then
       OSC_HARMONICITY_WREN  <= '0';
       OSC_HARMONICITY_ALPHA_WREN  <= '0';
        if initRam100 = '0' then
            initTimer <= initTimer + 1;
            MEM_WRADDR <= STD_LOGIC_VECTOR(to_unsigned(initTimer, MEM_WRADDR'length));
            if(initTimer < 1024) then
                MEM_IN <= "000000000000010000";
                OSC_HARMONICITY_WREN  <= '1';
            elsif initTimer < 2048 then
               OSC_HARMONICITY_ALPHA_WREN  <= '1';
                MEM_IN <= "010000000000000000";
            end if;
        end if;
    end if;
end process;

END;
