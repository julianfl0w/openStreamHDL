library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY note_svf_tb IS 
END note_svf_tb;

ARCHITECTURE behavior OF note_svf_tb IS
-- Component Declaration for the Unit Under Test (UUT)
COMPONENT note_svf

--just copy and paste the input and output ports of your module as such. 

Port ( 
    clk100     : in STD_LOGIC;
    ZN5_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
            
    Z20_FILTER_OUT: out sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
    Z00_FILTER_IN : in  sfixed(1 downto -STD_FLOWWIDTH + 2);
    
    Z05_OS     : in oneshotspervoice_by_ramwidth18s;
    Z05_COMPUTED_ENVELOPE: in inputcount_by_ramwidth18s;
    
    MEM_WRADDR    : in STD_LOGIC_VECTOR(RAMADDR_WIDTH-1 downto 0);
    MEM_IN        : in STD_LOGIC_VECTOR(ram_width18-1 downto 0); 
    VOICE_FILTQ_WREN: in STD_LOGIC;
    VOICE_FILTF_WREN: in STD_LOGIC;
    FILT_FDRAW : in instcount_by_polecount_by_drawslog2;
    FILT_QDRAW : in instcount_by_polecount_by_drawslog2;
    FILT_FTYPE : in instcount_by_polecount_by_ftypeslog2;
    
    ram_rst100    : in std_logic;
    initRam100       : in std_logic;
    OUTSAMPLEF_ALMOSTFULL  : in std_logic
    );
    
END COMPONENT;

component ram_active_rst is
Port ( 
    clkin       : in STD_LOGIC;
    clksrdy     : in STD_LOGIC;
    ram_rst     : out STD_LOGIC := '0';
    initializeRam_out : out std_logic := '1'
    );
end component;
   
component interpolate_oversample_4 is
Port ( 
    clk100     : in STD_LOGIC;
    
    ZN1_ADDR      : in unsigned (RAMADDR_WIDTH-1 downto 0);
    Z01_INTERP_OUT: out sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    Z00_INTERP_IN : in  sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    
    ram_rst100    : in std_logic;
    initRam100       : in std_logic;
    OUTSAMPLEF_ALMOSTFULL  : in std_logic
    );
end component;
   
-- Clock period definitions
constant clk100_period : time := 10 ns;
signal clk100          : STD_LOGIC := '0';

constant VOICENUM : integer := 0;

-- 10ms ~= 100 Hz
constant square_period : time := 1 ms;
signal square          : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal saw             : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');

signal ZN1_ADDR        : unsigned ( 9 downto 0) := (others=>'0');
signal ZN3_ADDR        : unsigned ( 9 downto 0) := (others=>'0');
signal ZN4_ADDR        : unsigned ( 9 downto 0) := (others=>'0');
        
signal Z21_FILTER_OUT  : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
    
signal Z06_OS       : oneshotspervoice_by_ramwidth18s := (others=>(others=>'0'));
signal Z06_COMPUTED_ENVELOPE  : inputcount_by_ramwidth18s := (others=>(others=>'0'));

signal MEM_WRADDR      : STD_LOGIC_VECTOR (9 downto 0) := (others=>'0');
signal MEM_IN          : STD_LOGIC_VECTOR(ram_width18-1 downto 0) := (others=>'0');
signal VOICE_FILTQ_WREN : STD_LOGIC := '0';
signal VOICE_FILTF_WREN : STD_LOGIC := '0';

signal FILT_FDRAW   : instcount_by_polecount_by_drawslog2  := (others=>(others=>(others=>'0')));
signal FILT_QDRAW   : instcount_by_polecount_by_drawslog2  := (others=>(others=>(others=>'0')));
signal FILT_FTYPE   : instcount_by_polecount_by_ftypeslog2 := (others=>(others=>0));

signal initRam100         : std_logic;
signal ram_rst100      : std_logic;
signal OUTSAMPLEF_ALMOSTFULL    : std_logic := '0';

signal clksrdy : std_logic := '1';
signal SAMPLECOUNT : integer := 0;

signal Z01_INTERP_OUT: sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
signal Z00_INTERP_IN : sfixed(1 downto -STD_FLOWWIDTH + 2) := (others=>'0');
    
constant INSTNUM : integer := 0;
    
BEGIN
-- Instantiate the Unit(s) Under Test
i_note_svf: note_svf PORT MAP (
    clk100         => clk100,
    ZN5_ADDR       => ZN4_ADDR, 
            
    Z20_FILTER_OUT => Z21_FILTER_OUT,
    Z00_FILTER_IN  => Z01_INTERP_OUT,
    
    Z05_OS      => Z06_OS,
    Z05_COMPUTED_ENVELOPE => Z06_COMPUTED_ENVELOPE,
    
    MEM_WRADDR     => MEM_WRADDR,
    MEM_IN         => MEM_IN,
    VOICE_FILTQ_WREN => VOICE_FILTQ_WREN,
    VOICE_FILTF_WREN => VOICE_FILTF_WREN,
    FILT_FDRAW  => FILT_FDRAW,
    FILT_QDRAW  => FILT_QDRAW,
    FILT_FTYPE  => FILT_FTYPE,
    
    ram_rst100    => ram_rst100,
    initRam100       => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    ); 

i_ram_active_rst: ram_active_rst port map(
    clkin              => clk100,
    clksrdy            => clksrdy,
    ram_rst            => ram_rst100,
    initializeRam_out  => initRam100
    );
    
i_interpolate_oversample_4: interpolate_oversample_4 Port map( 
    clk100      => clk100,

    ZN1_ADDR      => ZN1_ADDR,
    Z01_INTERP_OUT=> Z01_INTERP_OUT,
    Z00_INTERP_IN => Z00_INTERP_IN,
    
    ram_rst100    => ram_rst100,
    initRam100       => initRam100,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
    
-- Clock process definitions( clock with 50% duty cycle is generated here.)
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

        if  OUTSAMPLEF_ALMOSTFULL='0' then
            ZN1_ADDR <= ZN1_ADDR +1;
            ZN4_ADDR <= ZN1_ADDR +4;
            ZN3_ADDR <= ZN4_ADDR;
            
            if unsigned(ZN1_ADDR) >= 0 and unsigned(ZN1_ADDR) < 4 then
                -- frequency / 48e3  = thisadd / 2**24
                -- thisadd = frequency * 2**24 / 48e3
                saw <= resize(saw + to_sfixed(0.005, saw), saw,  fixed_wrap, fixed_truncate);
--                if SAW(SAW'high) = '1' then
--                    Z00_FILTER_IN <= to_signed( 2**23, STD_FLOWWIDTH);
--                else
--                    Z00_FILTER_IN <= to_signed(-2**23, STD_FLOWWIDTH);
--                end if;

                Z00_INTERP_IN <= SQUARE;
                --Z00_INTERP_IN <= resize(-signed(SAW), STD_FLOWWIDTH);
                --Z00_INTERP_IN <= to_signed(2**10, STD_FLOWWIDTH);
            else
                Z00_INTERP_IN <= (others=>'0');
            end if;
        end if;
        
        SAMPLECOUNT <= SAMPLECOUNT + 1;
--        if SAMPLECOUNT < 20 then
--            OUTSAMPLEF_ALMOSTFULL <= '1';
--        else
--            OUTSAMPLEF_ALMOSTFULL <= '0';
--        end if;
        
        if SAMPLECOUNT = 30 then
            samplecount <= 0;
        end if;
    end if;
end process;

-- generate a square wave
square_proc: process
begin
    square <= to_sfixed(2**22 , square);
    wait for square_period/2;
    square <= to_sfixed(-2**22, square);
    wait for square_period/2;
end process;


-- this simple test ensures basic functionality of the paramstate variable filter 

note_svfproc: process
begin
    wait until initRam100 = '0';
    -- create basic butterworth
    -- draw from constant
    
    pole_loop:
    for pole in 0 to polecount -1 loop
    FILT_FDRAW(INSTNUM, pole) <= to_unsigned(DRAW_FIXED_I, drawslog2);
    -- draw q from constant
    FILT_QDRAW(INSTNUM, pole) <= to_unsigned(DRAW_FIXED_I, drawslog2);
    -- FTYPE : lowpass
    FILT_FTYPE(INSTNUM, pole) <= FTYPE_BP_I;
    end loop;
    
    FILT_FTYPE(INSTNUM, 3) <= FTYPE_LP_I;
    -- where F is [0,1] fixed point, 2**16 == 1
    -- f = 2*sin(pi* fc/ fs) * 2**16
    -- f = 2*sin(pi*.01) * 2**16
    
    MEM_WRADDR <= (others=>'0');
    MEM_IN <= STD_LOGIC_VECTOR(to_signed(4117, 18));
    VOICE_FILTF_WREN <= '1';
    wait until rising_edge(clk100);
    MEM_WRADDR <= STD_LOGIC_VECTOR(unsigned(MEM_WRADDR)+5);
    wait until rising_edge(clk100);
    MEM_WRADDR <= STD_LOGIC_VECTOR(unsigned(MEM_WRADDR)+5);
    wait until rising_edge(clk100);
    MEM_WRADDR <= STD_LOGIC_VECTOR(unsigned(MEM_WRADDR)+5);
    wait until rising_edge(clk100);
    VOICE_FILTF_WREN <= '0';
    
    -- q is on scale 2**14 = 1
    -- -1/sqrt(2) is butterworth
    -- qc = 1/q
    -- so q = -2**14*sqrt(2) = -23170
    
    MEM_WRADDR <= (others=>'0');    
    MEM_IN <= STD_LOGIC_VECTOR(to_signed(-23170, 18));
    VOICE_FILTQ_WREN <= '1';
    wait until rising_edge(clk100);
    MEM_WRADDR <= STD_LOGIC_VECTOR(unsigned(MEM_WRADDR)+5);
    wait until rising_edge(clk100);
    MEM_WRADDR <= STD_LOGIC_VECTOR(unsigned(MEM_WRADDR)+5);
    wait until rising_edge(clk100);
    MEM_WRADDR <= STD_LOGIC_VECTOR(unsigned(MEM_WRADDR)+5);
    wait until rising_edge(clk100);
    VOICE_FILTQ_WREN <= '0';
    
    wait;
end process;

END;