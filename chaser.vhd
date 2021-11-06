Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity chaser Is
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		Z01_exp : In Std_logic;
		Z02_en  : In Std_logic;
		srun: in Std_logic_vector;
        
        Z00_target  : In Std_logic_vector;
		Z00_current : In Std_logic_vector; 
        Z00_addr    : In Std_logic_vector;
        Z01_porta   : In sfixed;
        Z02_moving : out Std_logic;
		Z03_current  : Out sfixed
	);
End chaser;

Architecture arch_imp Of chaser Is

	Signal Z01_current  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z02_current  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z02_mod  :  sfixed(1 downto -Z01_porta'length+2);
	Signal Z02_modexp  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z03_current_int  : sfixed(1 downto -Z00_target'length+2)  := (Others => '0');
	Signal Z01_difference: sfixed(1 downto -Z00_target'length+2);
	Signal Z01_ADDR     : Std_logic_vector(Z00_addr'length   - 1 Downto 0);
	Signal Z01_target   : sfixed(1 downto -Z00_target'length+2);
	Signal Z02_ADDR     : Std_logic_vector(Z00_addr'length   - 1 Downto 0);
	Signal Z03_ADDR     : Std_logic_vector(Z00_addr'length   - 1 Downto 0);
	Signal Z02_exp : Std_logic;

		
Begin
    Z03_current       <= Z03_current_int;
	-- sum process\\
	sumproc2 :
	Process (clk)
	Begin
		If rising_edge(clk) Then

			If rst = '0' Then
                
                If srun(Z00) = '1' Then
                    Z01_target<= sfixed(Z00_target);
                    Z01_ADDR       <= Z00_ADDR;
                    Z01_current    <= sfixed(Z00_current);
                    Z01_difference <= sfixed(resize(signed(Z00_target) - signed(Z00_current), Z01_difference'length));
                End If;

                If srun(Z01) = '1' Then
                    Z02_ADDR <= Z01_ADDR;
                    Z02_current <= Z01_current;
                    Z02_exp   <= Z01_exp;
                    Z02_modexp  <= resize(Z01_difference * Z01_porta, Z02_modexp, fixed_wrap, fixed_truncate);
                    -- chase the prescale
                    if Z01_difference > Z01_porta Then
                        Z02_mod <= Z01_porta;
                    Elsif Z01_difference < -Z01_porta Then
                        Z02_mod <= resize(-Z01_porta, Z02_mod, fixed_wrap, fixed_truncate);
                    Else
                   	    Z02_mod <= resize(Z01_target + Z01_difference, Z02_mod, fixed_wrap, fixed_truncate);
                    End If;
                    if Z01_difference = 0 then
                        Z02_moving <= '0';
                    else
                        Z02_moving <= '1';
                    end if;
                End If;
                
                If srun(Z02) = '1' Then
                    Z03_ADDR       <= Z02_ADDR;         
                    if Z02_en = '1' then      
                        if Z02_exp = '1' then
                           Z03_current_int<= resize(Z02_current + Z02_modexp, Z03_current_int, fixed_wrap, fixed_truncate);
                        else
                    	   Z03_current_int<= resize(Z02_current + Z02_mod, Z03_current_int, fixed_wrap, fixed_truncate);
                    	end if;
                    else
                    	Z03_current_int<= Z02_current;
                    end if;
                End If;
                
            End If;
		End If;
	End Process;

End arch_imp;
