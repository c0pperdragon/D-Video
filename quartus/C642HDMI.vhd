library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity C642HDMI is	
	port (
--		atan_zero : in integer range 0 to 255;
--		atan_x    : in integer range 0 to 255;
--		atan_y    : in integer range 0 to 255;
--		atan_phi  : out integer range 0 to 255;
--		atan_d2   : out integer range 0 to 65535;
	
	
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
		
		-- GPIO on board
		GPI: in std_logic_vector(15 downto 0);
		GPO: out std_logic_vector(21 downto 16)
	);	
end entity;


architecture immediate of C642HDMI is
	

   component PLL_63_0 is
	port (
		refclk   : in  std_logic; --  refclk.clk
		rst      : in  std_logic; --   reset.reset
		outclk_0 : out std_logic  -- outclk0.clk
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

	
		subtype int8 is integer range 0 to 255;
		subtype int16 is integer range 0 to 65535;
	  	type T_atan is array (0 to 63) of integer range 0 to 31;
		constant atan : T_atan := (
			0,  0, 1, 1, 2, 3, 3, 4, 5, 5, 6, 6, 7, 8, 8, 9,
			9, 10,11,11,12,12,13,14,14,15,15,16,16,17,17,18,
			18,19,19,20,20,21,21,22,22,23,23,24,24,24,25,25,
			26,26,27,27,27,28,28,28,29,29,29,30,30,31,31,31
		);
		-- determine the angle for a given x/y pair. 
		-- x,y are specified in unsigned values, the real x,y offsets are the differences to  
		-- the zero level 		
		-- returns the angle in 256th of a full circle (values 0 - 255)
		function atan2(zero : int8; x : int8; y : int8) return int8 is
		variable xa : int8;
		variable ya : int8;		
		variable quadrant : integer range 0 to 3;
		variable a : integer range 0 to 127;
		variable n : integer range 0 to 65535;
		variable m : integer range 0 to 63;
		begin
			-- quick termination if coordinates lie on some axis
			if y=zero then 
				if x>=zero then return 0;
				else            return 128;
				end if;
			elsif x=zero then
				if y>=zero then return 64;
				else            return 192;
				end if;
			end if;
			-- determine quadrant and coordinates relative to the zero level
			if x>zero then 
				if y>zero then 
					xa := x-zero;
					ya := y-zero;
					quadrant := 0;
				else
					xa := x-zero;
					ya := zero-y;
					quadrant := 3;
				end if;
			else
				if y>zero then 
					xa := zero-x;
					ya := y-zero;
					quadrant := 1;
				else
					xa := zero-x;
					ya := zero-y;
					quadrant := 2;
				end if;
			end if; 
			-- compute differently depending on x or y being bigger
			if xa=ya then
				a:= 32;
			elsif xa>ya then
				n := ya;
				n := (n*64) / xa;
				m := n;
				a := atan(m);
			else
				n := xa;
				n := (n*64) / ya;
				m := n;
				a := 64 - atan(m);
			end if; 
			-- translate back into proper quadrant
			case quadrant is 
			when 0 => return a;
			when 1 => return 128-a;
			when 2 => return 128+a;
			when 3 => return 256-a;
			end case;
		end atan2;
		
		function distance(a : int8; b : int8) return int8 is
		begin
			if a>b then 
				return a-b;
			else
				return b-a;
			end if;
		end distance;
		
		function sqr(a : int8) return int16 is
		variable tmp : int16;
		begin
			tmp := a;
			tmp := tmp*a;
			return tmp;
		end sqr;
		
		
	signal C64REFCLK   : std_logic;  
	signal DVID_CLK    : std_logic;
	signal DVID_SYNC   : std_logic;
	signal DVID_RGB    : STD_LOGIC_VECTOR(11 downto 0);
	
	signal digit0 : STD_LOGIC_VECTOR(3 downto 0);
	signal digit1 : STD_LOGIC_VECTOR(3 downto 0);
	signal digit2 : STD_LOGIC_VECTOR(3 downto 0);
	signal digit3 : STD_LOGIC_VECTOR(3 downto 0);
	
begin		

	
	c64referenceclockgenerator: PLL_63_0 port map (CLK50, not RST, C64REFCLK);
		
   part2 : DVideo2HDMI port map (
		CLK50, RST, 
		SWITCH, BUTTON, LED,
		adv7511_scl, adv7511_sda, adv7511_hs, adv7511_vs, adv7511_clk, adv7511_d, adv7511_de,
		DVID_CLK, DVID_SYNC, DVID_RGB );
	
   hex0driver : SevenSegmentDriver port map(digit0, '1', HEX0); 
   hex1driver : SevenSegmentDriver port map(digit1, '1', HEX1); 
   hex2driver : SevenSegmentDriver port map(digit2, '1', HEX2); 
   hex3driver : SevenSegmentDriver port map(digit3, '1', HEX3); 
	
  process (C64REFCLK) 
  
  variable pixelclockphase : integer range 0 to 7:= 0;
  
  variable in_lum : integer range 0 to 255;
  variable in_col : integer range 0 to 255;
  variable in_colaux : integer range 0 to 255;
  variable in_colorphase : integer range 0 to 255 := 0;
  variable in_saturation : integer range 0 to 1:= 0;
  
  variable carrierphase : integer range 0 to 255 := 0;
  variable syncduration : integer range 0 to 127 := 0;
  variable hpos : integer range 0 to 511 := 0;
  variable vpos : integer range 0 to 511 := 0;

  variable out_pixelclock : std_logic := '0';
  variable out_colorclock : std_logic := '0';
  variable out_adccolclock : std_logic := '0';
  variable out_adclumclock : std_logic := '0';
  variable out_debugpulse : std_logic := '0';

	variable out_dvid_clk : std_logic := '0';
	variable out_dvid_sync : std_logic := '0';
	variable out_dvid_rgb : STD_LOGIC_VECTOR(11 downto 0) := "000000000000";
  
  	type T_registers is array (0 to 40) of integer range 0 to 255;
	variable registers : T_registers := (
			70, -- 39,    -- sync threashold
			162,   -- color signal zero line
			23,    -- saturation threashold
			72,255,126,184,136,159,111,208,135,111,158,125,151,209,153,186,     -- luminances for all colors
			106,159, 214,29, 75,170, 196,65, 34,217, 154,91,  -- even line and odd line phase for colors
			123,123, 131,99, 91,151, 198,48, 32,240
	);
	variable selectedregister : integer range 0 to 40 := 0;
	variable in_button : STD_LOGIC_VECTOR(3 downto 0) := "0000";
   variable prev_button : STD_LOGIC_VECTOR(3 downto 0) := "0000";
	variable tmp_vect8 : std_logic_vector(7 downto 0);
	variable odd : integer range 0 to 1;
	variable suppresscolorclock : std_logic := '0';
  begin
		if rising_edge(C64REFCLK) then
		  -- compute the phase of the color signal (do in seperate step for better pipelining)
		  if pixelclockphase=5 then
			in_colorphase := atan2(registers(1),in_colaux,in_col) - carrierphase;
			
			if sqr(distance(in_col,registers(1))) + sqr(distance(in_colaux,registers(1))) > sqr(registers(2)) then
				in_saturation := 1;
			else 
				in_saturation := 0;
			end if;
			
			-- overlay with reference colors
			if SWITCH(1 downto 0) /= "00" 
			 and vpos>=107 and vpos<=235 
			 and hpos>=64 and hpos<96 then
				odd := vpos mod 2;
				case (vpos-107) / 8 is 
				when  0 => in_lum := registers(3);  in_saturation:=0; in_colorphase:=0;
				when  1 => in_lum := registers(4);  in_saturation:=0; in_colorphase:=0;
				when  2 => in_lum := registers(5);  in_saturation:=1; in_colorphase:=registers(19+odd);
				when  3 => in_lum := registers(6);  in_saturation:=1; in_colorphase:=registers(21+odd);
				when  4 => in_lum := registers(7);  in_saturation:=1; in_colorphase:=registers(23+odd);
				when  5 => in_lum := registers(8);  in_saturation:=1; in_colorphase:=registers(25+odd);
				when  6 => in_lum := registers(9);  in_saturation:=1; in_colorphase:=registers(27+odd);
				when  7 => in_lum := registers(10); in_saturation:=1; in_colorphase:=registers(29+odd);
				when  8 => in_lum := registers(11); in_saturation:=1; in_colorphase:=registers(31+odd);
				when  9 => in_lum := registers(12); in_saturation:=1; in_colorphase:=registers(33+odd);
				when 10 => in_lum := registers(13); in_saturation:=1; in_colorphase:=registers(35+odd);
				when 11 => in_lum := registers(14); in_saturation:=0; in_colorphase:=0;
				when 12 => in_lum := registers(15); in_saturation:=0; in_colorphase:=0;
				when 13 => in_lum := registers(16); in_saturation:=1; in_colorphase:=registers(37+odd);
				when 14 => in_lum := registers(17); in_saturation:=1; in_colorphase:=registers(39+odd);
				when 15 => in_lum := registers(18); in_saturation:=0; in_colorphase:=0;
				when others => 
				end case;
			end if;
 	     end if;

		  
		   -- calculate the DVID signals and progress pixel counter
		  if pixelclockphase=6 then 
			out_dvid_clk := not out_dvid_clk;
			                           -- when entering here: (top line on screen has oddline=1)

			-- sense the phase of the carrier during color burst or just let it run free
			if hpos<15 then
				carrierphase := atan2(registers(1),in_colaux,in_col);
			else
				carrierphase := carrierphase + 128;
			end if;

			-- generate debug pulse
			if hpos=100 and ((SWITCH(2)='0' and vpos=107) or (SWITCH(2)='1' and vpos=108)) then
				out_debugpulse := '1';
			else
				out_debugpulse := '0';
			end if;
			
			-- detect sync and increment hpos and vpos counters
			if in_lum<registers(0) then   
				out_dvid_sync := '0';
				if hpos>100 then 
					vpos := vpos+1;
				end if;
				hpos := 0;
				if syncduration<127 then
					syncduration := syncduration+1;
				else
					vpos := 0;              
				end if;
			else
				out_dvid_sync := '1';
				if hpos<511 then hpos := hpos+1; end if;
				syncduration := 0;
			end if;
			
			-- create output color according to switch settings
			case SWITCH(1 downto 0) is 
			when "00" =>
				out_dvid_rgb := "0000" & std_logic_vector(to_unsigned(in_lum,8));
			when "01" =>
				out_dvid_rgb := "1110" & std_logic_vector(to_unsigned(in_lum,8));
			when "10" =>
				out_dvid_rgb := "1110" & std_logic_vector(to_unsigned(in_col,8));
			when "11" =>
--				out_dvid_rgb := "1110" & std_logic_vector(to_unsigned(in_col,8));
--				if in_saturation=1 then
--					out_dvid_rgb := "1110" & std_logic_vector(to_unsigned(in_colorphase,8));
--				else
--					out_dvid_rgb := "100010000000";
--				end if;
				out_dvid_rgb := "1110" & std_logic_vector(to_unsigned(in_colaux,8));
			end case;

		  end if;
		  
		  -- read next incomming digitized values at the right moment
		  if pixelclockphase=4 then
			in_lum := to_integer(unsigned(
				GPI(15 downto 15) & GPI(13) & GPI(11) & GPI(9) 
				& GPI(7) & GPI(5) & GPI(3) & GPI(1)));
	     end if;
		  if pixelclockphase=2 then
			in_colaux := to_integer(unsigned(
				GPI(14 downto 14) & GPI(12) & GPI(10) & GPI(8) 
				& GPI(6) & GPI(4) & GPI(2) & GPI(0)));  
		  end if;
		  if pixelclockphase=4 then
			in_col := to_integer(unsigned(
				GPI(14 downto 14) & GPI(12) & GPI(10) & GPI(8) 
				& GPI(6) & GPI(4) & GPI(2) & GPI(0))); 
		  end if;  
  
		-- generate the clock signals going into the VIC-II and the ADCs
			case pixelclockphase is
			when 0 => pixelclockphase:=1; out_adclumclock:='0'; out_adccolclock:='0'; out_pixelclock:='1'; out_colorclock:='0';
			when 1 => pixelclockphase:=2; out_adclumclock:='1'; out_adccolclock:='1'; out_pixelclock:='0'; out_colorclock:='0';
			when 2 => pixelclockphase:=3; out_adclumclock:='0'; out_adccolclock:='0'; out_pixelclock:='0'; out_colorclock:='1'; --
			when 3 => pixelclockphase:=4; out_adclumclock:='1'; out_adccolclock:='1'; out_pixelclock:='0'; out_colorclock:='1'; --
			when 4 => pixelclockphase:=5; out_adclumclock:='0'; out_adccolclock:='0'; out_pixelclock:='0'; out_colorclock:=suppresscolorclock;        
			when 5 => pixelclockphase:=6; out_adclumclock:='1'; out_adccolclock:='1'; out_pixelclock:='1'; out_colorclock:=suppresscolorclock; suppresscolorclock:='0';
			when 6 => pixelclockphase:=7; out_adclumclock:='0'; out_adccolclock:='0'; out_pixelclock:='1'; out_colorclock:='1';
			when 7 => pixelclockphase:=0; out_adclumclock:='1'; out_adccolclock:='1'; out_pixelclock:='1'; out_colorclock:='1'; 
			end case;
		end if;

		
		
		-- output variables as signals
		GPO(21) <= out_pixelclock;
		GPO(19) <= out_colorclock;
		GPO(17) <= out_adccolclock;
		GPO(16) <= out_adclumclock;
		GPO(20) <= out_debugpulse;
		GPO(18) <= '0';

		DVID_CLK  <= out_dvid_clk;
		DVID_SYNC <= out_dvid_sync;
		DVID_RGB  <= out_dvid_rgb;
		
		
		------- handle the register user interface ------
		if rising_edge(C64REFCLK) and pixelclockphase=0 then
			if in_button(3)='0' and prev_button(3)='1' and selectedregister>0 then
				selectedregister := selectedregister-1;
				suppresscolorclock := '1';
			end if;
			if in_button(2)='0' and prev_button(2)='1' and selectedregister<40 then
				selectedregister := selectedregister+1;
			end if;
			if in_button(1)='0' and prev_button(1)='1' then
				registers(selectedregister) := registers(selectedregister)-1;
			end if;
			if in_button(0)='0' and prev_button(0)='1' then
				registers(selectedregister) := registers(selectedregister)+1;
			end if;
			
			prev_button := in_button;
			in_button := BUTTON;
		end if;
		
		
		tmp_vect8 := std_logic_vector(to_unsigned(selectedregister,8));
		digit3 <= tmp_vect8(7 downto 4);
		digit2 <= tmp_vect8(3 downto 0);
		tmp_vect8 := std_logic_vector(to_unsigned(registers(selectedregister),8));
		digit1 <= tmp_vect8(7 downto 4);
		digit0 <= tmp_vect8(3 downto 0);
		
  end process; 


  
  
--	process (atan_zero, atan_x, atan_y) 
--	begin
--		atan_phi <= atan2(atan_zero,atan_x,atan_y);
--		atan_d2 <= 0;	
--	end process;
  
end immediate;

