----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;
Use ieee.math_real.All;

Library work;
Use work.zconstants_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;
Library UNISIM;
Use UNISIM.vcomponents.All;

Library UNIMACRO;
Use UNIMACRO.vcomponents.All;
Library work;
Use work.zconstants_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity mm_volume_stream Is 
    Generic(
        DOUT_DATA_LEN : integer := 18
        );
    Port (
        rst                   : In Std_logic;
        clk                   : in Std_logic;
        
        gain_wr               : in  Std_logic := '1';
        mm_voiceno            : in Std_logic_vector;
        mm_wrdata_processbw   : In Std_logic_vector;
        Z00_NoteIndex         : In Std_logic_vector;
        Z00_ready             : OUT Std_logic;
        Z00_valid             : In  Std_logic;
        
        Z00_din_data          : in  sfixed;
        
        Z03_dout_ready        : In Std_logic;
        Z03_dout_valid        : Out Std_logic;
        Z03_dout_data         : out sfixed := (Others => '0')
    );

End mm_volume_stream;

Architecture arch_imp Of mm_volume_stream Is

   signal run : std_logic_vector(Z03 downto 0);
   
   signal Z01_gain : std_logic_vector(mm_wrdata_processbw'high downto 0);
   signal Z02_gain : sfixed(1 downto -mm_wrdata_processbw'length + 2);
   
   signal Z01_din_data   : sfixed(Z00_din_data'range);
   signal Z02_din_data   : sfixed(Z00_din_data'range);
        

Begin

    -- I/O Connections assignments
    flow_i : Entity work.flow
        Port Map(
            clk => clk,
            rst => rst,

            in_ready => Z00_ready,
            in_valid => Z00_valid,
            out_ready => Z03_dout_ready,
            out_valid => Z03_dout_valid,

            run => run
        );


    -- master gain
    gain : Entity work.simple_dual_one_clock
        Port Map(
            clk    => clk,
            wea    => '1',
            wraddr => mm_voiceno,
            wrdata => mm_wrdata_processbw,
            wren   => gain_wr,
            rden   => run(Z00),
            rdaddr => Z00_NoteIndex,
            rddata => Z01_gain
			);
				
        
    sineproc :
    Process (clk)
    Begin
        If rising_edge(clk) Then
                        
            If run(Z00) = '1' Then
                Z01_din_data <= Z00_din_data;
            end if;
            
            If run(Z01) = '1' Then
                Z02_din_data <= Z01_din_data;
                Z02_gain <= sfixed(Z01_gain);
            end if;
            
            If run(Z02) = '1' Then
                Z03_dout_data <= resize(Z02_din_data * Z02_gain, 1, -DOUT_DATA_LEN+2, fixed_saturate, fixed_truncate);
            end if;
            
        End If;
    End Process;

End arch_imp;