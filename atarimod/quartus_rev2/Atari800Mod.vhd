library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a GTIA emulation that creates an HDMI output
-- Running on a D-Video board

entity Atari800Mod is	
	port (
	   -- clocking input
		CLK50: in std_logic;	
		
	   -- HDMI interface
		adv7513_scl: inout std_logic; 
		adv7513_sda: inout std_logic; 
      adv7513_hs : out std_logic; 
      adv7513_vs : out std_logic;
      adv7513_clk : out std_logic;
      adv7513_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7513_de : out std_logic;
		adv7513_spdif : out std_logic;
		
		-- GPIO  
		GPIO     : in std_logic_vector(22 downto 0)
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
		DVID_RGB    : in STD_LOGIC_VECTOR(11 downto 0);
		
		-- debugging output ---
		DEBUG : out std_logic
	);	
	end component;
	
   component GTIA2DVideo is
	port (
		-- Connections to the real GTIAs pins 
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
		CLK50, '0', 
		adv7513_scl, adv7513_sda, adv7513_hs, adv7513_vs, adv7513_clk,
		adv7513_d, adv7513_de,
		DVID_CLK, DVID_HSYNC, DVID_VSYNC, DVID_RGB,
		open	);

   part2 : GTIA2DVideo port map (
		NOT GPIO(2),                                                                                       -- CLK
		NOT (GPIO(19 downto 19) & GPIO(17) & GPIO(15) & GPIO(13) & GPIO(11)),                              -- A4-A0
		NOT (GPIO(5 downto 5) & GPIO(7) & GPIO(9) & GPIO(21) & GPIO(10) & GPIO(12) & GPIO(16) & GPIO(14)), -- D7-D0
		NOT (GPIO(22 downto 22) & GPIO(18) & GPIO(20)),                                                    -- AN2-AN0
		NOT GPIO(6),                                                                                       -- RW
		NOT GPIO(8),                                                                                       -- CS
		NOT GPIO(1),                                                                                       -- HALT		
		DVID_CLK,
		DVID_VSYNC, 
		DVID_HSYNC, 
		DVID_RGB  );

	------- direct wiring
	process (CLK50)
	begin
		adv7513_spdif <= '0';
	end process;

end immediate;

