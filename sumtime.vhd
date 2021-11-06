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

Entity sumtime Is
    Generic(
        ratio : integer := 1024
    );
    
    Port (
        clk : In Std_logic;
        rst : In Std_logic;

        din_ready : Out Std_logic := '1';
        din_valid : In Std_logic;
        din_data  : In sfixed;
        
        dout_ready : In Std_logic;
        dout_valid : Out Std_logic := '0';
        dout_data  : Out sfixed := (others=>'0')

    );
End sumtime;

Architecture arch_imp Of sumtime Is

    constant ratiolog2 : integer := log2(ratio);
    Signal din_ready_int  : Std_logic := '1';
    Signal dout_valid_int : Std_logic := '0';
    Signal data_latched : sfixed(dout_data'high downto dout_data'low) := (others=>'0');
    Signal currAddend : integer := ratio-1;
    
Begin
    dout_data <= data_latched; 
    dout_valid<= dout_valid_int;
    din_ready <= din_ready_int;
    din_ready_int <= '1' when dout_valid_int = '0' or dout_ready = '1' else '0';
    
    ser_process:
    Process (clk)
    Begin
        If rising_edge(clk) Then    
            -- every send, invalidate and reset output
            if dout_valid_int = '1' and dout_ready = '1' then          
                dout_valid_int <= '0';
                data_latched <= (others=>'0');
            end if;
            
            -- every receive, add the bit
            if din_valid = '1' and din_ready_int = '1' then
                -- if sending, reset
                if dout_valid_int = '1' and dout_ready = '1' then   
                    data_latched <= resize(din_data, data_latched, fixed_wrap, fixed_truncate); 
                else  
                    data_latched   <= resize(data_latched + din_data, data_latched, fixed_wrap, fixed_truncate); 
                end if;
                if currAddend = 0 then
                    currAddend <= ratio-1;
                    dout_valid_int <= '1';
                else
                    currAddend <= currAddend - 1;  
                end if;
            end if;
            
        End If;
    End Process;

End arch_imp;