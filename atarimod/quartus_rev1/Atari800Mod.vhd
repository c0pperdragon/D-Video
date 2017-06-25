library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.DVideo2HDMI_pkg.all;

-- Implement a GTIA emulation that creates an HDMI output
-- Running on a D-Video board

entity Atari800Mod is	
	port (
	   -- clocking input
		CLK50: in std_logic;	
	
		-- on-board user IO
		LED:  out STD_LOGIC_VECTOR (1 downto 0);
		
	   -- HDMI interface
		adv7511_scl: inout std_logic; 
		adv7511_sda: inout std_logic; 
      adv7511_hs : out std_logic; 
      adv7511_vs : out std_logic;
      adv7511_clk : out std_logic;
      adv7511_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7511_de : out std_logic;
		
		-- INPUT LINES  
		INPUTS     : in std_logic_vector(23 downto 0);
		INPUTS29   : in std_logic
	);	
end entity;


architecture immediate of Atari800Mod is
	
	component DVideo2HDMI is
	generic ( 
		 timings:videotimings;
		 configurations:pllconfigurations;
		 vstretch:boolean
	);
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
		DVID_REFCLK : in std_logic;
		DVID_HSYNC  : in std_logic;
		DVID_VSYNC  : in std_logic;
		DVID_RGB    : in STD_LOGIC_VECTOR(11 downto 0);
		
		-- debugging output ---
		DEBUG0 : out std_logic;
		DEBUG1 : out std_logic
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
	
		-- settings for possible resolutions in 50Hz
   constant timings:videotimings := ( 
		( 128 + 30, 200, 1280, 72, -131,  7*384,  7 + 9,  23, 1024, 3 ),   -- 1280x1024
		( 176 + 15, 264, 1680, 88,   72,  4*384,  6 + 2,  24, 1050, 3 ),   -- 1680x1050
		( 200 + 17, 312, 1920, 112, 192,  0*384,  5 + 26, 26, 1080, 3 )    -- 1920x1080
	);
	constant configurations:pllconfigurations := (
		-- 41:2 (low bandwidth)
			"000001000000000001"   -- CP,LF
		 & "100000000000000000"   -- N
		 & "000111110100111101"   -- M
	    & "000000011000000011"   -- C0
		 & "100000000000000000"   -- C1
		 & "100000000000000000"   -- C2
		 & "100000000000000000"   -- C3
       & "100000000000000000"   -- C4
		,
		 -- 217:8  (low bandwidth)
			"000001000100000001"   -- CP,LF
		 & "100000000000000000"   -- N
		 & "001101101101101100"   -- M
	    & "000000100000000100"   -- C0
		 & "100000000000000000"   -- C1
		 & "100000000000000000"   -- C2
		 & "100000000000000000"   -- C3
       & "100000000000000000"   -- C4
       ,
		 -- 197:6 (low bandwidth)
			"000001000100000001"   -- CP,LF
		 & "100000000000000000"   -- N
		 & "001100011101100010"   -- M
	    & "000000011000000011"   -- C0
		 & "100000000000000000"   -- C1
		 & "100000000000000000"   -- C2
		 & "100000000000000000"   -- C3
       & "100000000000000000"    -- C4
--		 -- 36:1 (low bandwidth)
--			"000001000000000001"   -- CP,LF
--		 & "100000000000000000"   -- N
--		 & "000110110000110110"   -- M
--	    & "000000010100000001"   -- C0
--		 & "100000000000000000"   -- C1
--		 & "100000000000000000"   -- C2
--		 & "100000000000000000"   -- C3
--       & "100000000000000000"   -- C4
--		 -- 32:1 (low bandwidth)
--			"000001000000000001"   -- CP,LF
--		 & "100000000000000000"   -- N
--		 & "001000000001000000"   -- M
--	    & "000000010000000010"   -- C0
--		 & "100000000000000000"   -- C1
--		 & "100000000000000000"   -- C2
--		 & "100000000000000000"   -- C3
--     & "100000000000000000"   -- C4
--		 -- 31:1 (low bandwidth)
--			"000001000000000001"   -- CP,LF
--		 & "100000000000000000"   -- N
--		 & "000111110000111110"   -- M
--	    & "000000010000000010"   -- C0
--		 & "100000000000000000"   -- C1
--		 & "100000000000000000"   -- C2
--		 & "100000000000000000"   -- C3
--      & "100000000000000000"   -- C4
	);

begin		
		
   part1 : DVideo2HDMI 
	generic map(timings,configurations,false) 
	port map (
		CLK50, '0', 
		adv7511_scl, adv7511_sda, adv7511_hs, adv7511_vs, adv7511_clk,
		adv7511_d, adv7511_de,
		DVID_CLK, INPUTS29, DVID_HSYNC, DVID_VSYNC, DVID_RGB,
		LED(0), LED(1)	
	);

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

end immediate;

