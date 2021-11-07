----------------------------------------------------------------------------------
-- Engineer: Mike Field  
-- 
-- Module Name: i2s_master - Behavioral
--
-- Description: Convert the 16-bit samples to an I2S bitstream, synced to the 
--              supplied mclk, bclk and lrclk. The value of 'sample_left' and 
--              'sample_right' on the first '0' cycle of 'lrclk' are sent.  
----------------------------------------------------------------------------------
-- Julian Loiacono

Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;

Library UNISIM;
Use UNISIM.VComponents.All;
Library UNIMACRO;
Use UNIMACRO.vcomponents.All;

Library work;
Use work.zconstants_pkg.All;

Entity i2s_master Is
	Generic (
		BIT_DEPTH : Integer := 16;
		CHANNEL_COUNT : Integer := 2;
		INPUT_FREQ : Integer := 100e6;
		SAMPLE_RATE : Integer := 96e3;
		MCLK_PRECISION : Integer := 25;
		mclk_lr_ratio : Integer := 384
	);
	Port (
		i2s_mclk : In Std_logic;
		rst : In Std_logic;

		TX_VALID : In Std_logic;
		TX_READY : Out Std_logic;
		TX_DATA : In Std_logic_vector(BIT_DEPTH * CHANNEL_COUNT - 1 Downto 0);

		RX_VALID : Out Std_logic;
		RX_READY : In Std_logic;
		RX_DATA : Out Std_logic_vector(BIT_DEPTH * CHANNEL_COUNT - 1 Downto 0) := (Others => '0');

		i2s_bclk : Out Std_logic;
		i2s_lrclk : Out Std_logic := '1';
		i2s_dacsd : Out Std_logic := '0';
		i2s_adcsd : In Std_logic;

		i2s_begin : Out Std_logic := '0'
	);
End i2s_master;

Architecture Behavioral Of i2s_master Is

	Signal lrclk_last : Std_logic := '0';
	Signal curr_bit : Integer := 0;
	Signal TX_DATA_latched : Std_logic_vector(BIT_DEPTH * CHANNEL_COUNT - 1 Downto 0);

	Attribute mark_debug : String;
	-- mclk is 192x the sample rate
	-- /2 for half-period
	Attribute keep : String;
	Constant mclk_bclk_ratio : Integer := mclk_lr_ratio / (CHANNEL_COUNT * BIT_DEPTH);

	-- constant mclk_increment   : unsigned(MCLK_PRECISION-1 downto 0) := to_unsigned(2**MCLK_PRECISION * (mclk_lr_ratio*2) *SAMPLE_RATE/INPUT_FREQ, MCLK_PRECISION);
	-- Synthesis hates the above
	-- constant mclk_increment   : unsigned(MCLK_PRECISION-1 downto 0) := resize(X"0bf7b5b", MCLK_PRECISION);

	Signal bclk_counter : Integer := 0;
	Signal i2s_bclk_int : Std_logic := '0';
	Signal TX_READY_int : Std_logic;

	Attribute mark_debug Of i2s_bclk_int : Signal Is "true";
	Attribute mark_debug Of TX_VALID : Signal Is "true";
	Attribute mark_debug Of TX_DATA_latched : Signal Is "true";

Begin
	i2s_bclk <= i2s_bclk_int;
	TX_READY <= TX_READY_int;

	dac_proc : Process (i2s_mclk)
	Begin
		If rising_edge(i2s_mclk) Then
			If rst = '0' Then
				If TX_READY_int = '1' And TX_VALID = '1' Then
					TX_READY_int <= '0';
					TX_DATA_latched <= TX_DATA;
				End If;

				TX_READY_int <= '0';
				RX_VALID <= '0';
				i2s_begin <= '0';

				bclk_counter <= bclk_counter + 1;
				If bclk_counter = mclk_bclk_ratio/2 - 1 Then
					bclk_counter <= 0;
					i2s_bclk_int <= Not i2s_bclk_int;

					-- change data on falling edge
					If i2s_bclk_int = '1' Then
						i2s_dacsd <= TX_DATA_latched(curr_bit);
						-- Shift the bits out on the falling edge of bclk
						curr_bit <= curr_bit - 1;
						If curr_bit = (BIT_DEPTH * CHANNEL_COUNT)/2 + 1 Then
							i2s_lrclk <= '0';
						Elsif curr_bit = 1 Then
							i2s_lrclk <= '1';
							-- read the next sample now
							TX_READY_int <= '1';
						Elsif curr_bit = 0 Then
							-- indicate cycle beginning now
							i2s_begin <= '1';
							curr_bit <= BIT_DEPTH * CHANNEL_COUNT - 1;
						End If;
						-- sample bit on rising edge
					Else
						RX_DATA(curr_bit) <= i2s_adcsd;
						If curr_bit = 0 Then
							RX_VALID <= '1';
						End If;
					End If;
				End If;
			End If;
		End If;
	End Process;

End Behavioral;