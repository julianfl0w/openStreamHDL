----------------------------------------------------------------------------------
-- Julian Loiacono 10/2017
--
-- Module Name: oscillators - Behavioral
--
-- Description: Generate an low-volume sine wave, at around 400 Hz
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;
library work;
use work.spectral_pkg.all;

entity rationalize is
Generic(
    ram_width18   : integer := 18;
    ramaddr_width : integer := 18
);
Port ( 
    clk       : in STD_LOGIC;
    
    ZN3_ADDR     : in unsigned (RAMADDR_WIDTH -1 downto 0); -- Z01
    Z00_IRRATIONAL: in signed (ram_width18 -1 downto 0); -- Z01
    OSC_HARMONICITY_WREN   : in std_logic;
    MEM_IN       : in std_logic_vector(ram_width18 -1 downto 0);
    MEM_WRADDR   : in std_logic_vector(RAMADDR_WIDTH -1 downto 0);
    
    ZN2_RATIONAL : out signed(ram_width18-1 downto 0) := (others=>'0');
   
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
           
end rationalize;

architecture Behavioral of rationalize is
component ram_controller_18k_18 is
Port ( 
    DO             : out STD_LOGIC_VECTOR (ram_width18 -1 downto 0);
    DI             : in  STD_LOGIC_VECTOR (ram_width18 -1 downto 0);
    RDADDR         : in  STD_LOGIC_VECTOR (ramaddr_width-1 downto 0);
    RDCLK          : in  STD_LOGIC;
    RDEN           : in  STD_LOGIC;
    REGCE          : in  STD_LOGIC;
    RST            : in  STD_LOGIC;
    WE             : in  STD_LOGIC_VECTOR (1 downto 0);
    WRADDR         : in  STD_LOGIC_VECTOR (ramaddr_width-1 downto 0);
    WRCLK          : in  STD_LOGIC;
    WREN           : in  STD_LOGIC);
end component;
   
signal RAM_REGCE     : std_logic := '0';
signal RAM18_WE      : STD_LOGIC_VECTOR (1 downto 0) := (others => '1');   
signal RAM_RDEN      : std_logic := '0';

signal REPOSITION_WREN : std_logic := '0';

attribute mark_debug : string;
signal ZN2_RATIONAL_oscdet_int : std_logic_vector(ram_width18-1 downto 0) := (others=>'0');
signal Z00_OSC_HARMONICITY : std_logic_vector(ram_width18-1 downto 0) := (others=>'0');
signal Z01_OSC_HARMONICITY : std_logic_vector(ram_width18-1 downto 0) := (others=>'0');

-- signals for nearest rational approx
constant decPlace : natural := 14;
constant RATIONALADD_LOW  : natural := Z01;
constant RATIONALADD_HIGH : natural := RAM_WIDTH18;

type PROPTYPE23    is array (1 to RAM_WIDTH18) of signed(ram_width18-1 + 5 downto 0);
type PROPTYPE18    is array (1 to RAM_WIDTH18) of signed(ram_width18-1 downto 0);
type PROPTYPE16    is array (1 to RAM_WIDTH18) of unsigned(decPlace-1 downto 0);
type PROPTYPE6     is array (1 to RAM_WIDTH18) of signed(6-1 downto 0);
type PROPTYPENUM   is array (1 to RAM_WIDTH18) of signed(ram_width18-1 + 5 - decPlace downto 0);
type PROPTYPE_OSCDET is array (ZN1 to Z21) of signed(ram_width18-1 downto 0);
signal SUM : PROPTYPE23 := (others=>(others=>'0'));
signal IRR : PROPTYPE18 := (others=>(others=>'0'));
signal OSC_HARMONICITY  : PROPTYPE18 := (others=>(others=>'0'));
signal MAXFRAC : PROPTYPE16 := (others=>(others=>'0'));
signal DEN : PROPTYPE6  := (others=>"000001");
signal NUM : PROPTYPENUM  := (others=>(others=>'0'));
signal ZN1_addr : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal ZN4_ADDR : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal Z19_addr : unsigned(RAMADDR_WIDTH - 1 downto 0) := (others => '0');
signal Z19_rational : std_logic_vector(ram_width18-1 downto 0) := (others=>'0');
signal ZN3_RATIONAL : std_logic_vector(ram_width18-1 downto 0) := (others=>'0');

type inversesArray is array(1 to RAM_WIDTH18) of signed(RAM_WIDTH18 - 1 downto 0);
constant inverse : inversesArray :=
(
to_signed((2**decPlace / 1 ), RAM_WIDTH18),
to_signed((2**decPlace / 2 ), RAM_WIDTH18),
to_signed((2**decPlace / 3 ), RAM_WIDTH18),
to_signed((2**decPlace / 4 ), RAM_WIDTH18),
to_signed((2**decPlace / 5 ), RAM_WIDTH18),
to_signed((2**decPlace / 6 ), RAM_WIDTH18),
to_signed((2**decPlace / 7 ), RAM_WIDTH18),
to_signed((2**decPlace / 8 ), RAM_WIDTH18),
to_signed((2**decPlace / 9 ), RAM_WIDTH18),
to_signed((2**decPlace / 10), RAM_WIDTH18),
to_signed((2**decPlace / 11), RAM_WIDTH18),
to_signed((2**decPlace / 12), RAM_WIDTH18),
to_signed((2**decPlace / 13), RAM_WIDTH18),
to_signed((2**decPlace / 14), RAM_WIDTH18),
to_signed((2**decPlace / 15), RAM_WIDTH18),
to_signed((2**decPlace / 16), RAM_WIDTH18),
to_signed((2**decPlace / 17), RAM_WIDTH18),
to_signed((2**decPlace / 18), RAM_WIDTH18)
);

signal Z00_timeDiv : integer range 0 to time_divisions -1 := 0;
begin 
Z00_timeDiv <= to_integer(ZN3_ADDR(1 downto 0) + 3);

i_harmonicity_ram: ram_controller_18k_18 port map (
    DO         => Z00_OSC_HARMONICITY,
    DI         => std_logic_vector(MEM_IN),
    RDADDR     => std_logic_vector(ZN1_ADDR),
    RDCLK      => clk,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(MEM_WRADDR),
    WRCLK      => clk,
    WREN       => OSC_HARMONICITY_WREN);
        
i_reposition_ram: ram_controller_18k_18 port map (
    DO         => ZN3_RATIONAL,
    DI         => std_logic_vector(Z19_RATIONAL),
    RDADDR     => std_logic_vector(ZN4_ADDR),
    RDCLK      => clk,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(Z19_ADDR ),
    WRCLK      => clk,
    WREN       => REPOSITION_WREN);
        
phase_proc: process(clk)
begin
if rising_edge(clk) then

REPOSITION_WREN <= '0';

if initRam100 = '0' and OUTSAMPLEF_ALMOSTFULL='0' then
    ZN2_RATIONAL <= signed(ZN3_RATIONAL);

    Z01_OSC_HARMONICITY <= Z00_OSC_HARMONICITY;
    ZN1_addr <= ZN3_addr - Z01;
    ZN4_ADDR <= ZN1_addr + 4;
    Z19_addr <= ZN1_addr - Z19;
    
-- rationalize!
-- determine the residual fraction for irrational*1, irrational *2, ... , irrational*18
-- the minimum of these indicates the numerator and denominator of rational approximation

    -- the irrational number is propagated
    IRR(1)     <= Z00_IRRATIONAL;
    -- sum is increased by IRR every clock, and starts at IRR
    SUM(1)     <= resize(Z00_IRRATIONAL, SUM(4)'length);
    -- MAXFRAC is the absolute distance from 0
    --MAXFRAC(address, Z04) <= abs(signed(Z03_OSC_DETUNE(decPlace-1 downto 0)));
    -- MAXFRAC is the distance above 0
    -- but only if harmon(0) is indicated
    if Z00_OSC_HARMONICITY(0) = '1' then
        MAXFRAC(1) <= unsigned(Z00_IRRATIONAL(decPlace-1 downto 0));
    else
        --MAXFRAC(1) <= (others=>'1');
        -- start MAXFRAC at 0 because this is a ceining function
        MAXFRAC(1) <= (others=>'0');
    end if;
    
    -- the denominator starts with 1
    DEN(1)     <= to_signed(1, DEN(1)'length);
    -- the numerator is the integer part of the irrational number
    NUM(1)     <= resize(Z00_IRRATIONAL(ram_width18-1 downto decPlace), NUM(1)'length);

    OSC_HARMONICITY(1) <= signed(Z00_OSC_HARMONICITY);
    
    proploop:
    for propnum in 2 to RAM_WIDTH18 loop
        IRR(propnum) <= IRR(propnum-1);
        SUM(propnum) <= SUM(propnum-1) + IRR(propnum-1);
        OSC_HARMONICITY(propnum) <= OSC_HARMONICITY(propnum-1);
        
        --this conditional finds nearest neighbor
        --if  abs(signed(SUM(propnum-1)(decPlace-1 downto 0))) < MAXFRAC(propnum-1)
        --but we want lowest neighbor
        --if  unsigned(SUM(propnum-1)(decPlace-1 downto 0)) <= MAXFRAC(propnum-1)
        -- but we want highest neighbor
        if  unsigned(SUM(propnum-1)(decPlace-1 downto 0)) >= MAXFRAC(propnum-1)
        and OSC_HARMONICITY(propnum - 1)(propnum -2) = '1' then
            --MAXFRAC(propnum) <= abs(signed(SUM(propnum-1)(decPlace-1 downto 0)));
            MAXFRAC(propnum) <= unsigned(SUM(propnum-1)(decPlace-1 downto 0));
            DEN(propnum) <= to_signed(propnum - 1, DEN(RATIONALADD_LOW)'length);
            -- because this is a ceiling type, add 1 to numerator here
            NUM(propnum) <= SUM(propnum-1)(ram_width18-1 + 5 downto decPlace) + 1;
        else
            --otherwise, propagate
            MAXFRAC(propnum) <= MAXFRAC(propnum-1);
            DEN(propnum) <= DEN(propnum-1);
            NUM(propnum) <= NUM(propnum-1);
        end if;
    end loop;
    
    -- output irrational if no harmonicity set
    if OSC_HARMONICITY(Z18) = 0 then
        Z19_rational <= std_logic_vector(IRR(Z18));
    else
        Z19_rational <= std_logic_vector(MULT(NUM(RAM_WIDTH18),
        inverse(to_integer(den(RAM_WIDTH18))), RAM_WIDTH18, 4 + 5));
    end if;
    REPOSITION_WREN <= '1';
    
end if;
end if;
end process;
    
RAM_RDEN   <= not OUTSAMPLEF_ALMOSTFULL;

end Behavioral;