library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a test image generator for the D-Video board.


entity LEDBlinker is	
	port (
	   -- clocking input
		CLK50: in std_logic;	
	
		-- on-board user IO
		LED:  out STD_LOGIC_VECTOR (1 downto 0);
		BUTTON: in STD_LOGIC;
		
	   -- HDMI interface
		adv7511_scl: inout std_logic; 
		adv7511_sda: inout std_logic; 
		adv7511_int : in std_logic;
      adv7511_hs : out std_logic; 
      adv7511_vs : out std_logic;
      adv7511_clk : out std_logic;
      adv7511_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7511_de : out std_logic;
		adv7511_spdif : out std_logic;
		
		-- INPUT LINES  
		INPUTS     : in std_logic_vector(31 downto 0)
	);	
end entity;


architecture immediate of LEDBlinker is
begin		
		
	process (CLK50) 
	variable x : std_logic := '0';
	variable cnt : integer range 0 to 49999999;
	
	begin
		if rising_edge(CLK50) then
			if cnt<49999999 then
				cnt := cnt+1;
			else 
				cnt := 0;
				x := not x;
			end if;
		end if;
		
		LED(0) <= x;
		LED(1) <= not x;
	end process;
	
end immediate;

