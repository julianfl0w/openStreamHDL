-------------------------------------------------------------------------------
-- File downloaded from http://www.nandland.com
-------------------------------------------------------------------------------
-- Description:
-- A LFSR or Linear Feedback Shift Register is a quick and easy
-- way to generate pseudo-random data inside of an FPGA.  The LFSR can be used
-- for things like counters, test patterns, scrambling of data, and others.
-- This module creates an LFSR whose width gets set by a generic.  The
-- LFSR_Done will pulse once all combinations of the LFSR are complete.  The
-- number of clock cycles that it takes LFSR_Done to pulse is equal to
-- 2^g_Num_Bits-1.  For example, setting g_Num_Bits to 5 means that LFSR_Done
-- will pulse every 2^5-1 = 31 clock cycles.  LFSR_Data will change on each
-- clock cycle that the module is enabled, which can be used if desired.
--
-- Generics:
-- g_Num_Bits - Set to the integer number of bits wide to create your LFSR.
-------------------------------------------------------------------------------

Library ieee;
Use ieee.std_logic_1164.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Entity LFSR Is
	Generic (
		g_Num_Bits : Integer := 5
	);
	Port (
		Clk : In Std_logic;
		Enable : In Std_logic;

		-- Optional Seed Value
		Seed_DV : In Std_logic;
		Seed_Data : In Std_logic_vector(g_Num_Bits - 1 Downto 0);

		LFSR_Data : Out Std_logic_vector(g_Num_Bits - 1 Downto 0);
		LFSR_Done : Out Std_logic
	);
End Entity LFSR;

Architecture RTL Of LFSR Is

	Signal r_LFSR : Std_logic_vector(g_Num_Bits Downto 1) := (Others => '0');
	Signal w_XNOR : Std_logic;

Begin

	-- Purpose: Load up LFSR with Seed if Data Valid (DV) pulse is detected.
	-- Othewise just run LFSR when enabled.
	p_LFSR : Process (Clk) Is
	Begin
		If rising_edge(Clk) Then
			If Seed_DV = '1' Then
				r_LFSR <= Seed_Data;
			Elsif Enable = '1' Then
				r_LFSR <= r_LFSR(r_LFSR'left - 1 Downto 1) & w_XNOR;
			End If;
		End If;
	End Process p_LFSR;

	-- Create Feedback Polynomials.  Based on Application Note:
	-- http://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
	g_LFSR_3 : If g_Num_Bits = 3 Generate
		w_XNOR <= r_LFSR(3) Xnor r_LFSR(2);
	End Generate g_LFSR_3;

	g_LFSR_4 : If g_Num_Bits = 4 Generate
		w_XNOR <= r_LFSR(4) Xnor r_LFSR(3);
	End Generate g_LFSR_4;

	g_LFSR_5 : If g_Num_Bits = 5 Generate
		w_XNOR <= r_LFSR(5) Xnor r_LFSR(3);
	End Generate g_LFSR_5;

	g_LFSR_6 : If g_Num_Bits = 6 Generate
		w_XNOR <= r_LFSR(6) Xnor r_LFSR(5);
	End Generate g_LFSR_6;

	g_LFSR_7 : If g_Num_Bits = 7 Generate
		w_XNOR <= r_LFSR(7) Xnor r_LFSR(6);
	End Generate g_LFSR_7;

	g_LFSR_8 : If g_Num_Bits = 8 Generate
		w_XNOR <= r_LFSR(8) Xnor r_LFSR(6) Xnor r_LFSR(5) Xnor r_LFSR(4);
	End Generate g_LFSR_8;

	g_LFSR_9 : If g_Num_Bits = 9 Generate
		w_XNOR <= r_LFSR(9) Xnor r_LFSR(5);
	End Generate g_LFSR_9;

	g_LFSR_10 : If g_Num_Bits = 10 Generate
		w_XNOR <= r_LFSR(10) Xnor r_LFSR(7);
	End Generate g_LFSR_10;

	g_LFSR_11 : If g_Num_Bits = 11 Generate
		w_XNOR <= r_LFSR(11) Xnor r_LFSR(9);
	End Generate g_LFSR_11;

	g_LFSR_12 : If g_Num_Bits = 12 Generate
		w_XNOR <= r_LFSR(12) Xnor r_LFSR(6) Xnor r_LFSR(4) Xnor r_LFSR(1);
	End Generate g_LFSR_12;

	g_LFSR_13 : If g_Num_Bits = 13 Generate
		w_XNOR <= r_LFSR(13) Xnor r_LFSR(4) Xnor r_LFSR(3) Xnor r_LFSR(1);
	End Generate g_LFSR_13;

	g_LFSR_14 : If g_Num_Bits = 14 Generate
		w_XNOR <= r_LFSR(14) Xnor r_LFSR(5) Xnor r_LFSR(3) Xnor r_LFSR(1);
	End Generate g_LFSR_14;

	g_LFSR_15 : If g_Num_Bits = 15 Generate
		w_XNOR <= r_LFSR(15) Xnor r_LFSR(14);
	End Generate g_LFSR_15;

	g_LFSR_16 : If g_Num_Bits = 16 Generate
		w_XNOR <= r_LFSR(16) Xnor r_LFSR(15) Xnor r_LFSR(13) Xnor r_LFSR(4);
	End Generate g_LFSR_16;

	g_LFSR_17 : If g_Num_Bits = 17 Generate
		w_XNOR <= r_LFSR(17) Xnor r_LFSR(14);
	End Generate g_LFSR_17;

	g_LFSR_18 : If g_Num_Bits = 18 Generate
		w_XNOR <= r_LFSR(18) Xnor r_LFSR(11);
	End Generate g_LFSR_18;

	g_LFSR_19 : If g_Num_Bits = 19 Generate
		w_XNOR <= r_LFSR(19) Xnor r_LFSR(6) Xnor r_LFSR(2) Xnor r_LFSR(1);
	End Generate g_LFSR_19;

	g_LFSR_20 : If g_Num_Bits = 20 Generate
		w_XNOR <= r_LFSR(20) Xnor r_LFSR(17);
	End Generate g_LFSR_20;

	g_LFSR_21 : If g_Num_Bits = 21 Generate
		w_XNOR <= r_LFSR(21) Xnor r_LFSR(19);
	End Generate g_LFSR_21;

	g_LFSR_22 : If g_Num_Bits = 22 Generate
		w_XNOR <= r_LFSR(22) Xnor r_LFSR(21);
	End Generate g_LFSR_22;

	g_LFSR_23 : If g_Num_Bits = 23 Generate
		w_XNOR <= r_LFSR(23) Xnor r_LFSR(18);
	End Generate g_LFSR_23;

	g_LFSR_24 : If g_Num_Bits = 24 Generate
		w_XNOR <= r_LFSR(24) Xnor r_LFSR(23) Xnor r_LFSR(22) Xnor r_LFSR(17);
	End Generate g_LFSR_24;

	g_LFSR_25 : If g_Num_Bits = 25 Generate
		w_XNOR <= r_LFSR(25) Xnor r_LFSR(22);
	End Generate g_LFSR_25;

	g_LFSR_26 : If g_Num_Bits = 26 Generate
		w_XNOR <= r_LFSR(26) Xnor r_LFSR(6) Xnor r_LFSR(2) Xnor r_LFSR(1);
	End Generate g_LFSR_26;

	g_LFSR_27 : If g_Num_Bits = 27 Generate
		w_XNOR <= r_LFSR(27) Xnor r_LFSR(5) Xnor r_LFSR(2) Xnor r_LFSR(1);
	End Generate g_LFSR_27;

	g_LFSR_28 : If g_Num_Bits = 28 Generate
		w_XNOR <= r_LFSR(28) Xnor r_LFSR(25);
	End Generate g_LFSR_28;

	g_LFSR_29 : If g_Num_Bits = 29 Generate
		w_XNOR <= r_LFSR(29) Xnor r_LFSR(27);
	End Generate g_LFSR_29;

	g_LFSR_30 : If g_Num_Bits = 30 Generate
		w_XNOR <= r_LFSR(30) Xnor r_LFSR(6) Xnor r_LFSR(4) Xnor r_LFSR(1);
	End Generate g_LFSR_30;

	g_LFSR_31 : If g_Num_Bits = 31 Generate
		w_XNOR <= r_LFSR(31) Xnor r_LFSR(28);
	End Generate g_LFSR_31;

	g_LFSR_32 : If g_Num_Bits = 32 Generate
		w_XNOR <= r_LFSR(32) Xnor r_LFSR(22) Xnor r_LFSR(2) Xnor r_LFSR(1);
	End Generate g_LFSR_32;
	LFSR_Data <= Std_logic_vector(r_LFSR(r_LFSR'high Downto r_LFSR'length - LFSR_Data'length + 1));
	LFSR_Done <= '1' When r_LFSR(r_LFSR'left Downto 1) = Seed_Data Else '0';

End Architecture RTL;