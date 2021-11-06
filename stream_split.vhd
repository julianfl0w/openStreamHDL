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

Entity stream_split Is
    Port (
        clk : In Std_logic;
        rst : In Std_logic;

        din_ready : Out Std_logic := '0';
        din_valid : In Std_logic;
        din_data  : In Std_logic_vector;
        
        dout0_ready : In Std_logic;
        dout0_valid : Out Std_logic := '0';
        dout0_data  : Out Std_logic_vector := (others=>'0');
        
        dout1_ready : In Std_logic;
        dout1_valid : Out Std_logic := '0';
        dout1_data  : Out Std_logic_vector := (others=>'0')

    );
End stream_split;

Architecture arch_imp Of stream_split Is

Signal din_ready_int : Std_logic := '0';
Signal dout0_valid_int : Std_logic := '0';
Signal dout1_valid_int : Std_logic := '0';

Begin
    din_ready   <= din_ready_int;
    dout0_valid <= dout0_valid_int;
    dout1_valid <= dout1_valid_int;

    -- ready when neither output is valid
    din_ready_int <= not dout1_valid_int and not dout0_valid_int;
    
    ser_process:
    Process (clk)
    Begin
        If rising_edge(clk) Then    
            -- if sending, invalidate
            if dout0_valid_int = '1' and dout0_ready = '1' then
                dout0_valid_int <= '0';
            end if;
            if dout1_valid_int = '1' and dout1_ready = '1' then
                dout1_valid_int <= '0';
            end if;
            
            -- if receiving, validate
            if din_ready_int = '1' and din_valid = '1' then
                dout0_valid_int <= '1';
                dout1_valid_int <= '1';
                dout0_data <= din_data;
                dout1_data <= din_data;
            end if;
        End If;
    End Process;
End arch_imp;