-- A fifo for streaming
-- Julian Loiacono

Library IEEE;
Use IEEE.std_logic_1164.All;
Use IEEE.std_logic_unsigned.All;

Library UNISIM;
Use UNISIM.vcomponents.All;
Library UNIMACRO;
Use UNIMACRO.vcomponents.All;

Entity fifo_stream Is
	Generic (
		FIFO_SIZE : String := "18Kb"
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		din_ready : Out Std_logic;
		din_valid : In Std_logic;
		din_data : In Std_logic_vector;
		dout_ready : In Std_logic;
		dout_valid : Out Std_logic;
		dout_data : Out Std_logic_vector
	);
End fifo_stream;

Architecture Behavioral Of fifo_stream Is

	Signal fifo_almostfull : Std_logic := '0';
	Signal fifo_empty : Std_logic := '1';
	Signal peek_data : Std_logic_vector(din_data'high Downto din_data'low);
	Signal peek_valid : Std_logic := '0';
	Signal dout_valid_int : Std_logic := '0';
	Signal fifo_rden : Std_logic := '0';
	Signal initialized : Std_logic := '0';
	Signal fifo_wren : Std_logic := '0';
	Signal resetcount : Integer := 0;

	Signal fifo_FULL : Std_logic := '0';
	Signal fifo_RDERR : Std_logic := '0';
	Signal fifo_WRERR : Std_logic := '0';

Begin
	fifo_wren <= initialized And din_valid And Not rst;
	din_ready <= Not fifo_almostfull;
	dout_valid <= dout_valid_int;
	dout_data <= peek_data;
	-- if peek data is invalid or being read, and buffer is nonempty
	-- read it into peek
	fifo_rden <= Not fifo_empty And (Not dout_valid_int Or dout_ready);

	-- FIFO_SYNC_MACRO: Synchronous First-In, First-Out (FIFO) RAM Buffer
	--                  Artix-7
	-- Xilinx HDL Language Template, version 2019.2

	-- Note -  This Unimacro model assumes the port directions to be "downto". 
	--         Simulation of this model with "to" in the port directions could lead to erroneous results.

	-----------------------------------------------------------------
	-- DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width --
	-- ===========|===========|============|=======================--
	--   37-72    |  "36Kb"   |     512    |         9-bit         --
	--   19-36    |  "36Kb"   |    1024    |        10-bit         --
	--   19-36    |  "18Kb"   |     512    |         9-bit         --
	--   10-18    |  "36Kb"   |    2048    |        11-bit         --
	--   10-18    |  "18Kb"   |    1024    |        10-bit         --
	--    5-9     |  "36Kb"   |    4096    |        12-bit         --
	--    5-9     |  "18Kb"   |    2048    |        11-bit         --
	--    1-4     |  "36Kb"   |    8192    |        13-bit         --
	--    1-4     |  "18Kb"   |    4096    |        12-bit         --
	-----------------------------------------------------------------

	FIFO_SYNC_MACRO_inst2 : FIFO_SYNC_MACRO
	Generic Map(
		DEVICE => "7SERIES", -- Target Device: "VIRTEX5, "VIRTEX6", "7SERIES" 
		ALMOST_FULL_OFFSET => X"0080", -- Sets almost full threshold
		ALMOST_EMPTY_OFFSET => X"0080", -- Sets the almost empty threshold
		DATA_WIDTH => din_data'length, -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
		FIFO_SIZE => FIFO_SIZE) -- Target BRAM, "18Kb" or "36Kb" 
	Port Map(
		ALMOSTEMPTY => Open, -- 1-bit output almost empty
		ALMOSTFULL => fifo_almostfull, -- 1-bit output almost full
		DO => peek_data, -- Output data, width defined by DATA_WIDTH parameter
		EMPTY => fifo_empty, -- 1-bit output empty
		FULL => fifo_FULL, -- 1-bit output full
		RDCOUNT => Open, -- Output read count, width determined by FIFO depth
		RDERR => fifo_RDERR, -- 1-bit output read error
		WRCOUNT => Open, -- Output write count, width determined by FIFO depth
		WRERR => fifo_WRERR, -- 1-bit output write error
		CLK => CLK, -- 1-bit input clock
		DI => din_data, -- Input data, width defined by DATA_WIDTH parameter
		RDEN => fifo_rden, -- 1-bit input read wrrdenle
		RST => RST, -- 1-bit input reset
		WREN => fifo_wren -- 1-bit input write wrrdenle
	);
	-- End of FIFO_SYNC_MACRO_inst instantiation

	Process (clk)
	Begin
		If rising_edge(clk) Then
			If rst = '0' Then
				-- not valid if being read
				If dout_ready = '1' Then
					dout_valid_int <= '0';
				End If;

				-- if we read last cycle, data is valid
				If fifo_rden = '1' Then
					dout_valid_int <= '1';
				End If;

				resetcount <= 0;
			Else
				resetcount <= resetcount + 1;
				If resetcount >= 5 Then
					initialized <= '1';
				End If;
			End If;
		End If;
	End Process;
End;