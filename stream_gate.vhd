-- Julian Loiacono
-- stream_gate

Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.zconstants_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Entity stream_gate Is
	Port (
		clk           : In Std_logic;
		rst           : In Std_logic;

        amount_ready  : Out std_logic;
        amount_valid  : In  std_logic;
        amount_data   : In  integer; 
        
		din_ready     : Out Std_logic := '1';
		din_valid     : In Std_logic;
		din_data      : In Std_logic_vector;

		dout_ready    : In Std_logic;
		dout_valid    : Out Std_logic := '0';
		dout_data     : Out Std_logic_vector := (Others => '0')

	);
End stream_gate;

Architecture arch_imp Of stream_gate Is

	Signal amount_ready_int : Std_logic := '0';
	Signal dout_valid_int   : Std_logic := '0';
	Signal din_ready_int    : Std_logic := '1';
	Signal remain : Integer := 0;

Begin
	-- Big Endian  
	amount_ready   <= amount_ready_int;
	dout_data      <= din_data;
	dout_valid     <= dout_valid_int;
	amount_ready_int <= not rst When remain = 0 Else '0';
	dout_valid_int <= din_valid and Not rst When remain /= 0 Else '0';
	
	din_ready <= din_ready_int;
	din_ready_int <= Not rst When remain /= 0 Else '0';

	ser_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			-- every send, derease remain, and shift latched result
			If dout_valid_int = '1' And dout_ready = '1' Then
                remain <= remain - 1;
			End If;

			If amount_valid = '1' Then
				remain <= amount_data;
			End If;
			
		End If;
	End Process;

End arch_imp;