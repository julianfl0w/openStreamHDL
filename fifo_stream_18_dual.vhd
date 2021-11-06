-- A fifo for streaming

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

ENTITY fifo_stream_18_dual IS
    GENERIC(
        FIFO_SIZE : string := "18Kb"
    );
    PORT (
        inclk  : IN std_logic;
        outclk : IN std_logic;
        rst    : IN std_logic;
        din_ready  : out std_logic;
        din_valid  : IN  std_logic;
        din_data   : IN  std_logic_vector;
        dout_ready : IN  std_logic;
        dout_valid : out std_logic;
        dout_data  : out std_logic_vector
    );
END fifo_stream_18_dual;

architecture Behavioral of fifo_stream_18_dual is

signal fifo_almostfull : std_logic := '0';
signal fifo_almostempty: std_logic := '0';
signal fifo_empty : std_logic := '1';
signal peek_data  : std_logic_vector(din_data'high downto din_data'low);
signal peek_valid : std_logic := '0';
signal dout_valid_int : std_logic := '0';
signal fifo_rden   : std_logic := '0';
signal fifo_wren   : std_logic := '0';
signal din_ready_int   : std_logic := '0';
signal in_resetcount   : integer := 0;
signal in_initialized  : std_logic := '0';
signal in_initialized_and  : std_logic := '0';
signal out_resetcount  : integer := 0;
signal out_initialized : std_logic := '0';
signal out_initialized_and : std_logic := '0';

signal fifo_FULL    : std_logic := '0';
signal fifo_RDERR   : std_logic := '0';
signal fifo_WRERR   : std_logic := '0';
signal fifo_rdcount : std_logic_vector(10 downto 0);
signal fifo_wrcount : std_logic_vector(10 downto 0);
Attribute mark_debug : String;
Attribute mark_debug Of fifo_FULL    : Signal Is "true";
Attribute mark_debug Of fifo_RDERR   : Signal Is "true";
Attribute mark_debug Of fifo_WRERR   : Signal Is "true";
Attribute mark_debug Of fifo_rdcount : Signal Is "true";
Attribute mark_debug Of fifo_wrcount : Signal Is "true";
      
BEGIN
    fifo_wren <= in_initialized_and and din_valid and din_ready_int;
    din_ready <= din_ready_int;
    din_ready_int <= not fifo_almostfull;
    dout_valid<= dout_valid_int;
    dout_data <= peek_data;


    -- if peek data is invalid or being read, and buffer is nonempty
    -- read it into peek
    fifo_rden     <= not fifo_empty and (not dout_valid_int or dout_ready) and out_initialized_and;

    -- FIFO_SYNC_MACRO: Synchronous First-In, First-Out (FIFO) RAM Buffer
    --                  Artix-7
    -- Xilinx HDL Language Template, version 2019.2
    
    -- Note -  This Unimacro model assumes the port directions to be "downto". 
    --         Simulation of this model with "to" in the port directions could lead to erroneous results.
    
    -----------------------------------------------------------------
    -- DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width --
    -- ===========|===========|============|=======================--
    --   37-72    |  "36Kb"   |     512    |         9-bit         --
    --   19-36    |  "36Kb"   |    1024    |        10-bit         --
    --   19-36    |  "18Kb"   |     512    |         9-bit         --
    --   10-18    |  "36Kb"   |    2048    |        11-bit         --
    --   10-18    |  "18Kb"   |    1024    |        10-bit         --
    --    5-9     |  "36Kb"   |    4096    |        12-bit         --
    --    5-9     |  "18Kb"   |    2048    |        11-bit         --
    --    1-4     |  "36Kb"   |    8192    |        13-bit         --
    --    1-4     |  "18Kb"   |    4096    |        12-bit         --
    -----------------------------------------------------------------

    FIFO_DUALCLOCK_MACRO_inst : FIFO_DUALCLOCK_MACRO
    generic map (
      DEVICE => "7SERIES",            -- Target Device: "VIRTEX5, "VIRTEX6", "7SERIES" 
      ALMOST_FULL_OFFSET => X"0008",  -- Sets almost full threshold (0x0200 max, need to leave some for clock ratio)
      ALMOST_EMPTY_OFFSET => X"0005", -- Sets the almost empty threshold
      DATA_WIDTH => din_data'length,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => FIFO_SIZE)            -- Target BRAM, "18Kb" or "36Kb" 
    port map (
      ALMOSTEMPTY => fifo_almostempty,   -- 1-bit output almost empty
      ALMOSTFULL  => fifo_almostfull,     -- 1-bit output almost full
      DO          => peek_data,-- Output data, width defined by DATA_WIDTH parameter
      EMPTY   => fifo_empty,-- 1-bit output empty
      FULL    => fifo_FULL,    -- 1-bit output full
      RDCOUNT => fifo_rdcount,           -- Output read count, width determined by FIFO depth
      RDERR   => fifo_RDERR,                 -- 1-bit output read error
      WRCOUNT => fifo_wrcount,           -- Output write count, width determined by FIFO depth
      WRERR   => fifo_WRERR,                 -- 1-bit output write error
      RDCLK => outclk,                   -- 1-bit input clock
      WRCLK => inclk,                   -- 1-bit input clock
      DI => din_data,               -- Input data, width defined by DATA_WIDTH parameter
      RDEN => fifo_rden,             -- 1-bit input read wrrdenle
      RST => RST,                   -- 1-bit input reset
      WREN => fifo_wren              -- 1-bit input write wrrdenle
    );
    -- End of FIFO_SYNC_MACRO_inst instantiation
    
    PROCESS (outclk)
    begin
    if rising_edge(outclk) then
        if rst = '0' then
            -- not valid if being read
            if dout_ready = '1' then
                dout_valid_int <= '0';
            end if;
            
            -- if we read last cycle, data is valid
            if fifo_rden = '1' then
                dout_valid_int <= '1';
            end if;
        end if;
    end if;
    END PROCESS;
            
    PROCESS (inclk)
    begin
    if rising_edge(inclk) then
        if rst = '1' then
            in_resetcount <= 0;
        else
            in_initialized_and <= in_initialized and out_initialized;
            in_resetcount <= in_resetcount + 1;
            if in_resetcount >= 20 then
                in_initialized <= '1';
            end if;
        end if;
    end if;
    END PROCESS;
            
    PROCESS (outclk)
    begin
    if rising_edge(outclk) then
        if rst = '1' then
            out_resetcount <= 0;
        else
            out_initialized_and <= in_initialized and out_initialized;
            out_resetcount <= out_resetcount + 1;
            if out_resetcount >= 1 then
                out_initialized <= '1';
            end if;
        end if;
    end if;
    END PROCESS;
END;