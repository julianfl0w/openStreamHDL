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
		PROCESS_BW : Integer := 25;
		NOTECOUNT  : Integer := 1;
		NOTECOUNTLOG2: Integer := 0;
		PHASE_PRECISION : Integer := 32
	);
	
End chaser_mm_tb;

Architecture arch_imp Of chaser_mm_tb Is


    signal clk    : Std_logic := '0';
    signal rst    : Std_logic := '0';
    signal srun   : Std_logic_vector(6 downto 0) := (others=>'1');
    signal Z03_env_en : Std_logic := '1';
    
    signal mm_wraddr       : Std_logic_vector(0 downto 0) := (others=>'0');
    
    signal Z03_finished : Std_logic;
   
    signal Z00_addr     : Std_logic_vector(0 Downto 0) := "0";
            
	Signal Z02_moving : Std_logic_vector(0 Downto 0) := "0";
	Signal Z02_exp : Std_logic_vector(0 Downto 0) := b"1";

    Signal target_wr  : std_logic := '0';
    Signal porta_wr   : std_logic := '0';
    Signal exp_wr     : std_logic := '0';
    
    Signal mm_wrdata           : Std_logic_vector(32 - 1 Downto 0) := (Others => '0');
    Signal mm_wrdata_process   : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
    Signal mm_wrdata_phase     : Std_logic_vector(PHASE_PRECISION - 1 Downto 0) := (Others => '0');
    Signal mm_wrdata_processbw : Std_logic_vector(mm_wrdata'length - 1 Downto 0) := (Others => '0');
	Signal Z01_current : Std_logic_vector(mm_wrdata'length - 1 Downto 0) := (Others => '0');

        
Begin
    mm_wrdata_process   <= mm_wrdata(mm_wrdata_process  'high downto 0);
    mm_wrdata_phase     <= mm_wrdata(mm_wrdata_phase    'high downto 0);
    mm_wrdata_processbw <= mm_wrdata(mm_wrdata_processbw'high downto 0);

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
            COUNT     => 1,
            LOG2COUNT => 0
        )
        Port Map(
            clk => clk,
            rst => rst,
            srun=> srun,
            Z03_en => Z03_env_en,
            
            mm_wraddr => mm_wraddr,
            mm_wrdata => mm_wrdata,
            mm_wrdata_porta => mm_wrdata_process,
            
            Z00_rden => srun(Z00),
            Z00_addr => Z00_addr,
            Z01_current => Z01_current,
            Z03_finished => Z03_finished,
            exp_wr    => exp_wr,
            target_wr => target_wr,
            porta_wr  => porta_wr
    
        );
 
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

mm_wrdata <= std_logic_vector(to_unsigned(2**16, mm_wrdata'length));
porta_wr <= '1'; wait until rising_edge(clk); 
porta_wr <= '0'; 

mm_wrdata <= std_logic_vector(to_unsigned(2**25, mm_wrdata'length));
target_wr <= '1'; wait until rising_edge(clk); 
target_wr <= '0'; 

mm_wrdata <= std_logic_vector(to_unsigned(1, mm_wrdata'length));
exp_wr <= '1'; wait until rising_edge(clk); 
exp_wr <= '0'; 

wait until Z03_finished = '1';

mm_wrdata <= std_logic_vector(to_unsigned(0, mm_wrdata'length));
porta_wr <= '1'; wait until rising_edge(clk); 
porta_wr <= '0'; 

mm_wrdata <= std_logic_vector(to_unsigned(0, mm_wrdata'length));
target_wr <= '1'; wait until rising_edge(clk); 
target_wr <= '0'; 

--mm_wrdata <= std_logic_vector(to_unsigned(2**16, mm_wrdata'length));
--porta_wr <= '1'; wait until rising_edge(clk); 
--porta_wr <= '0'; 

wait;
end process;
End arch_imp;