Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;

Library work;
Use work.memory_word_type.All;
Use work.fixed_pkg.All;

-- entity declaration for your testbench.Dont declare any ports here
Entity sine_lookup_tb Is
End sine_lookup_tb;

Architecture behavior Of sine_lookup_tb Is
	-- Component Declaration for the Unit Under Test (UUT)

	Component sine_lookup
		--just copy and paste the input and output ports of your module as such. 
		Port (
			clk100 : In Std_logic;
			Z00_PHASE_in : In signed(std_flowwidth - 1 Downto 0);
			Z06_SINE_out : Out sfixed(1 Downto -std_flowwidth + 2) := (Others => '0');
			OUTSAMPLEF_ALMOSTFULL : In Std_logic
		);

	End Component;
	Constant clk100_period : Time := 10 ns;
	Signal clk100 : Std_logic := '0';
	--signal Z00_PHASE_in : sfixed(RAM_WIDTH18 - 1 downto 0) := (others=>'0');
	Signal Z00_PHASE_in : signed(std_flowwidth - 1 Downto 0) := (Others => '0');
	Signal Z06_SINE_out : sfixed(1 Downto -std_flowwidth + 2) := (Others => '0');
	Signal OUTSAMPLEF_ALMOSTFULL : Std_logic := '0';

Begin
	-- Instantiate the Unit Under Test (UUT)
	i_sine_lookup : sine_lookup Port Map(
		clk100 => clk100,
		Z00_PHASE_in => Z00_PHASE_in,
		Z06_SINE_out => Z06_SINE_out,
		OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
	);

	-- Clock process definitions( clock with 50% duty cycle is generated here.
	clk100_process : Process
	Begin
		clk100 <= '0';
		Wait For clk100_period/2; --for 0.5 ns signal is '0'.
		clk100 <= '1';
		Wait For clk100_period/2; --for next 0.5 ns signal is '1'.
	End Process;

	lfotest : Process (clk100)
	Begin
		If rising_edge(clk100) Then
			--Z00_PHASE_in <= Z00_PHASE_in + (2**10);
			Z00_PHASE_in <= Z00_PHASE_in + 1;
		End If;
	End Process;

End;