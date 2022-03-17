-- Turn parameters into a sine-bank amplitude array!

-- the basic parameters of a note:
-- envelope
-- Harmonic width
-- F0 filter     (bidirectional)
-- Global filter (unidirectional)
-- F0 
-- Lowest harmonic
-- Highest harmonic

Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Entity deserializer_copy Is
    Port (
        clk : In Std_logic;
        rst : In Std_logic;

        din_ready : Out Std_logic := '1';
        din_valid : In Std_logic;
        din_data  : In Std_logic_vector;
        
        dout_ready : In Std_logic;
        dout_valid : Out Std_logic := '0';
        dout_data  : Out Std_logic_vector := (others=>'0')

    );
End deserializer_copy;
 
Architecture arch_imp Of deserializer_copy Is
    Constant ratio : integer := dout_data'length / din_data'length;
    Signal din_ready_int  : Std_logic := '1';
    Signal dout_valid_int : Std_logic := '0';
    Signal data_latched : std_logic_vector(dout_data'high downto 0);
    Signal currInBit : integer := ratio-1;
    
Begin
    -- Big Endian
    dout_data <= data_latched; 
    dout_valid<= dout_valid_int;
    din_ready <= din_ready_int;
    din_ready_int <= '1' when dout_valid_int = '0' or dout_ready = '1' else '0';
    
    ser_process:
    Process (clk)
    Begin
        If rising_edge(clk) Then    
            -- every send, invalidate output
            if dout_valid_int = '1' and dout_ready = '1' then          
                dout_valid_int <= '0';
            end if;
            
            -- every receive, latch the bit
            if din_valid = '1' and din_ready_int = '1' then
                data_latched   <= data_latched(data_latched'high -1 downto 0) & din_data; -- little endian
                if currInBit = 0 then
                    currInBit <= ratio-1;
                    dout_valid_int <= '1';
                else
                    currInBit <= currInBit - 1;  
                end if;
            end if;
            
            
        End If;
    End Process;

End arch_imp;