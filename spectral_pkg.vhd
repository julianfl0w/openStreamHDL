library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_misc.ALL;
use ieee.math_real.all;
Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

package spectral_pkg is    

    function log2( i : natural) return integer;
    
    constant cmd_readirqueue        : integer := 64;
    constant cmd_readaudio          : integer := 65;
    constant cmd_readid             : integer := 66;
    
    -- voice params
    constant cmd_sounding           : integer := 69;
    constant cmd_fm_algo            : integer := 70;
    constant cmd_am_algo            : integer := 71;
    constant cmd_fbgain             : integer := 73;
    constant cmd_fbsrc              : integer := 74;
    constant cmd_channelgain        : integer := 75;
    
    -- operator params
    constant cmd_env               : integer := 76;
    constant cmd_env_rate          : integer := 77;
    constant cmd_increment         : integer := 79;
    constant cmd_increment_rate    : integer := 80;
    
    -- global params
    constant cmd_flushspi           : integer := 120;
    constant cmd_passthrough        : integer := 121;
    constant cmd_shift              : integer := 122;
    constant cmd_softreset          : integer := 127;
         
    constant PROCESS_BW : integer := 18;
    constant OPCOUNT : integer := 8;
    constant OPCOUNTLOG2 : integer := 3;
    constant PROCESS_BWA : integer := 18;
    constant PHASE_PRECISIONA : integer := 32;
    Type OPERATOR_PROCESS Is Array (0 To OPCOUNT - 1) Of sfixed(1 Downto -PROCESS_BWA + 2);
    Type OPERATOR_ARRAY Is Array    (0 To OPCOUNT - 1) Of Std_logic_vector(PHASE_PRECISIONA - 1 Downto 0);
    Type OPERATOR_ARRAY_18 Is Array (0 To OPCOUNT - 1) Of Std_logic_vector(PROCESS_BWA - 1 Downto 0);
    
    type bezier2dWriteType is array ( 2 downto 0 ) of std_logic_vector(2 downto 0);

    constant MEASUREMAXLOG2 : integer := 7;
    constant BEATMAXLOG2 : integer := 11;
    
    -- define some constants
    constant std_flowwidth   : INTEGER := 25;    -- typical internal signals are 25-bit
    constant ram_width18     : INTEGER := 18;    -- modulator signals are 18 bit
    constant gpif_width      : INTEGER := 16;
    
    constant VOICECOUNT       : INTEGER := 128;
    
    constant E0_FREQ_HZ : real := 20.60;
    constant sqrt_1200: real := 1.00057778951;

    
    constant FS_HZ : integer := 48000;
    constant FS_HZ_REAL : real := 48000.0;
    constant BYTES_PER_SAMPLE_XFER : natural := 192;
        
    -- sdram constants
    constant sdramWidth         : INTEGER := 16;
    constant sdram_rowcount     : natural := 13;
    constant sdram_colcount     : natural := 10;
    constant cycles_per_refresh : natural := 1560;
    constant BANKCOUNT          : natural := 4;
    
    constant wfcount   : INTEGER := 16;
    constant wfcountlog2: INTEGER := 4;
    
    constant DRAWSCOUNT  : integer := 64;
    constant DRAWSLOG2   : integer := 6;
       
    constant ftypescount: INTEGER := 4;
    constant ftypeslog2 : INTEGER := 2;
    constant FTYPE_NONE : unsigned(1 downto 0) := "00";
    constant FTYPE_LP   : unsigned(1 downto 0) := "01";
    constant FTYPE_HP   : unsigned(1 downto 0) := "10";
    constant FTYPE_BP   : unsigned(1 downto 0) := "11";   
    
    constant FTYPE_NONE_I : INTEGER := 0;
    constant FTYPE_LP_I   : INTEGER := 1;
    constant FTYPE_HP_I   : INTEGER := 2;
    constant FTYPE_BP_I   : INTEGER := 3;
       
    constant DIRECTLY   : unsigned(6 downto 0) := "0000000";
    constant BY_TAG     : unsigned(6 downto 0) := "0000001";
    constant ALL_VOICES : unsigned(6 downto 0) := "0000011";
    constant DUPLICATES : unsigned(6 downto 0) := "0000100";
    
    constant OPTIONS_VALUE : unsigned(3 downto 0) := "0000";
    constant OPTIONS_DRAW  : unsigned(3 downto 0) := "0001";
    
end spectral_pkg;

package body spectral_pkg is
    
   -- log2 function
   function log2( i : natural) return integer is
       variable temp    : integer := i;
       variable ret_val : integer := 0; 
     begin                    
       while temp > 1 loop
         ret_val := ret_val + 1;
         temp    := temp / 2;     
       end loop;
         
       return ret_val;
     end function;
           
end package body;