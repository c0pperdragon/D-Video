library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity C642HDMI is	
	port (
		-- Input from C64 mod circuit
		C64_CLK     : in std_logic;
		C64_LUM     : in std_logic_vector(7 downto 0);
		C64_COL     : in std_logic_vector(7 downto 0);
		C64_AES     : in std_logic;

	   -- default clocking and reset
		CLK50: in std_logic;	
      RST: in std_logic;
	
		-- on-board user IO
		SWITCH: in STD_LOGIC_VECTOR(9 downto 0);
		BUTTON: in STD_LOGIC_VECTOR(3 downto 0);
		LED:  out STD_LOGIC_VECTOR (17 downto 0);
		HEX0: out STD_LOGIC_VECTOR (6 downto 0);
		HEX1: out STD_LOGIC_VECTOR (6 downto 0);
		HEX2: out STD_LOGIC_VECTOR (6 downto 0);
		HEX3: out STD_LOGIC_VECTOR (6 downto 0);
		
	   -- HDMI interface
		adv7511_scl: inout std_logic; 
		adv7511_sda: inout std_logic; 
      adv7511_hs : out std_logic; 
      adv7511_vs : out std_logic;
      adv7511_clk : out std_logic;
      adv7511_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7511_de : out std_logic
		
		-- Input from GPIO connected to VIC-II pins
		DVID_CLK    : in std_logic;
		DVID_SYNC   : in std_logic;
		DVID_DATA   : in std_logic_vector(11 downto 0);
	);	
end entity;


architecture immediate of C642HDMI is
	
   component C642DVideo is
	port (
		SWITCH: in STD_LOGIC_VECTOR(9 downto 0);
		BUTTON: in STD_LOGIC_VECTOR(3 downto 0);

		-- Input from C64 mod circuit
		DVID_CLK    : in std_logic;
		DVID_SYNC   : in std_logic;
		DVID_DATA   : out STD_LOGIC_VECTOR(11 downto 0)
	
		-- Output to DVideo interface -----
		DVID_RGB    : out STD_LOGIC_VECTOR(11 downto 0)
	);	
   end component;

	
   component DVideo2HDMI is
	port (
	   -- default clocking and reset
		CLK50: in std_logic;	
      RST: in std_logic;

		-- on-board user IO
		SWITCH: in STD_LOGIC_VECTOR(9 downto 0);
		BUTTON: in STD_LOGIC_VECTOR(3 downto 0);
		LED:  out STD_LOGIC_VECTOR (17 downto 0);
		HEX0: out STD_LOGIC_VECTOR (6 downto 0);
		HEX1: out STD_LOGIC_VECTOR (6 downto 0);
		HEX2: out STD_LOGIC_VECTOR (6 downto 0);
		HEX3: out STD_LOGIC_VECTOR (6 downto 0);
		
	   -- HDMI interface
		adv7511_scl: inout std_logic; 
		adv7511_sda: inout std_logic; 
      adv7511_hs : out std_logic; 
      adv7511_vs : out std_logic;
      adv7511_clk : out std_logic;
      adv7511_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7511_de : out std_logic;

		-- DVideo input -----
		DVID_CLK    : in std_logic;
		DVID_SYNC   : in std_logic;
		DVID_RGB    : in STD_LOGIC_VECTOR(11 downto 0)
	);	
	end component;
	
	
	signal DVID_RGB    : STD_LOGIC_VECTOR(11 downto 0);

	
begin		
	part1: C642DVideo	port map (
		SWITCH, BUTTON,
		DVID_CLK, DVID_SYNC, DVID_DATA,
		DVID_RGB);
	
   part2 : DVideo2HDMI port map (
		CLK50, RST, 
		SWITCH, BUTTON, LED, HEX0, HEX1, HEX2, HEX3,
		adv7511_scl, adv7511_sda, adv7511_hs, adv7511_vs, adv7511_clk, adv7511_d, adv7511_de,
		DVID_CLK, DVID_SYNC, DVID_RGB );
	
end immediate;

