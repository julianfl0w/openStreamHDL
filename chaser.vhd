Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.zconstants_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity chaser Is
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		Z01_is_exponential : In Std_logic;
		Z02_en  : In Std_logic;
		srun: in Std_logic_vector;
        
        Z00_target  : In Std_logic_vector;
		Z00_current : In Std_logic_vector; 
        Z00_voiceaddr    : In Std_logic_vector;
        Z01_rate    : In sfixed;
        Z03_moving  : out Std_logic;
		Z03_current : Out sfixed
	);
End chaser;

Architecture arch_imp Of chaser Is

	Signal Z01_current  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z02_current  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z02_linear_mod  :  sfixed(1 downto -Z01_rate'length+2);
	Signal Z02_scaled_difference  :  sfixed(1 downto -Z00_target'length+2);
	Signal Z03_current_int  : sfixed(1 downto -Z00_target'length+2)  := (Others => '0');
	Signal Z01_difference: sfixed(1 downto -Z00_target'length+2);
	Signal Z02_difference: sfixed(1 downto -Z00_target'length+2);
	Signal Z01_voiceaddr     : Std_logic_vector(Z00_voiceaddr'length   - 1 Downto 0);
	Signal Z01_target   : sfixed(1 downto -Z00_target'length+2);
	Signal Z02_target   : sfixed(1 downto -Z00_target'length+2);
	Signal Z02_voiceaddr     : Std_logic_vector(Z00_voiceaddr'length   - 1 Downto 0);
	Signal Z03_voiceaddr     : Std_logic_vector(Z00_voiceaddr'length   - 1 Downto 0);
	Signal Z02_is_exponential : Std_logic;

		
Begin
    Z03_current       <= Z03_current_int;
	-- sum process\\
	sumproc2 :
	Process (clk)
	Begin
		If rising_edge(clk) Then

			If rst = '0' Then
                
                If srun(Z00) = '1' Then
                    Z01_target     <= sfixed(Z00_target);
                    Z01_voiceaddr  <= Z00_voiceaddr;
                    Z01_current    <= sfixed(Z00_current);
                    Z01_difference <= sfixed(resize(signed(Z00_target) - signed(Z00_current), Z01_difference'length));
                End If;

                If srun(Z01) = '1' Then
                    Z02_voiceaddr <= Z01_voiceaddr;
                    Z02_current   <= Z01_current;
                    Z02_is_exponential   <= Z01_is_exponential;
                    Z02_scaled_difference  <= resize(Z01_difference * Z01_rate, Z02_scaled_difference, fixed_wrap, fixed_truncate);
                    
                    -- Linear Mode:
                    -- chase the prescale
                    if Z01_difference > Z01_rate Then
                        Z02_linear_mod <= Z01_rate;
                    Elsif Z01_difference < -Z01_rate Then
                        Z02_linear_mod <= resize(-Z01_rate, Z02_linear_mod, fixed_wrap, fixed_truncate);
                    Else
                   	    Z02_linear_mod <= resize(Z01_difference, Z02_linear_mod, fixed_wrap, fixed_truncate);
                    End If;
                    
                    Z02_target <= Z01_target;
                    Z02_difference <= Z01_difference;
                End If;
                
                If srun(Z02) = '1' Then
                    Z03_voiceaddr       <= Z02_voiceaddr;    
                    
                    -- Enable on certain clock cycles, good for LFOs     
                    if Z02_en = '1' then      
                        -- Linear or Exponential chase
                        -- if exponential
                        if Z02_is_exponential = '1' then
                           if abs(Z02_scaled_difference) < 0.0001 then
                                Z03_moving <= '0';
                                Z03_current_int<= resize(Z02_target, Z03_current_int, fixed_wrap, fixed_truncate);
                           else
                                Z03_moving <= '1';
                                Z03_current_int<= resize(Z02_current + Z02_scaled_difference, Z03_current_int, fixed_wrap, fixed_truncate);
                           end if;
                           
                        -- if linear
                        else
                    	    Z03_current_int<= resize(Z02_current + Z02_linear_mod, Z03_current_int, fixed_wrap, fixed_truncate);
                    	   
                            -- 2 of the same indicates stop state
                            if abs(Z02_difference) = 0  then
                                Z03_moving <= '0';
                            else
                                Z03_moving <= '1';
                            end if;
                    	end if;
                    	
                    else
                    	Z03_current_int<= Z02_current;
                    end if;
                End If;
                
            End If;
		End If;
	End Process;

End arch_imp;
