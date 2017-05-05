library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement the GTIA emulator together with the DVideo2HDMI upscaler 
-- on a Cyclone 5 GX Starter Board


entity Atari2HDMI is	
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

		-- GPIO  
		GPIO0       : in std_logic;
		GPIO        : in std_logic_vector(19 downto 1)
	);	
end entity;


architecture immediate of Atari2HDMI is

   component GTIA is
	port (
		-- Connections to the real GTIAs pins
		CLK         : in std_logic;
		A           : in std_logic_vector(4 downto 0);
		D           : in std_logic_vector(7 downto 0);
		AN          : in std_logic_vector(2 downto 0);
		W           : in std_logic;
		CS          : in std_logic;
		PHI2        : in std_logic;
		HALT        : in std_logic;
		
		-- Output to DVID interface (CLK is bypassed directly) ---
		DVID_SYNC   : out std_logic;
		DVID_RGB    : out std_logic_vector(11 downto 0)
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
	
--   component PLL_100 is
--	port (
--		refclk   : in  std_logic; --  refclk.clk
--		rst      : in  std_logic; --   reset.reset
--		outclk_0 : out std_logic  -- outclk0.clk
--	);
-- end component;
	
   component SevenSegmentDriver is
	port (
		data:     in STD_LOGIC_VECTOR(3 downto 0);
		en:       in STD_LOGIC;
		q:       out STD_LOGIC_VECTOR (6 downto 0)
	);	
	end component;
	

--	signal CLK100 : std_logic;
		
	signal DVID_CLK    : std_logic;
	signal DVID_SYNC   : std_logic;
	signal DVID_RGB    : STD_LOGIC_VECTOR(11 downto 0);

	signal digit0 : std_logic_vector(3 downto 0);
	signal digit1 : std_logic_vector(3 downto 0);
	signal digit2 : std_logic_vector(3 downto 0);
	signal digit3 : std_logic_vector(3 downto 0);
begin		
		
	part1: GTIA	port map (
		DVID_CLK,                                                                 -- CLK 
		GPIO(12)&GPIO(11)&GPIO(10)&GPIO(9)&GPIO(8),                            -- A (4 downto 0)
		GPIO(16)&GPIO(15)&GPIO(14)&GPIO(13)&GPIO(7)&GPIO(6)&GPIO(5)&GPIO(4),	  -- D (7 downto 0)
		GPIO(1)&GPIO(2)&GPIO(3),                                               -- AN (2 downto 0)
		GPIO(17),			                                                     -- W 
		GPIO(18), 		                                                        -- CS
		GPIO(19),                                                              -- PHI2
		GPIO(19),			                                                     -- HALT
		DVID_SYNC, DVID_RGB);
	
   part2 : DVideo2HDMI port map (
		CLK50, RST, 
		SWITCH, BUTTON, 
		adv7511_scl, adv7511_sda, adv7511_hs, adv7511_vs, adv7511_clk, adv7511_d, adv7511_de,
		DVID_CLK, DVID_SYNC, DVID_RGB );

--   part3 : PLL_100 port map (
--		CLK50, not RST, CLK100 );
	part3 : SevenSegmentDriver port map(digit0, '1', HEX0);
	part4 : SevenSegmentDriver port map(digit1, '1', HEX1);
	part5 : SevenSegmentDriver port map(digit2, '1', HEX2);
	part6 : SevenSegmentDriver port map(digit3, '1', HEX3);
		
		
	process (GPIO0) 
--	variable in_clk : std_logic := '0';
--	variable out_clk : std_logic := '0';
--	variable inhibit : integer range 0 to 15 := 0;
	variable var_v : std_logic_vector(7 downto 0) := "00000000";
	variable var_x : std_logic_vector(7 downto 0) := "00000000";
	variable tmp_a : std_logic_vector(4 downto 0);
	variable tmp_d : std_logic_vector(7 downto 0);
	begin
	
--		if rising_edge(CLK100) then
--			if in_clk/=out_clk and inhibit=0 then
--			   out_clk := in_clk;
--				inhibit := 10;
--			elsif inhibit > 0 then
--				inhibit := inhibit-1;
--			end if;
--	
--			in_clk := GPIO0;
--		end if;
		
		
		DVID_CLK <= GPIO0; -- out_clk;
	
		LED <= "000000000000000000";
		digit0 <= var_v (3 downto 0);
		digit1 <= var_v (7 downto 4);
		digit2 <= var_x (3 downto 0);
		digit3 <= var_x (7 downto 4);

		if rising_edge(GPIO0) then
		
			if (GPIO(17)='0') and (GPIO(18)='0') and (GPIO(19)='1') then  -- CS and W and phi0
				tmp_a := GPIO(12)&GPIO(11)&GPIO(10)&GPIO(9)&GPIO(8);
				tmp_d := GPIO(16)&GPIO(15)&GPIO(14)&GPIO(13)&GPIO(7)&GPIO(6)&GPIO(5)&GPIO(4);
				
				if tmp_a = SWITCH(9 downto 5) then
					var_v := tmp_d;
					var_x := std_logic_vector(to_unsigned(to_integer(unsigned(var_x)) + 1, 8));
				end if;
			end if;
		end if;
			
	end process;
	
end immediate;

