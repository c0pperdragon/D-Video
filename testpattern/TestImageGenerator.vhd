library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a test image generator for the D-Video board.


entity TestImageGenerator is	
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
		GPIO     : in std_logic_vector(30 downto 1);
		GPIO0    : out std_logic
	);	
end entity;


architecture immediate of TestImageGenerator is

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
	
			
	signal DVID_CLK    : std_logic;
	signal DVID_HSYNC   : std_logic;
	signal DVID_VSYNC   : std_logic;
	signal DVID_RGB    : STD_LOGIC_VECTOR(11 downto 0);
begin		
		
   part1 : DVideo2HDMI port map (
		CLK50, '0',
		adv7513_scl, adv7513_sda, adv7513_hs, adv7513_vs, adv7513_clk,
		adv7513_d, adv7513_de,
		DVID_CLK, DVID_HSYNC, DVID_VSYNC, DVID_RGB );

		
	------- audio signal (not used yet)
	process (CLK50)
	begin
		adv7513_spdif <= '0';
	end process;
		
		
	------- generator for the test image (a low-res DVideo signal)	
	process (CLK50) 
	variable ticks: integer range 0 to 6 := 0; -- divider 7 -> pixel clock: 7,14285 Mhz
	                                           -- need 142857 pixels per frame (461x310 is good enough)
	variable x:integer range 0 to 511 := 0;    -- 0 - 460
	variable y:integer range 0 to 511 := 0;    -- 0 - 309
	
	variable t_x: integer range 0 to 127; 
	variable t_y: integer range 0 to 63; 
	
	variable out_clk    : std_logic;
	variable out_hsync  : std_logic;
	variable out_vsync  : std_logic;
	variable out_rgb    : std_logic_vector(11 downto 0) := "000000000000";    
	
	begin
		if rising_edge(CLK50) then
		
			if ticks<6 then
				ticks := ticks+1;
			else
				ticks := 0;
				if x<460 then
				    x := x+1;
			   else
				   x := 0;
					if y<309 then
						y := y+1;
					else
						y := 0;
					end if;
				end if;
				
				out_clk := not out_clk;
				if x<400 then out_hsync:='0'; else out_hsync := '1'; end if;
				if y<270 then out_vsync:='0'; else out_vsync := '1'; end if;
				
				if x=0 or x=399 or y=0 or y=269 then
					out_rgb := "111111111111";
				elsif x>=40 and x<40+320 and y>=7 and y<7+256 then
					t_x := ((x-40)/4) mod 128;
					t_y := ((y-7)/4) mod 64;
					if t_x<64 then
						out_rgb(11 downto 8) := std_logic_vector(to_unsigned(t_x mod 16,4));	
						out_rgb(7 downto 4)  := std_logic_vector(to_unsigned(t_y mod 16,4));	
						out_rgb(3 downto 0)  := std_logic_vector(to_unsigned((t_x/16)+(t_y/16)*4,4));
					elsif t_x>=72 then
						out_rgb(11 downto 4) := "00000000";	
						out_rgb(3 downto 0)  := std_logic_vector(to_unsigned(t_y/4,4));
					elsif t_y<=30 then -- and GPIO(t_y)='0' then
						out_rgb(11 downto 0) := "111111111111";
					else 
						out_rgb(11 downto 0) := "000000000000";	
					end if;
				else
					out_rgb := "001100110011";
				end if;
							
			end if;
		end if;
		
		DVID_CLK <= out_clk;
		DVID_HSYNC <= out_hsync;
		DVID_VSYNC <= out_vsync;
		DVID_RGB <= out_rgb;			
	end process;


	process (CLK50) 
		variable ticks: integer range 0 to 49999999 := 0;
		variable p : std_logic := '0';
	begin
	
		if rising_edge(CLK50) then
		
			if ticks<49999999 then
				ticks := ticks+1;
			else
				ticks := 0;
				p := not p;
			end if;
			
		end if;
		
		GPIO0 <= p;
		
	end process;

end immediate;

