library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity PLLTest is	
	port (
	   -- clocking input
		CLK50: in std_logic;	
			
		-- GPIO  
		GPIO28    : out std_logic;
		GPIO29    : out std_logic;
		
		GPIO0 : in std_logic
	);	
end entity;


architecture immediate of PLLTest is

--   component PLL_DOUBLE is
--	PORT
--	(
--		areset		: IN STD_LOGIC  := '0';
--		inclk0		: IN STD_LOGIC  := '0';
--		c0		: OUT STD_LOGIC ;
--		locked		: OUT STD_LOGIC 
--	);
--	end component;
   component PLL_TIMES_35 is
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC 
	);
	end component;

--	signal PLLDOUBLEOUT : std_logic;
	signal PLLOUT : std_logic;
	signal PLLLOCKED: std_logic;
	
begin			

--   part3 : PLL_DOUBLE port map (
--		'0',   -- areset
--		GPIO0,
--		PLLDOUBLEOUT,
--		open 
--	);

   part4 : PLL_TIMES_35 port map (
		'0',   -- areset
		GPIO0,
		PLLOUT,
		PLLLOCKED 
	);
		

	-- produce a clock with 50/14 = 3,5714MHz  on GPIO29
	process (CLK50) 
	variable counter : integer range 0 to 13 := 0;
	variable out_clk : std_logic;
	begin
		if rising_edge(CLK50) then			
			case counter is
			when  0 => out_clk := '0';
			when  1 => out_clk := '0';
			when  2 => out_clk := '0';
			when  3 => out_clk := '0';
			when  4 => out_clk := '0';
			when  5 => out_clk := '0';
			when  6 => out_clk := '0';
			when  7 => out_clk := '1';
			when  8 => out_clk := '1';
			when  9 => out_clk := '1';
			when 10 => out_clk := '1';
			when 11 => out_clk := '1';
			when 12 => out_clk := '1';
			when 13 => out_clk := '1';
			end case;
						
			if counter<13 then
				counter := counter+1;
			else
				counter := 0;
			end if;
		end if;
		GPIO29 <= out_clk;
	end process;
	
	-- divide the PLL clock by the multiplication factor ----
	-- so the debug output is in sync with the input frequency 
	process (PLLOUT) 
	variable counter: integer range 0 to 999 := 0;
	variable b : std_logic := '0';
	begin
		if rising_edge(PLLOUT) and PLLLOCKED='1' then
			if counter<10 then
				b := '1';
			else 
				b := '0';
			end if;
		
			if counter<35-1 then
				counter := counter+1;
			else
				counter := 0;
			end if;
		end if;
		
		GPIO28 <= b;
	end process;
	

end immediate;

