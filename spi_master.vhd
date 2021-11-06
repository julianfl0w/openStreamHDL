------------------------------------------------------------------------------/
-- Description: SPI (Serial Peripheral Interface) Master
--              Creates master based on input configuration.
--              Sends a byte one bit at a time on MOSI
--              Will also receive byte data one bit at a time on MISO.
--              Any data on input byte will be shipped out on MOSI.
--
--              To kick-off transaction, user must pulse TX_valid.
--              This module supports multi-byte transmissions by pulsing
--              TX_valid and loading up TX_data when TX_Ready_int is high.
--
--              This module is only responsible for controlling Clk, MOSI, 
--              and MISO.  If the SPI peripheral requires a chip-select, 
--              this must be done at a higher level.
--
-- Note:        Clk must be at least 2x faster than SPI_Clk
--
-- Generics:    SPI_MODE, can be 0, 1, 2, or 3.  See above.
--              Can be configured in one of 4 modes:
--              Mode | Clock Polarity (CPOL/CKP) | Clock Phase (CPHA)
--               0   |             0             |        0
--               1   |             0             |        1
--               2   |             1             |        0
--               3   |             1             |        1
--              More: https:--en.wikipedia.org/wiki/Serial_Peripheral_Interface_Bus#Mode_numbers
--              CLKS_PER_HALF_BIT - Sets frequency of SPI_Clk.  SPI_Clk is
--              derived from Clk.  Set to integer number of clocks for each
--              half-bit of SPI data.  E.g. 100 MHz Clk, CLKS_PER_HALF_BIT = 2
--              would create SPI_Clk of 25 MHz.  Must be >= 2
--
------------------------------------------------------------------------------/
-- Julian Loiacono edited this file
Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;

Entity spi_master Is
	Generic (
		SPI_MODE : Integer := 0;
		CLKS_PER_HALF_BIT : Integer := 1
	);
	Port (
		-- Control/Data Signals,
		Rst : In Std_logic; -- FPGA Reset
		Clk : In Std_logic; -- FPGA Clock
		-- send length stream
		TX_LengthIn_data : In Std_logic_vector(63 Downto 0) := (Others => '0');
		TX_LengthIn_ready : Out Std_logic := '0';
		TX_LengthIn_valid : In Std_logic := '0';

		-- TX (MOSI) Signals
		TX_data : In Std_logic_vector; -- Byte to transmit on MOSI
		TX_valid : In Std_logic; -- Data Valid Pulse with TX_data
		TX_Ready : Out Std_logic; -- Transmit Ready for next byte

		-- RX (MISO) Signals
		RX_ready : In Std_logic;
		RX_valid : Out Std_logic; -- Data Valid pulse (1 clock cycle)
		RX_data : Out Std_logic_vector; -- Byte received on MISO

		-- SPI Interface
		SPI_Cs : Out Std_logic := '1';
		SPI_Clk : Out Std_logic;
		SPI_Miso : In Std_logic_vector(0 Downto 0);
		SPI_Mosi : Out Std_logic_vector(0 Downto 0)
	);
End Entity spi_master;

Architecture RTL Of spi_master Is

	Type tb_statetype Is (HIGHPERIOD, IDLE, PREDATA, RISING, FALLING, POSTDATA);
	Signal spi_state : tb_statetype;

	Signal SPI_MOSI_valid : Std_logic := '0'; -- Data Valid Pulse with TX_data
	Signal SPI_MOSI_Ready : Std_logic := '0'; -- Transmit Ready for next byte

	Signal SPI_MISO_valid : Std_logic := '0'; -- Data Valid Pulse with TX_data
	Signal SPI_MISO_Ready : Std_logic := '0'; -- Transmit Ready for next byte

	-- SPI Interface (All Runs at SPI Clock Domain)
	Signal w_CPOL : Std_logic; -- Clock polarity
	Signal w_CPHA : Std_logic; -- Clock phase
	Signal count : Integer := 0;
	Signal current_bit : Integer := 7;

	Signal TX_LengthFifo_ready : Std_logic := '0';
	Signal TX_LengthFifo_valid : Std_logic := '0';
	Signal TX_LengthFifo_data : Std_logic_vector(63 Downto 0); -- data to sent

Begin
	-- CPOL: Clock Polarity
	-- CPOL=0 means clock idles at 0, leading edge is rising edge.
	-- CPOL=1 means clock idles at 1, leading edge is falling edge.
	w_CPOL <= '1' When (SPI_MODE = 2) Or (SPI_MODE = 3) Else '0';

	-- CPHA: Clock Phase
	-- CPHA=0 means the "out" side changes the data on trailing edge of clock
	--              the "in" side captures data on leading edge of clock
	-- CPHA=1 means the "out" side changes the data on leading edge of clock
	--              the "in" side captures data on the trailing edge of clock
	w_CPHA <= '1' When (SPI_MODE = 1) Or (SPI_MODE = 3) Else '0';
	SPI_CLK <= Not w_CPOL When spi_state = RISING Else w_CPOL;

	TX_LengthFifo_ready <= '1' When spi_state = IDLE And rst = '0' Else '0';

	SPI_Cs <= '1' When spi_state = IDLE Or spi_state = HIGHPERIOD Else '0';

	-- Purpose: Generate SPI Clock correct number of times when DV pulse comes
	Edge_Indicator : Process (Clk, Rst)
	Begin

		--SPI_CLK       <= w_CPOL; -- assign default state to idle state
		If rising_edge(Clk) Then
			If Rst = '1' Then
			Else

				count <= count + 1;

				-- every time we receive a length, return state to "predata" 
				If TX_LengthFifo_valid = '1' And TX_LengthFifo_ready = '1' Then
					count <= 0;
					spi_state <= PREDATA;
					current_bit <= to_integer(unsigned(TX_LengthFifo_data(31 Downto 0))) - 1;
				End If;

				-- every time we receive a bit, send it to mosi! decrement bit counter
				If SPI_MOSI_valid = '1' And SPI_MOSI_ready = '1' Then
					SPI_MOSI_ready <= '0';
					If current_bit = 0 Then
					Else
						current_bit <= current_bit - 1;
					End If;
				End If;

				If SPI_MISO_ready = '1' And SPI_MISO_valid = '1' Then
					SPI_MISO_valid <= '0';
				End If;

				Case(spi_state) Is
					When HIGHPERIOD =>
					If count = 5 Then
						spi_state <= IDLE;
					End If;
					When IDLE =>
					-- literally do nothing
					count <= 0;
					When PREDATA =>
					If count > 5 Then
						count <= 0;
						spi_state <= RISING;
					End If;
					-- RISING EDGE
					When RISING =>
					If count = CLKS_PER_HALF_BIT Then
						count <= 0;
						SPI_MISO_valid <= '1'; -- better be ready
						SPI_MOSI_ready <= '1';
						If current_bit = 0 Then
							spi_state <= POSTDATA;
						Else
							spi_state <= FALLING;
						End If;
					End If;
					When FALLING =>
					--SPI_CLK <= w_CPOL;
					If count = CLKS_PER_HALF_BIT Then
						--SPI_CLK <= not w_CPOL;
						count <= 0;
						spi_state <= RISING;
					End If;
					When POSTDATA =>
					If count = CLKS_PER_HALF_BIT * 12 Then
						count <= 0;
						spi_state <= HIGHPERIOD;
					End If;
					When Others =>
				End Case;
			End If;
		End If;
	End Process Edge_Indicator;

	-- have to do the copy verison here
	-- bc otherwise vivado gets confused
	-- when one serialzer is in tb and the other in system
	ser : Entity work.serializer_copy
		Port Map(
			clk => clk,
			rst => rst,
			din_ready => TX_ready,
			din_valid => TX_valid,
			din_data => TX_data,
			dout_ready => SPI_MOSI_Ready,
			dout_valid => SPI_MOSI_valid,
			dout_data => SPI_MOSI
		);
	deser : Entity work.deserializer_copy
		Port Map(
			clk => clk,
			rst => rst,
			din_ready => SPI_MISO_ready,
			din_valid => SPI_MISO_valid,
			din_data => SPI_MISO,
			dout_ready => RX_Ready,
			dout_valid => RX_valid,
			dout_data => RX_data
		);

	-- how many bytes to send
	fs1 : Entity work.fifo_stream_36
		Port Map(
			clk => clk,
			rst => rst,
			din_ready => TX_LengthIn_ready,
			din_valid => TX_LengthIn_valid,
			din_data => TX_LengthIn_data,
			dout_ready => TX_LengthFifo_ready,
			dout_valid => TX_LengthFifo_valid,
			dout_data => TX_LengthFifo_data
		);

End Architecture RTL;