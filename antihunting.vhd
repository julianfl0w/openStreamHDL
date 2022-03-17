----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;
Use ieee.math_real.All;

Library work;
Use work.spectral_pkg.All;
Use work.zconstants_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;
Library UNISIM;
Use UNISIM.vcomponents.All;

Library UNIMACRO;
Use UNIMACRO.vcomponents.All;
Library work;
Use work.spectral_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity antihunting Is
    Port (
        run   : In Std_logic_vector;
        clk   : in  Std_logic;
        
        Z00_VoiceIndex       : in Std_logic_vector;
        Z02_din_DATA   : in sfixed(1 downto -PROCESS_BW+2) := (Others => '0');
        
        srun   : In Std_logic_vector;
        S00_rdaddr     : in Std_logic_vector;
        S02_dout_DATA  : out sfixed(1 downto -PROCESS_BW+2) := (Others => '0')
    );

End antihunting;

Architecture arch_imp Of antihunting Is
signal Z01_din_DATA_past   : Std_logic_vector(Z02_din_DATA'length-1 downto 0);
signal Z02_din_DATA_past   : sfixed(1 downto -PROCESS_BW+2) := (Others => '0');
signal Z01_VoiceIndex       : Std_logic_vector(Z00_VoiceIndex'high downto 0);
signal Z02_VoiceIndex       : Std_logic_vector(Z00_VoiceIndex'high downto 0);
signal Z03_VoiceIndex       : Std_logic_vector(Z00_VoiceIndex'high downto 0);
signal Z03_dout_DATA  : sfixed(1 downto -PROCESS_BW+2) := (Others => '0');
signal Z03_dout_DATA_slv  : Std_logic_vector(PROCESS_BW-1 downto 0) := (Others => '0');
signal S01_dout_DATA  : Std_logic_vector(Z02_din_DATA'length-1 downto 0);
signal Z02_din_DATA_slv   : Std_logic_vector(PROCESS_BW-1 downto 0) := (Others => '0');

Begin
    Z03_dout_DATA_slv <= std_logic_vector(Z03_dout_DATA);
    Z02_din_DATA_slv  <= std_logic_vector(Z02_din_DATA);
    -- history
    oned : Entity work.simple_dual_one_clock
        Port Map(
            clk    => clk,
            wea    => '1',
            wraddr => Z02_VoiceIndex,
            wrdata => Z02_din_DATA_slv,
            wren   => run(Z02),
            rden   => run(Z00),
            rdaddr => Z00_VoiceIndex,
            rddata => Z01_din_DATA_past
			);
				
    -- wraparound
    wraparound : Entity work.simple_dual_one_clock
        Port Map(
            clk    => clk,
            wea    => '1',
            wraddr => Z03_VoiceIndex,
            wrdata => Z03_dout_DATA_slv,
            wren   => run(Z03),
            rden   => srun(Z00),
            rdaddr => S00_rdaddr,
            rddata => S01_dout_DATA
			);
			
			
    sineproc :
    Process (clk)
    Begin
        If rising_edge(clk) Then
                        
            If run(Z00) = '1' Then
                Z01_VoiceIndex <= Z00_VoiceIndex;
            end if;
            
            If run(Z01) = '1' Then
                Z02_VoiceIndex <= Z01_VoiceIndex;
                Z02_din_DATA_past <= sfixed(Z01_din_DATA_past);
            end if;
            
            If run(Z02) = '1' Then
                Z03_VoiceIndex <= Z02_VoiceIndex;
                Z03_dout_DATA <= resize((Z02_din_DATA + Z02_din_DATA_past)/2, Z02_din_DATA_past, fixed_saturate, fixed_truncate);
            end if;
            
            If srun(Z01) = '1' Then
                S02_dout_DATA <= sfixed(S01_dout_DATA);
            end if;
         end if;       
    End Process;

End arch_imp;