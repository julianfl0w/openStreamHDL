----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 9/2021
----------------------------------------------------------------------------------

--SAVING THIS ISH FOR ANOTHER DAY
--(WHEN ARRAYS CAN BE PASSED)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity flow_mimo is
Port ( 
    clk       : in STD_LOGIC;
    rst       : in STD_LOGIC;

    in_ready  : out STD_LOGIC_VECTOR;
    in_valid  : in STD_LOGIC;
    in_addr   : in bus_array(2**sel_width - 1 downto 0, bus_width - 1 downto 0);
    
    out_addr  : out STD_LOGIC_VECTOR;  -- extra wide SLV width*stages
    out_ready : in STD_LOGIC_VECTOR;
    out_valid : out STD_LOGIC_VECTOR;
    
    valid_override : in std_logic_vector;
    run            : out std_logic_vector
    );
           
end flow_mimo;

architecture Behavioral of flow_mimo is

-- Each block gets its own independant address. 
-- ready is only asserted when the input block address matches
signal run_int  : std_logic_vector(run'range) := (others=>'0');
signal valid_if_no_override   : std_logic_vector(run'length-1 downto 0) := (others=>'0');
signal future_gap: std_logic_vector(run'range) := (others=>'0');
signal out_valid_int: std_logic_vector(run'high downto 1) := (others=>'0');
signal out_addr_int: std_logic_vector(run'high downto 1) := (others=>'0');

begin
run       <= run_int;
out_valid <= out_valid_int;
run_int(0)    <= future_gap(0) and in_valid and not rst;
future_gap(0) <=  '1' when ((not unsigned(out_valid_int(run'high downto 1))) /= 0 or out_ready(run'high) = '1') else '0';
genloop:
for i in 1 to run'high generate
    -- future gap if there is a non-out_valid_int ahead, or if output is ready
    future_gap(i) <= '1' when ((not unsigned(out_valid_int(run'high downto i+1))) /= 0 or out_ready(run'high) = '1') else '0';
    -- run when there is a gap and current step is out_valid_int
    run_int(i)    <= future_gap(i) and out_valid_int(i) and not rst;
    
    in_ready(i)   <= future_gap(i)   and not rst when in_addr(i) = out_addr_int(i) else '0'; -- only ready when addresses match
    
    out_valid_int(i) <= out_valid_int(i);
end generate;

out_valid_int <= valid_if_no_override and not valid_override and not rst;
runproc: process(clk)
begin
if rising_edge(clk) then  
    if rst = '0' then
    
        valid_if_no_override(1) <= not valid_if_no_override(0) and ((in_valid and future_gap(0)) or (valid_if_no_override(1) and not run_int(1)));
        for i in 2 to run'length-1 loop
            -- current step is out_valid_int if previous step ran, or current step was out_valid_int and didnt run
            -- and not validity override
            valid_if_no_override(i) <= (valid_if_no_override(i-1) and run_int(i-1)) or (valid_if_no_override(i) and not run_int(i));
        end loop;
        
        If run_int(Z00) = '1' Then
            Z00_Addr  <= Std_logic_vector(unsigned(Z00_Addr) + 1); -- always running, motherfucker!
            Addr(Z01) <= Z00_Addr;
        End If;
        
        addrloop :
        For i In Z02 To Addr'HIGH Loop
            If run(i - 1) = '1' Then
                Addr(i) <= Addr(i - 1);
            End If;
        End Loop;

    else
        valid_if_no_override <= (others=>'0');
    end if;
end if;
end process;
end Behavioral;