library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement an on-chip test pattern generator that drives the
-- DVideo2HDMI upscaler.
-- Running on an Cyclone V GX Starter Kit

entity TestDVideo2HDMI is	
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
      adv7511_de : out std_logic
	);	
end entity;


architecture immediate of TestDVideo2HDMI is

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
	
	
   component SevenSegmentDriver is
	port (
		data:     in STD_LOGIC_VECTOR(3 downto 0);
		en:       in STD_LOGIC;
		q:       out STD_LOGIC_VECTOR (6 downto 0)
	);	
	end component;
	
		
	signal DVID_CLK    : std_logic;
	signal DVID_SYNC   : std_logic;
	signal DVID_RGB    : STD_LOGIC_VECTOR(11 downto 0);

	signal digit0 : std_logic_vector(3 downto 0);
	signal digit1 : std_logic_vector(3 downto 0);
	signal digit2 : std_logic_vector(3 downto 0);
	signal digit3 : std_logic_vector(3 downto 0);
begin		

   part2 : DVideo2HDMI port map (
		CLK50, RST, 
		SWITCH, BUTTON, 
		adv7511_scl, adv7511_sda, adv7511_hs, adv7511_vs, adv7511_clk, adv7511_d, adv7511_de,
		DVID_CLK, DVID_SYNC, DVID_RGB );

	part3 : SevenSegmentDriver port map(digit0, '1', HEX0);
	part4 : SevenSegmentDriver port map(digit1, '1', HEX1);
	part5 : SevenSegmentDriver port map(digit2, '1', HEX2);
	part6 : SevenSegmentDriver port map(digit3, '1', HEX3);
		
		
	-------------------- test signal generator ------------
	process (CLK50)
	variable divider : integer range 0 to 7 := 0;         -- divider 50Mhz / 7 -> 7.142857 Mhz
	                             
	variable totallines : integer range 0 to 511 := 313;
	variable x : integer range 0 to 511 := 0;     
	variable y : integer range 0 to 511 := 0;     
		-- PAL (50,095 Hz frame rate):
		-- horizontal pixels: 457 (sync:34, bp:40, vis:371, fp:12)
		-- lines: 312 (sync+bp:5, vis:304, fp:3) 
		-- NTSC (60.11 Hz frame rate)
		-- horizontal pixels: 457 (same as PAL)
      -- lines: 260 (sync+bp:5, vis: 254, fp:3)
		 
	
	variable out_clk : std_logic := '0';
	variable out_sync : std_logic := '0';
	variable out_rgb : std_logic_vector(11 downto 0);
	
	begin
		
		if rising_edge(CLK50) then
		
			-- create pixel every 7th 50mhz clock
			if divider<6 then 
		      divider := divider+1;
			else
				divider := 0;
				out_clk := not out_clk;
				
				-- calculate color pattern including a centered reference frame
				out_rgb := std_logic_vector(to_unsigned((x/2) mod 16, 4))
							& std_logic_vector(to_unsigned((y/16) mod 16, 4))
							& std_logic_vector(to_unsigned((y/2) mod 16, 4));
							
				if x<34+40 or y<5 or x>=34+40+371 or y>=totallines-3
				or x=99 or x=418 or y=53 or y=252 then
					out_rgb := "000000000000";
				end if;
	
				-- calculate the hsync   
				if x<34 then
					out_sync := '0';
				else
					out_sync := '1';
				end if;
				
				-- for the vsync the sync signal is created differently
				if y<5 or y>=totallines-3 then				
					if x<17 or (x>=228 and x<228+17) then
						out_sync := '0';
					else 
						out_sync := '1';
					end if;
					if y<2 or (y=2 and x<228) then
						out_sync := not out_sync;
					end if;
				end if;
								
				-- increment the counters for the next pixel
				if x<456 then 
					x := x+1;
				else 
					x := 0;
					if y<totallines-1 then 
						y := y+1;
					else
						y := 0;
					end if;
				end if;
			end if;
			
			-- switch between two output modes
			if SWITCH(9) = '0' then
				totallines := 312;
			else
				totallines := 260;
			end if;				
		end if;
			
		
		DVID_CLK <= out_clk;	
		DVID_SYNC <= out_sync;
		DVID_RGB <= out_rgb;
			
		LED <= "000000000000000000";
		digit0 <= "0000";
		digit1 <= "0000";
		digit2 <= "0000";
		digit3 <= "0000";
	end process;
	
end immediate;

