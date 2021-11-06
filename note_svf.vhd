----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------

-- here's what this nutso thing does
-- first, look at the flow diagram in Julius O Smith's paramstate Variable Filter writeup
-- we need to run a single pole twice, effectively doubling the input sample rate
-- thats what the OVERSAMPLEFACTOR is
-- the rest is just implimentation
-- and plumbing
-- hopefully this code never breaks lol


-- if each SVF oversample is 7 clocks (prime WRT 1024 so processes dont overlap)
-- and a new independant sample arrives every 4 clocks
-- total length of a process is 7*4 = 28 clocks

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

entity note_svf is
    
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
           
end note_svf;

architecture Behavioral of note_svf is

component ram_controller_18k_18 is
Port ( 
   DO             : out STD_LOGIC_VECTOR (ram_width18 - 1 downto 0);
   DI             : in  STD_LOGIC_VECTOR (ram_width18 - 1 downto 0);
   RDADDR         : in  STD_LOGIC_VECTOR (9 downto 0);
   RDCLK          : in  STD_LOGIC;
   RDEN           : in  STD_LOGIC;
   REGCE          : in  STD_LOGIC;
   RST            : in  STD_LOGIC;
   WE             : in  STD_LOGIC_VECTOR (1 downto 0);
   WRADDR         : in  STD_LOGIC_VECTOR (9 downto 0);
   WRCLK          : in  STD_LOGIC;
   WREN           : in  STD_LOGIC);
end component;

component ram_controller_36k_25 is
Port ( 
   DO             : out STD_LOGIC_VECTOR (STD_FLOWWIDTH - 1 downto 0);
   DI             : in  STD_LOGIC_VECTOR (STD_FLOWWIDTH - 1 downto 0);
   RDADDR         : in  STD_LOGIC_VECTOR (9 downto 0);
   RDCLK          : in  STD_LOGIC;
   RDEN           : in  STD_LOGIC;
   REGCE          : in  STD_LOGIC;
   RST            : in  STD_LOGIC;
   WE             : in  STD_LOGIC_VECTOR (3 downto 0);
   WRADDR         : in  STD_LOGIC_VECTOR (9 downto 0);
   WRCLK          : in  STD_LOGIC;
   WREN           : in  STD_LOGIC);
end component;

component param_lpf is
Port ( 
    clk100       : in STD_LOGIC;
    
    ZN2_ADDR_IN      : in unsigned (RAMADDR_WIDTH -1 downto 0); 
    Z00_PARAM_IN     : in signed(ram_width18 -1 downto 0);
    Z01_ALPHA_IN     : in signed(ram_width18 -1 downto 0);
    Z00_PARAM_OUT    : out signed(ram_width18 -1 downto 0);
    
    initRam100      : in std_logic;
    ram_rst100   : in std_logic;
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
end component;

attribute mark_debug : string;

constant MAX_PATH_LENGTH : integer := 7;
type polecount_by_stdflowwidth is array(0 to polecount-1) of sfixed(1 downto -STD_FLOWWIDTH + 2);

signal SVF_ALPHA : signed (RAM_WIDTH18-1 downto 0)  := to_signed(2**10, RAM_WIDTH18); 

-- unused ram signals
signal RAM_REGCE : std_logic := '0';
signal RAM18_WE  : std_logic_vector(1 downto 0) := "11";
signal RAM36_WE  : std_logic_vector(3 downto 0) := "1111";
signal RAM18_WE_DUB  : std_logic_vector(3 downto 0) := "1111";
signal RAM36_WE_DUB  : std_logic_vector(3 downto 0) := "1111";

signal Z05_FILT_FDRAW : unsigned(drawslog2-1 downto 0);
signal Z05_F     : std_logic_vector(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal Z07_F_LPF : signed(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal Z06_F     : signed(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal Z07_F     : std_logic_vector(RAM_WIDTH18-1 downto 0) := (others=>'0');

signal Z05_Q     : std_logic_vector(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal Z06_Q_LPF : signed(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal Z06_Q     : std_logic_vector(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal Z05_FILT_QDRAW : unsigned(drawslog2-1 downto 0);

signal ZN3_F_LPF : std_logic_vector(RAM_WIDTH18-1 downto 0) := (others=>'0');
signal ZN1_Q_LPF : std_logic_vector(RAM_WIDTH18-1 downto 0) := (others=>'0');
 
signal ZN2_BP     : polecount_by_stdflowwidth := (others=>(others=>'0'));
signal ZN1_POSTF0 : polecount_by_stdflowwidth := (others=>(others=>'0'));
signal Z02_SUM    : polecount_by_stdflowwidth := (others=>(others=>'0'));
signal Z02_POSTQ : polecount_by_stdflowwidth := (others=>(others=>'0'));
signal Z03_HP     : polecount_by_stdflowwidth := (others=>(others=>'0'));
signal Z04_POLE_OUT : polecount_by_stdflowwidth := (others=>(others=>'0'));
signal Z04_POSTF1     : polecount_by_stdflowwidth := (others=>(others=>'0'));

signal Z00_timeDiv : unsigned(1 downto 0);
signal Z01_timeDiv : unsigned(1 downto 0);
signal Z02_timeDiv : unsigned(1 downto 0);
signal Z03_timeDiv : unsigned(1 downto 0);

type topole_propagate_inner is array (Z00 to Z03) of sfixed(1 downto -STD_FLOWWIDTH + 2);
type topole_propagatetype is array (0 to polecount-1) of topole_propagate_inner;
signal POLE_IN : topole_propagatetype := (others=>(others=>(others=>'0')));

type lp_propagate_inner is array (ZN1 to Z07) of sfixed(1 downto -STD_FLOWWIDTH + 2);
type lp_propagatetype is array (0 to polecount-1) of lp_propagate_inner;
signal LP : lp_propagatetype := (others=>(others=>(others=>'0')));

type bp_propagate_inner is array (ZN2 to Z05) of sfixed(1 downto -STD_FLOWWIDTH + 2);
type bp_propagatetype is array (0 to polecount-1) of bp_propagate_inner;
signal BP : bp_propagatetype := (others=>(others=>(others=>'0')));

type f_propagate_inner is array (ZN2 to Z04) of sfixed(1 downto -RAM_WIDTH18 + 2);
type f_propagatetype is array (0 to polecount-1) of f_propagate_inner;
signal F  : f_propagatetype := (others=>(others=>(others=>'0')));

-- Q has 2 extra bits to accomodate values larger than 1
type q_propagate_inner is array (Z00 to MAX_PATH_LENGTH) of sfixed(3 downto -RAM_WIDTH18 + 4);
type q_propagatetype is array (0 to polecount-1) of q_propagate_inner;
signal Q  : q_propagatetype := (others=>(others=>(others=>'0')));

signal ZN4_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal ZN3_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal ZN2_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal ZN1_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal SVF_Z00_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z01_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z02_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z03_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z04_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z05_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z06_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z07_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z22_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');
signal Z27_ADDR : unsigned (RAMADDR_WIDTH-1 downto 0) := (others=>'0');

signal RAM_WREN    : std_logic := '0';
signal RAM_RDEN   : std_logic := '0';
signal VOICE_FILTQandF_RDEN: STD_LOGIC := '0';

signal Z04_currInst : integer range 0 to instcountlog2-1;

type Z02currinstarray is array (0 to polecount-1) of unsigned(RAMADDR_WIDTH-1 downto 0);
signal Z02_currInst : Z02currinstarray := (others=>(others=>'0'));
type Z03currtypearray is array (0 to polecount-1) of integer range 0 to ftypescount-1;
signal Z03_currtype : Z03currtypearray := (others=>0);

signal Z03_currtype_debug : unsigned(ftypeslog2 -1 downto 0);

signal ZN2_LP_OUT : std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal ZN3_BP_OUT : std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z27_BP_IN  : std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');
signal Z22_LP_IN  : std_logic_vector(STD_FLOWWIDTH-1 downto 0) := (others=>'0');

begin
RAM_RDEN <= not OUTSAMPLEF_ALMOSTFULL;
Z00_timeDiv  <= ZN4_ADDR(1 downto 0);
Z01_timeDiv  <= ZN3_ADDR(1 downto 0);
Z02_timeDiv  <= ZN2_ADDR(1 downto 0);
Z03_timeDiv  <= ZN1_ADDR(1 downto 0);

RAM_RDEN <= not OUTSAMPLEF_ALMOSTFULL;
VOICE_FILTQandF_RDEN <= not OUTSAMPLEF_ALMOSTFULL;

Z04_currInst <= to_integer(Z04_ADDR(RAMADDR_WIDTH -1 downto RAMADDR_WIDTH - instcountlog2));

-- timing proc does basic plumbing and timing
-- kind of a catchall process
timing_proc: process(clk100)
begin 
if rising_edge(clk100) then
RAM_WREN <= '0';
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    RAM_WREN <= '1';
    ZN4_ADDR <= ZN5_ADDR;
    ZN3_ADDR <= ZN4_ADDR;
    ZN2_ADDR <= ZN3_ADDR;
    ZN1_ADDR <= ZN2_ADDR;
    SVF_Z00_ADDR <= ZN1_ADDR;
    Z01_ADDR <= SVF_Z00_ADDR;
    Z02_ADDR <= Z01_ADDR;
    Z03_ADDR <= Z02_ADDR;
    Z04_ADDR <= Z03_ADDR;
    Z05_ADDR <= Z04_ADDR;
    Z06_ADDR <= Z05_ADDR;
    Z07_ADDR <= Z06_ADDR;
    Z22_ADDR <= ZN1_ADDR-22;
    Z27_ADDR <= ZN1_ADDR-27;
    
    Z03_currtype_debug <= to_unsigned(FILT_FTYPE(to_integer(Z02_currinst(0)(ramaddr_width -1 downto ramaddr_width - instcountlog2)), 0), ftypeslog2);
        
    -- only read into filter out such that filter out changes every
    -- 4 clocks, 0-aligned. this keeps us from sending junk to the next element
    -- 19 % 4 = 3
    if Z03_timeDiv = 0 then 
        Z20_FILTER_OUT <=Z04_POLE_OUT(3);
    end if;
    
    -- LP output is good on Z00 + MAXPATH*3 = 21
    -- 21 % 4 = Z01 time div
    Z22_LP_IN <= std_logic_vector(LP(to_integer(Z01_timeDiv))(Z00));
    
    -- BP output is good on Z05 + MAXPATH*3 = 26
    -- 26 % 4 = Z02 time div
    Z27_BP_IN <= std_logic_vector(BP(to_integer(Z02_timediv))(Z05)); 
    
    
    Z05_FILT_FDRAW <= FILT_FDRAW(Z04_currInst, to_integer(Z00_timeDiv));
    Z06_F <= CHOOSEMOD3(Z05_FILT_FDRAW, signed(Z05_F), Z05_OS, Z05_COMPUTED_ENVELOPE);
    Z07_F <= std_logic_vector(Z06_F);
    
    Z05_FILT_QDRAW <= FILT_QDRAW(Z04_currInst, to_integer(Z00_timeDiv));
    Z06_Q <= std_logic_vector(CHOOSEMOD3(Z05_FILT_QDRAW, signed(Z05_Q), Z05_OS, Z05_COMPUTED_ENVELOPE));
            
end if;
end if;
end process;     
    
    
-- filtf ram
i_filtf_ram: ram_controller_18k_18 
port map (
    DO         => Z05_F,
    DI         => MEM_IN,
    RDADDR     => std_logic_vector(Z04_ADDR),
    RDCLK      => clk100,
    RDEN       => VOICE_FILTQandF_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => VOICE_FILTF_WREN);
    
i_f_lpf: param_lpf port map (
    clk100       => clk100, 
    
    ZN2_ADDR_IN   => Z05_ADDR, 
    Z00_PARAM_IN  => signed(Z07_F), 
    Z01_ALPHA_IN  => signed(SVF_ALPHA), 
    Z00_PARAM_OUT => Z07_F_LPF, 
    
    initRam100      => initRam100, 
    ram_rst100   => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
        
    
-- filtf ram lpf
i_filtf_ram_lpf: ram_controller_18k_18 
port map (
    DO         => ZN3_F_LPF,
    DI         => std_logic_vector(Z07_F_LPF),
    RDADDR     => std_logic_vector(ZN4_ADDR),
    RDCLK      => clk100,
    RDEN       => VOICE_FILTQandF_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(Z07_ADDR),
    WRCLK      => clk100,
    WREN       => RAM_WREN);
        
-- filtf ram
i_filtq_ram: ram_controller_18k_18 
port map (
    DO         => Z05_Q,
    DI         => MEM_IN,
    RDADDR     => std_logic_vector(Z04_ADDR),
    RDCLK      => clk100,
    RDEN       => VOICE_FILTQandF_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => MEM_WRADDR,
    WRCLK      => clk100,
    WREN       => VOICE_FILTQ_WREN);
    
i_q_lpf: param_lpf port map (
    clk100       => clk100, 
    
    ZN2_ADDR_IN   => Z04_ADDR, 
    Z00_PARAM_IN  => signed(Z06_Q), 
    Z01_ALPHA_IN  => signed(SVF_ALPHA), 
    Z00_PARAM_OUT => Z06_Q_LPF, 
    
    initRam100      => initRam100, 
    ram_rst100   => ram_rst100, 
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    );
        
-- filtq ram reposition
i_filtq_ram_lpf: ram_controller_18k_18 
port map (
    DO         => ZN1_Q_LPF,
    DI         => std_logic_vector(Z06_Q_LPF),
    RDADDR     => std_logic_vector(ZN2_ADDR),
    RDCLK      => clk100,
    RDEN       => VOICE_FILTQandF_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM18_WE,
    WRADDR     => std_logic_vector(Z06_ADDR),
    WRCLK      => clk100,
    WREN       => RAM_WREN);
    
    
i_lp_ram: ram_controller_36k_25
port map (
    DO         => ZN2_LP_OUT,
    DI         => std_logic_vector(Z22_LP_IN),
    RDADDR     => std_logic_vector(ZN3_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM36_WE_DUB,
    WRADDR     => std_logic_vector(Z22_ADDR),
    WRCLK      => clk100,
    WREN       => RAM_WREN);

i_bp_ram: ram_controller_36k_25
port map (
    DO         => ZN3_BP_OUT,
    DI         => std_logic_vector(Z27_BP_IN),
    RDADDR     => std_logic_vector(ZN4_ADDR),
    RDCLK      => clk100,
    RDEN       => RAM_RDEN,
    REGCE      => RAM_REGCE,
    RST        => ram_rst100,
    WE         => RAM36_WE_DUB,
    WRADDR     => std_logic_vector(Z27_ADDR),
    WRCLK      => clk100,
    WREN       => RAM_WREN);

poleloop:
for pole in 0 to polecount-1 generate
    
process_proc: process(clk100)
begin 
if rising_edge(clk100) then
if initRam100 = '0' and  OUTSAMPLEF_ALMOSTFULL='0' then
    
    -- propagate signals
    
    -- LP and BP are both "split" signals
    -- in that they include both old value and new value
    -- in a single array. the update is explicitly described here
    -- to avoid "multiply driven" error
    
    -- first lp is either read from memory or from output of previous oversample
    if pole = Z02_timeDiv then -- Zn2 = z02 time div
        LP(pole)(ZN1) <= sfixed(ZN2_LP_OUT); 
    else
        LP(pole)(ZN1) <= LP(pole)(Z05); 
    end if;
    lp_proploop:
    for propnum in LP(0)'low+1 to LP(0)'high loop
        LP(pole)(propnum) <= LP(pole)(propnum-1);
    end loop;
    
    -- the first BP is either read from ram (first oversample)
    if pole = Z01_timeDiv then
        BP(pole)(ZN2) <= sfixed(ZN3_BP_OUT); 
    else -- or from the previous output (subsequant oversamples)
        BP(pole)(ZN2) <= resize(Z04_POSTF1(pole) + BP(pole)(Z04), BP(0)(0), fixed_saturate, fixed_truncate);
    end if;
    bp_proploop:
    for propnum in BP(0)'low+1 to BP(0)'high loop
        BP(pole)(propnum) <= BP(pole)(propnum-1);
    end loop;
    
    pole_proploop:
    for propnum in POLE_IN(0)'low+1 to POLE_IN(0)'high loop
        POLE_IN(pole)(propnum) <= POLE_IN(pole)(propnum-1);
    end loop;
    -- pole 0 is referred to explicitly here
    -- rather than outside of generate loop
    -- so that the arrays are not "multiply driven"
    if pole = 0 then
        -- first pole, first oversample input from filter_in 
        POLE_IN(pole)(Z01) <= Z00_FILTER_IN; 
    else
        -- subsequent first oversamples from previous pole output
        POLE_IN(pole)(Z00) <= Z04_POLE_OUT(pole-1);  
    end if;

    -- read first f value from ram
    if pole = Z01_timeDiv then
        F(pole)(ZN2) <= sfixed(ZN3_F_LPF);
    else  
        F(pole)(ZN2) <= F(pole)(Z04);
    end if;
    f_proploop:
    for propnum in F(0)'low+1 to F(0)'high loop
        F(pole)(propnum) <= F(pole)(propnum-1);
    end loop;
    
    -- read first q value from ram
    if pole = Z03_timeDiv then
        Q(pole)(Z00) <= sfixed(ZN1_Q_LPF);
    else
        Q(pole)(Z00) <= Q(pole)(Z06);
    end if;
    q_proploop:
    for propnum in Q(0)'low+1 to Q(0)'high loop
        Q(pole)(propnum) <= Q(pole)(propnum-1);
    end loop;
        
    -- the filter type is the only parameter in SVF which is not note-independant
    -- it is draw from the current instrument, which is set by the low 3 bits of
    -- the current address
    Z02_currinst(pole) <= Z01_ADDR - pole * 5;
    Z03_currtype(pole) <= FILT_FTYPE(to_integer(Z02_currinst(pole)(ramaddr_width -1 downto ramaddr_width - instcountlog2)), pole);
    case Z03_currtype(pole) is
        when FTYPE_NONE_I =>
            Z04_POLE_OUT(pole) <= POLE_IN(pole)(Z03);
        when FTYPE_BP_I =>
            Z04_POLE_OUT(pole) <= BP(pole)(Z03);
        when FTYPE_LP_I =>
            Z04_POLE_OUT(pole) <= LP(pole)(Z03);
        when OTHERS =>
            Z04_POLE_OUT(pole) <= Z03_HP(pole);
    end case;
        
    -- now we can begin the actual math processing
    -- POSTFs can be without saturation because F is on range [0,1]
    ZN1_POSTF0(pole) <= resize( BP(pole)(ZN2)      * F(pole)(ZN2)     , ZN1_POSTF0(pole), fixed_wrap    , fixed_truncate);
    LP(pole)(Z00)    <= resize( LP(pole)(ZN1)      + ZN1_POSTF0(pole) , LP(pole)(Z00)   , fixed_saturate, fixed_truncate);
    Z02_SUM(pole)    <= resize( POLE_IN(pole)(Z01) - LP(pole)(Z01)    , Z02_SUM(pole)   , fixed_saturate, fixed_truncate);
    Z02_POSTQ(pole)  <= resize( BP(pole)(Z01)      * Q(pole)(Z01)     , Z02_POSTQ(pole) , fixed_saturate, fixed_truncate);
    Z03_HP(pole)     <= resize( Z02_POSTQ(pole)    + Z02_SUM(pole)    , Z03_HP(pole)    , fixed_saturate, fixed_truncate);
    Z04_POSTF1(pole) <= resize( Z03_HP(pole)       * F(pole)(Z03)     , Z04_POSTF1(pole), fixed_wrap    , fixed_truncate);
    BP(pole)(Z05)    <= resize( Z04_POSTF1(pole)   + BP(pole)(Z04)    , BP(pole)(Z05)   , fixed_saturate, fixed_truncate);
    
end if;
end if;
end process;
end generate;
end Behavioral;
