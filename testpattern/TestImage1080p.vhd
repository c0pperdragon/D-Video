library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a simple test image generator for the D-Video board.
-- Straight forward 1080p image. No bells and whistles.

entity TestImage1080p is	
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
      adv7513_de : out std_logic
	);	
end entity;


architecture immediate of TestImage1080p is

component PLL_148_8 is
PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
end component;

component ConfigureADV7513 is	
	port (
		CLK50: in std_logic;			
		adv7513_scl: inout std_logic; 
		adv7513_sda: inout std_logic;
		SERIALOUT: out std_logic
	);	
end component;
	
	
signal CLKPIXEL    : std_logic;
		
begin		
	pixelclockgenerator: PLL_148_8 port map ( CLK50, CLKPIXEL );
	configurator: ConfigureADV7513 port map ( CLK50, adv7513_scl, adv7513_sda, open );

	------- generator for the HDMI test image 	
	process (CLKPIXEL) 

-- ModeLine "1920x1080" 148.800 1920 2448 2492 2622 1080 1084 1089 1135 +hsync +vsync  (50Hz)
--           1920x1080" 148.800 1920 2008 2052 2185 1080 1084 1089 1135 +hsync +vsync  (60Hz)
	constant h_img :  integer := 1920;
	constant h_fp :   integer := 2008-1920;
	constant h_sync : integer := 2052-2008;
	constant h_bp :   integer := 2185-2052;
	constant s_hsync : std_logic := '1';
	constant v_img :  integer := 1080;
	constant v_fp :   integer := 1084-1080;
	constant v_sync : integer := 1089-1084;
	constant v_bp :   integer := 1135-1089;
	constant s_vsync : std_logic := '1';
 	
	constant w : integer := h_sync + h_bp + h_img + h_fp; 
	constant h : integer := v_sync + v_bp + v_img + v_fp; 

	variable x:integer range 0 to w-1:= 0;  
	variable y:integer range 0 to h-1 := 0;  	
	
	variable out_hs  : std_logic := '0';
	variable out_vs  : std_logic := '0';
	variable out_clk : std_logic := '0';
	variable out_d : std_logic_vector(23 downto 0) := "000000000000000000000000";    
	variable out_de  : std_logic := '0';    
	
	variable px:integer range 0 to h_img-1;  
	variable py:integer range 0 to v_img-1; 	
		
	begin

		if rising_edge(CLKPIXEL) then
			-- create output signals
			out_d := "000000000000000000000000";
			out_de := '0';
			if x<h_sync then
				out_hs := s_hsync;
			else
				out_hs := not s_hsync;
			end if;
			if y<v_sync then
				out_vs := s_vsync;
			else
				out_vs := not s_vsync;
			end if;
			
			if   x>=h_sync+h_bp and x<h_sync+h_bp+h_img 
			and  y>=v_sync+v_bp and y<v_sync+v_bp+v_img 
			then
				out_de := '1';
				px := x-h_sync-h_bp;
				py := y-v_sync-v_bp;
				if px=0 or py=0 or px=h_img-1 or py=v_img-1 or px=py then
					out_d := "111111111111111111111111";
				else
					out_d := std_logic_vector(to_unsigned(px mod 256, 8)) 
							 &	std_logic_vector(to_unsigned(py mod 256, 8))  
							 &	std_logic_vector(to_unsigned(
								(px/256)*16 + (py/256)*64, 8));				
				end if;		
			end if;
			
			
			-- progress counters
			if x<w-1 then
				x:=x+1;
			else
				x:= 0;
				if y<h-1 then
					y:=y+1;
				else
					y:=0;
				end if;
			end if;
		end if;
			
		
      adv7513_hs <= out_hs;
      adv7513_vs <= out_vs;
      adv7513_clk <= CLKPIXEL;
		adv7513_d <= out_d;
      adv7513_de <= out_de;
	end process;

end immediate;

