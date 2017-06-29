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
		
	   -- HDMI interface
		adv7513_scl: inout std_logic; 
		adv7513_sda: inout std_logic; 
      adv7513_hs : out std_logic; 
      adv7513_vs : out std_logic;
      adv7513_clk : out std_logic;
      adv7513_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7513_de : out std_logic;
		
		-- GPIO  
		GPIO     : in std_logic_vector(22 downto 0);
		
		GPIO30 : out std_logic;
		GPIO29 : out std_logic
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

		-- settings for possible resolutions in 50Hz
   constant timings:videotimings := ( 
		( 128 + 30, 200, 1280, 72, -131,  7*384,  7 + 9,  23, 1024, 3 ),   -- 1280x1024
		( 176 + 15, 264, 1680, 88,   72,  4*384,  6 + 2,  24, 1050, 3 ),   -- 1680x1050
		( 200 + 17, 312, 1920, 112, 192,  0*384,  5 + 26, 26, 1080, 3 )    -- 1920x1080
--		( 32    ,   80, 1920,  48,  192,  0*384,  5 ,     26, 1080, 3 )    -- 1920x1080
	);
	constant configurations:pllconfigurations := (
		-- 41:2 
			"000001000000000001"   -- CP,LF
		 & "100000000000000000"   -- N
		 & "000111110100111101"   -- M = 62 + 61 
	    & "000000011000000011"   -- C0 = 3 + 3
		 & "100000000000000000"   -- C1
		 & "100000000000000000"   -- C2
		 & "100000000000000000"   -- C3
       & "100000000000000000"   -- C4
		,
		 -- 217:8 
			"000001000100000001"   -- CP,LF
		 & "100000000000000000"   -- N
		 & "001101101101101100"   -- M = 109 + 108
	    & "000000100000000100"   -- C0 = 4 + 4
		 & "100000000000000000"   -- C1
		 & "100000000000000000"   -- C2
		 & "100000000000000000"   -- C3
       & "100000000000000000"   -- C4
       ,
		 -- 197:6 
			"000001000100000001"   -- CP,LF
		 & "100000000000000000"   -- N
		 & "001100011101100010"   -- M = 99 + 98
	    & "000000011000000011"   -- C0 = 3 + 3
		 & "100000000000000000"   -- C1
		 & "100000000000000000"   -- C2
		 & "100000000000000000"   -- C3
       & "100000000000000000"   -- C4
--		 -- 31:1 (low bandwidth)
--			"000001000000000001"   -- CP,LF
--		 & "100000000000000000"   -- N
--		 & "000111110000111110"   -- M
--	    & "000000010000000010"   -- C0
--		 & "100000000000000000"   -- C1
--		 & "100000000000000000"   -- C2
--		 & "100000000000000000"   -- C3
--     & "100000000000000000"   -- C4
--		 -- 217:6  
 --  		"000001000100000001"   -- CP,LF
--		 & "100000000000000000"   -- N
--		 & "001101101101101100"   -- M
--	    & "000000011000000011"   -- C0
--		 & "100000000000000000"   -- C1
--		 & "100000000000000000"   -- C2
--		 & "100000000000000000"   -- C3
--     & "100000000000000000"   -- C4
--       ,
--		 -- 50Mhz -> 146Mhz
--			"000010100100000001"   -- CP,LF
--		 & "000000011100000010"   -- N
--		 & "000100101100100100"   -- M
--	    & "000000011100000010"   -- C0
--		 & "100000000000000000"   -- C1
--		 & "100000000000000000"   -- C2
--		 & "100000000000000000"   -- C3
--     & "100000000000000000"   -- C4
	);

begin		
		
   part1 : DVideo2HDMI 
	generic map(timings,configurations,false) 
	port map (
		CLK50, '0', 
		adv7513_scl, adv7513_sda, adv7513_hs, adv7513_vs, adv7513_clk,
		adv7513_d, adv7513_de,
		DVID_CLK, -- CLK50,
		GPIO(0), 
		DVID_HSYNC, DVID_VSYNC, DVID_RGB,
		GPIO29, GPIO30 );

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


end immediate;

