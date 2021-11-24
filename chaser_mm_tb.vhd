Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.zconstants_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity chaser_mm_tb Is
	Generic (
		PROCESS_BW : Integer := 18;
        COUNT     : Integer := 16;
        LOG2COUNT : Integer := 4;
		PHASE_PRECISION : Integer := 32
	);
	
End chaser_mm_tb;

Architecture arch_imp Of chaser_mm_tb Is


    signal clk    : Std_logic := '0';
    signal rst    : Std_logic := '0';
    signal srun   : Std_logic_vector(6 downto 0) := (others=>'1');
    signal Z03_env_en : Std_logic := '1';
    
    signal mm_voiceaddr       : Std_logic_vector(LOG2COUNT-1 downto 0) := (others=>'0');
    
    signal Z04_finished : Std_logic;
   
    signal Z00_voiceaddr     : Std_logic_vector(LOG2COUNT-1 Downto 0) := (others=>'0');
            
	Signal Z02_moving : Std_logic_vector(0 Downto 0) := "0";
	Signal Z02_exp : Std_logic_vector(0 Downto 0) := b"1";

    Signal target_wr  : std_logic := '0';
    Signal rate_wr   : std_logic := '0';
    Signal exp_or_linear_wr     : std_logic := '0';
    
    Signal mm_wrdata           : Std_logic_vector(32 - 1 Downto 0) := (Others => '0');
    Signal mm_wrdata_rate   : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
    Signal mm_wrdata_phase     : Std_logic_vector(PHASE_PRECISION - 1 Downto 0) := (Others => '0');
    Signal mm_wrdata_ratebw : Std_logic_vector(mm_wrdata'length - 1 Downto 0) := (Others => '0');
	Signal Z01_current : Std_logic_vector(mm_wrdata'length - 1 Downto 0) := (Others => '0');

        
Begin
    mm_wrdata_rate   <= mm_wrdata(mm_wrdata_rate  'high downto 0);
    mm_wrdata_phase  <= mm_wrdata(mm_wrdata_phase 'high downto 0);
    mm_wrdata_ratebw <= mm_wrdata(mm_wrdata_ratebw'high downto 0);

    clk <= not clk after 10ns;
    
	sflow_i : Entity work.flow
		Port Map(
			clk => clk,
			rst => rst,

			in_ready  => open,
			in_valid  => '1',
			out_ready => '1',
			out_valid => open,

			run => srun
		);
		
    dut : Entity work.chaser_mm
        Generic Map(
            COUNT     => COUNT,
            LOG2COUNT => LOG2COUNT
        )
        Port Map(
            clk => clk,
            rst => rst,
            srun=> srun,
            Z03_en => Z03_env_en,
            
            mm_voiceaddr => mm_voiceaddr,
            mm_wrdata => mm_wrdata,
            mm_wrdata_rate => mm_wrdata_rate,
            
            Z00_rden => srun(Z00),
            Z00_voiceaddr => Z00_voiceaddr,
            Z01_current => Z01_current,
            Z04_finished => Z04_finished,
            exp_or_linear_wr    => exp_or_linear_wr,
            target_wr => target_wr,
            rate_wr  => rate_wr
    
        );
        
        
        sumproc2 :
        Process (clk)
        Begin
            If rising_edge(clk) Then
                If rst = '0' Then
                    If srun(Z00) = '1' Then
                        Z00_voiceaddr <= std_logic_vector(unsigned(Z00_voiceaddr) + 1);
                    End If;
                End If;
            End If;
        End Process;
     
-- cpu replacement process
process
begin
rst <= '1';
for ii in 0 to 300 loop
wait until rising_edge(clk);
end loop;
rst <= '0'; 
for ii in 0 to 300 loop
wait until rising_edge(clk); 
end loop;

mm_wrdata <= std_logic_vector(to_unsigned(1, mm_wrdata'length));
exp_or_linear_wr <= '1'; wait until rising_edge(clk); exp_or_linear_wr <= '0'; 

-- Change target, then rate
mm_wrdata <= std_logic_vector(to_unsigned(2**30, mm_wrdata'length));
target_wr <= '1'; wait until rising_edge(clk); target_wr <= '0'; 

mm_wrdata <= std_logic_vector(to_unsigned(integer(2**16 * 0.01), mm_wrdata'length));
rate_wr <= '1'; wait until rising_edge(clk); rate_wr <= '0'; 

wait until Z04_finished = '1'; 

-- stop motion
mm_wrdata <= std_logic_vector(to_unsigned(0, mm_wrdata'length));
rate_wr <= '1'; wait until rising_edge(clk); rate_wr <= '0'; 

-- change target
mm_wrdata <= std_logic_vector(to_unsigned(0, mm_wrdata'length));
target_wr <= '1'; wait until rising_edge(clk); target_wr <= '0'; 

-- set rate
mm_wrdata <= std_logic_vector(to_unsigned(integer(2**16 * 0.01), mm_wrdata'length));
rate_wr <= '1'; wait until rising_edge(clk); rate_wr <= '0'; 

wait until Z04_finished = '1';

mm_wrdata <= std_logic_vector(to_unsigned(0, mm_wrdata'length));
exp_or_linear_wr <= '1'; wait until rising_edge(clk); exp_or_linear_wr <= '0'; 

-- Change target, then rate
mm_wrdata <= std_logic_vector(to_unsigned(2**30, mm_wrdata'length));
target_wr <= '1'; wait until rising_edge(clk); target_wr <= '0'; 

mm_wrdata <= std_logic_vector(to_unsigned(integer(2**16 * 0.001), mm_wrdata'length));
rate_wr <= '1'; wait until rising_edge(clk); rate_wr <= '0'; 

wait until Z04_finished = '1'; 

-- stop motion
mm_wrdata <= std_logic_vector(to_unsigned(0, mm_wrdata'length));
rate_wr <= '1'; wait until rising_edge(clk); rate_wr <= '0'; 

-- change target
mm_wrdata <= std_logic_vector(to_unsigned(0, mm_wrdata'length));
target_wr <= '1'; wait until rising_edge(clk); target_wr <= '0'; 

-- set rate
mm_wrdata <= std_logic_vector(to_unsigned(integer(2**16 * 0.001), mm_wrdata'length));
rate_wr <= '1'; wait until rising_edge(clk); rate_wr <= '0'; 

wait until Z04_finished = '1';

--mm_wrdata <= std_logic_vector(to_unsigned(2**16, mm_wrdata'length));
--rate_wr <= '1'; wait until rising_edge(clk); 
--rate_wr <= '0'; 

wait;
end process;
End arch_imp;