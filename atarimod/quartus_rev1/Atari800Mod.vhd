library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a GTIA emulation that creates an HDMI output
-- Running on a D-Video board

entity Atari800Mod is	
	port (
	   -- clocking input
		CLK50: in std_logic;	
	
		-- on-board user IO
		LED:  out STD_LOGIC_VECTOR (1 downto 0);
		BUTTON: in STD_LOGIC;
		
	   -- HDMI interface
		adv7511_scl: inout std_logic; 
		adv7511_sda: inout std_logic; 
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


architecture immediate of Atari800Mod is

   component DVideo2HDMI is
	port (
	   -- default clocking and reset
		CLK50: in std_logic;	
      RST: in std_logic;
		
	   -- HDMI interface
		adv7513_scl: inout std_logic; 
		adv7513_sda: inout std_logic; 
      adv7513_hs : out std_logic; 
      adv7513_vs : out std_logic;
      adv7513_clk : out std_logic;
      adv7513_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7513_de : out std_logic;

		-- DVideo input -----
		DVID_CLK    : in std_logic;
		DVID_HSYNC   : in std_logic;
		DVID_VSYNC   : in std_logic;
		DVID_RGB    : in STD_LOGIC_VECTOR(11 downto 0)	
	);	
	end component;
	
   component GTIA2DVideo is
	port (
		-- Connections to the real GTIAs pins (everything is inverted)
		CLK         : in std_logic;
		A           : in std_logic_vector(4 downto 0);
		D           : in std_logic_vector(7 downto 0);
		AN          : in std_logic_vector(2 downto 0);
		RW          : in std_logic;
		CS          : in std_logic;
		HALT        : in std_logic;
		
		-- output to the DVideo interface
		DVID_CLK    : out std_logic;
		DVID_VSYNC   : out std_logic;
		DVID_HSYNC   : out std_logic;
		DVID_RGB    : out STD_LOGIC_VECTOR(11 downto 0)	
	);	
	end component;
			
	signal DVID_CLK    : std_logic;
	signal DVID_VSYNC   : std_logic;
	signal DVID_HSYNC   : std_logic;
	signal DVID_RGB    : STD_LOGIC_VECTOR(11 downto 0);
begin		
		
   part1 : DVideo2HDMI port map (
		CLK50, not BUTTON, 
		adv7511_scl, adv7511_sda, adv7511_hs, adv7511_vs, adv7511_clk,
		adv7511_d, adv7511_de,
		DVID_CLK, DVID_HSYNC, DVID_VSYNC, DVID_RGB );

   part2 : GTIA2DVideo port map (
		NOT INPUTS(3),                                                                                                    -- CLK
		NOT (INPUTS(20 downto 20) & INPUTS(18) & INPUTS(16) & INPUTS(14) & INPUTS(12)),                                     -- A4-A0
		NOT (INPUTS(6 downto 6) & INPUTS(8) & INPUTS(10) & INPUTS(22) & INPUTS(11) & INPUTS(13) & INPUTS(17) & INPUTS(15)), -- D7-D0
		NOT (INPUTS(23 downto 23) & INPUTS(19) & INPUTS(21)),                                                               -- AN2-AN0
		NOT INPUTS(7),                                                                                                    -- RW
		NOT INPUTS(9),                                                                                                    -- CS
		NOT INPUTS(2),                                                                                                    -- HALT		
		DVID_CLK,
		DVID_VSYNC, 
		DVID_HSYNC, 
		DVID_RGB  );

		
	-- simple LED blinker to show that the board is working	
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
		
		adv7511_spdif <= '0';
	end process;

end immediate;

