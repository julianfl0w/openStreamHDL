library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_misc.ALL;
use ieee.math_real.all;
Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

package sine_table is    
  
    type a_sine_lut is array(0 to 127) of unsigned(16 downto 0);
    constant the_sine_lut : a_sine_lut :=
    (to_unsigned(0,17),to_unsigned(804,17), to_unsigned(1608,17), to_unsigned(2412,17),
    to_unsigned(3215,17),to_unsigned(4018,17), to_unsigned(4821,17), to_unsigned(5622,17),
    to_unsigned(6423,17),to_unsigned(7223,17), to_unsigned(8022,17), to_unsigned(8819,17),
    to_unsigned(9616,17),to_unsigned(10410,17), to_unsigned(11204,17), to_unsigned(11995,17),
    to_unsigned(12785,17),to_unsigned(13573,17), to_unsigned(14359,17), to_unsigned(15142,17),
    to_unsigned(15923,17),to_unsigned(16702,17), to_unsigned(17479,17), to_unsigned(18253,17),
    to_unsigned(19024,17),to_unsigned(19792,17), to_unsigned(20557,17), to_unsigned(21319,17),
    to_unsigned(22078,17),to_unsigned(22833,17), to_unsigned(23586,17), to_unsigned(24334,17),
    to_unsigned(25079,17),to_unsigned(25820,17), to_unsigned(26557,17), to_unsigned(27291,17),
    to_unsigned(28020,17),to_unsigned(28745,17), to_unsigned(29465,17), to_unsigned(30181,17),
    to_unsigned(30893,17),to_unsigned(31600,17), to_unsigned(32302,17), to_unsigned(32999,17),
    to_unsigned(33692,17),to_unsigned(34379,17), to_unsigned(35061,17), to_unsigned(35738,17),
    to_unsigned(36409,17),to_unsigned(37075,17), to_unsigned(37736,17), to_unsigned(38390,17),
    to_unsigned(39039,17),to_unsigned(39682,17), to_unsigned(40319,17), to_unsigned(40950,17),
    to_unsigned(41575,17),to_unsigned(42194,17), to_unsigned(42806,17), to_unsigned(43412,17),
    to_unsigned(44011,17),to_unsigned(44603,17), to_unsigned(45189,17), to_unsigned(45768,17),
    to_unsigned(46340,17),to_unsigned(46906,17), to_unsigned(47464,17), to_unsigned(48015,17),
    to_unsigned(48558,17),to_unsigned(49095,17), to_unsigned(49624,17), to_unsigned(50145,17),
    to_unsigned(50660,17),to_unsigned(51166,17), to_unsigned(51665,17), to_unsigned(52155,17),
    to_unsigned(52639,17),to_unsigned(53114,17), to_unsigned(53581,17), to_unsigned(54040,17),
    to_unsigned(54491,17),to_unsigned(54933,17), to_unsigned(55368,17), to_unsigned(55794,17),
    to_unsigned(56212,17),to_unsigned(56621,17), to_unsigned(57022,17), to_unsigned(57414,17),
    to_unsigned(57797,17),to_unsigned(58172,17), to_unsigned(58538,17), to_unsigned(58895,17),
    to_unsigned(59243,17),to_unsigned(59583,17), to_unsigned(59913,17), to_unsigned(60235,17),
    to_unsigned(60547,17),to_unsigned(60850,17), to_unsigned(61144,17), to_unsigned(61429,17),
    to_unsigned(61705,17),to_unsigned(61971,17), to_unsigned(62228,17), to_unsigned(62475,17),
    to_unsigned(62714,17),to_unsigned(62942,17), to_unsigned(63162,17), to_unsigned(63371,17),
    to_unsigned(63571,17),to_unsigned(63762,17), to_unsigned(63943,17), to_unsigned(64115,17),
    to_unsigned(64276,17),to_unsigned(64428,17), to_unsigned(64571,17), to_unsigned(64703,17),
    to_unsigned(64826,17),to_unsigned(64939,17), to_unsigned(65043,17), to_unsigned(65136,17),
    to_unsigned(65220,17),to_unsigned(65294,17), to_unsigned(65358,17), to_unsigned(65412,17),
    to_unsigned(65457,17),to_unsigned(65491,17), to_unsigned(65516,17), to_unsigned(65531,17));
        
    --attribute ram_style  : string;
    --attribute ram_style  of the_sine_lut : signal is "distributed";
    
end sine_table;
