Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity chaser_lpf Is
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		srun: in Std_logic_vector;
        
        Z00_target  : In Std_logic_vector;
		Z00_current : In Std_logic_vector; 
        Z00_addr    : In Std_logic_vector;
        Z01_porta   : In sfixed;
        Z02_finished : out Std_logic;
		Z03_current  : Out sfixed
	);
End chaser_lpf;

Architecture arch_imp Of chaser_lpf Is

	Signal Z01_current  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z02_current  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z02_mod  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z03_current_int  : sfixed(1 downto -Z00_target'length+2)  := (Others => '0');
	Signal Z01_difference: sfixed(1 downto -Z00_target'length+2);
	Signal Z01_ADDR     : Std_logic_vector(Z00_addr'length   - 1 Downto 0);
	Signal Z02_ADDR     : Std_logic_vector(Z00_addr'length   - 1 Downto 0);
	Signal Z03_ADDR     : Std_logic_vector(Z00_addr'length   - 1 Downto 0);

		
Begin
    Z03_current       <= Z03_current_int;
	-- sum process\\
	sumproc2 :
	Process (clk)
	Begin
		If rising_edge(clk) Then

			If rst = '0' Then
                
                If srun(Z00) = '1' Then
                    Z01_ADDR <= Z00_ADDR;
                    Z01_current           <= sfixed(Z00_current);
                    Z01_difference        <= sfixed(resize(signed(Z00_target) - signed(Z00_current), Z01_difference'length));
                End If;

                Z02_finished <= '0';
                If srun(Z01) = '1' Then
                    Z02_current <= Z01_current;
                    Z02_ADDR <= Z01_ADDR;
                    Z02_mod  <= resize(Z01_difference * Z01_porta, Z02_mod, fixed_wrap, fixed_truncate);
                    if Z01_difference < 0.01 then
                        Z02_finished <= '1';
                    end if;
                End If;
                
                If srun(Z02) = '1' Then
                    Z03_ADDR       <= Z02_ADDR;
                    Z03_current_int<= resize(Z02_current + Z02_mod, Z03_current_int, fixed_wrap, fixed_truncate);

                End If;
                
            End If;
		End If;
	End Process;

End arch_imp;