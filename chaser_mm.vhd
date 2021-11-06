Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity chaser_mm Is
	Generic (
		LPF       : Integer := 0;
		COUNT     : Integer := 128;
		LOG2COUNT : Integer := 7
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		srun: in Std_logic_vector;
		Z03_en  : In Std_logic;
        
        target_wr : in std_logic;
        porta_wr  : in std_logic;
        exp_wr    : in std_logic;
        mm_wraddr : In Std_logic_vector;
		mm_wrdata : In Std_logic_vector; 
		mm_wrdata_porta : In Std_logic_vector; 
		
        Z03_finished : out std_logic;
		 
		Z00_rden   : In Std_logic; -- should be 1 before data
		Z00_addr   : In Std_logic_vector; -- should be 1 before data
		Z01_current: Out Std_logic_vector := (Others => '0')
	);
End chaser_mm;

Architecture arch_imp Of chaser_mm Is

	Signal Z01_srun: Std_logic_vector(srun'high -Z01 downto 0);
	Signal mm_wrdata_processbw : Std_logic_vector(mm_wrdata'length - 1 Downto 0) := (Others => '0');
	Signal selectionBit : Std_logic := '0';
	
    Signal Z02_moving : Std_logic_vector(0 downto 0) := "0";
    Signal Z02_moving_last : Std_logic_vector(0 downto 0) := "0";
	Signal Z01_target   : Std_logic_vector(mm_wrdata'length - 1 Downto 0);
	Signal Z01_current_int  : Std_logic_vector(mm_wrdata'length - 1 Downto 0) := (Others => '0');
	Signal Z01_porta    : Std_logic_vector(mm_wrdata_porta'length - 1 Downto 0);
	Signal Z02_porta    : sfixed(1 downto -mm_wrdata_porta'length + 2);
	Signal Z04_current  : sfixed(1 downto -mm_wrdata'length + 2);
	Signal Z04_current_slv  : Std_logic_vector(mm_wrdata'high downto 0);

	Signal Z02_exp    : Std_logic_vector(0 Downto 0) := b"1";
	
	Signal Z01_addr   : Std_logic_vector(Z00_addr'high downto 0); -- should be 1 before data
	Signal Z02_addr   : Std_logic_vector(Z00_addr'high downto 0); -- should be 1 before data
	Signal Z03_addr   : Std_logic_vector(Z00_addr'high downto 0); -- should be 1 before data
    Signal Z04_addr   : Std_logic_vector(Z00_addr'high downto 0); -- should be 1 before data

Begin
    Z01_srun <= srun(srun'high downto Z01);
    Z04_current_slv <= std_logic_vector(Z04_current);
	sumproc2 :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			If rst = '0' Then
                
                If srun(Z00) = '1' Then
                    Z01_ADDR <= Z00_ADDR;
                End If;
                If srun(Z01) = '1' Then
                    Z02_ADDR <= Z01_ADDR;
                    Z02_porta<= sfixed(Z01_porta);
                End If;

                Z03_finished <= '0';
                If srun(Z02) = '1' Then
                    Z03_ADDR <= Z02_ADDR;
                    -- if the thing stopped moving, report it finished
                    if Z02_moving(0) = '0' and Z02_moving_last(0) = '1' then
                        Z03_finished <= '1';
                    end if;
                End If;
                
                If srun(Z03) = '1' Then
                    Z04_ADDR <= Z03_ADDR;
                End If;
                
            End If;
		End If;
	End Process;
    Z01_current <= Z01_current_int;
    -- we need to periodically reduce these values 
    -- so they dont get stuck
    target : Entity work.simple_dual_one_clock
        Port Map(
            clk => clk,
            wea => '1',
            wraddr => mm_wraddr,
            wrdata => mm_wrdata,
            wren   => target_wr,
            rden   => srun(Z00),
            rdaddr => Z00_addr,
            rddata => Z01_target
        );
    
    smoothed : Entity work.simple_dual_one_clock
        Port Map(
            clk => clk,
            wea => '1',
            wraddr => Z04_addr,
            wrdata => Z04_current_slv,
            wren   => srun(Z04),
            rden   => srun(Z00),
            rdaddr => Z00_addr, 
            rddata => Z01_current_int
        );
        
    moving : Entity work.simple_dual_one_clock
        Port Map(
            clk => clk,
            wea => '1',
            wraddr => Z02_addr,
            wrdata => Z02_moving,
            wren   => srun(Z02),
            rden   => srun(Z01),
            rdaddr => Z01_addr,
            rddata => Z02_moving_last
        );
    
    porta : Entity work.simple_dual_one_clock
        Port Map(
            clk => clk,
            wea => '1',
            wraddr => mm_wraddr,
            wrdata => mm_wrdata_porta,
            wren   => porta_wr,
            rden   => srun(Z00),
            rdaddr => Z00_addr,
            rddata => Z01_porta
        );
    -- sets exponent mode
    exp : Entity work.simple_dual_one_clock
        Port Map(
            clk => clk,
            wea => '1',
            wraddr => mm_wraddr,
            wrdata => mm_wrdata(0 downto 0),
            wren   => exp_wr,
            rden   => srun(Z01),
            rdaddr => Z01_addr,
            rddata => Z02_exp
        );
      
        
    chaser_i : Entity work.chaser
    --        Generic Map(
    --        )
        Port Map(
            clk         => clk         ,
            rst         => rst         ,
            srun        => Z01_srun    ,
            Z02_en      => Z03_en,
            Z01_exp     => Z02_exp(0),
            
            Z00_target  => Z01_target  ,
            Z00_current => Z01_current_int ,
            Z00_addr    => Z01_addr    ,
            Z01_porta   => Z02_porta   ,
            Z02_moving  => Z02_moving(0),
            Z03_current => Z04_current 
        );

End arch_imp;