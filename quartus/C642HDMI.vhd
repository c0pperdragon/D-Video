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
		GPIO0: in std_logic;
		GPIO1: in std_logic;
		GPIO2: in std_logic;
		GPIO3: in std_logic;
		GPIO4: in std_logic;
		GPIO5: in std_logic;
		GPIO6: in std_logic;
		GPIO7: in std_logic;
		GPIO8: out std_logic;
		GPIO9: out std_logic;
		GPIO10: out std_logic;
		GPIO11: out std_logic;
		GPIO12: out std_logic;
		GPIO13: out std_logic;
		GPIO14: in std_logic;
		GPIO15: in std_logic;
		GPIO16: in std_logic;
		GPIO17: in std_logic;
		GPIO18: in std_logic;
		GPIO19: in std_logic;
		GPIO20: in std_logic;
		GPIO21: in std_logic
	);	
end entity;


architecture immediate of C642HDMI is
	
	
	subtype int1 is integer range 0 to 1;
	subtype int2 is integer range 0 to 3;
	subtype int3 is integer range 0 to 7;
	subtype int08 is integer range 0 to 8;
	subtype int4 is integer range 0 to 15;
	subtype int8 is integer range 0 to 255;
	subtype int10 is integer range 0 to 1023;
	subtype int12 is integer range 0 to 4095;
  	type T_lumtable is array (0 to 8) of int8;
  	type T_coltable is array (0 to 15) of int8;

	function calculatelumindex(lum:int8; lumtable:t_lumtable) return int08 is
		type T_threasholds is array(0 to 7) of int8;
		variable threasholds : T_threasholds;
		variable tmp : integer range 0 to 511;
		begin
			for i in 0 to 7 loop
				tmp := lumtable(i);
				tmp := tmp + lumtable(i+1);
				tmp := tmp/2;
				threasholds(i) := tmp; 
			end loop;
			if lum<threasholds(7) then
				if lum<threasholds(3) then
					if lum<threasholds(1) then
						if lum<threasholds(0) then return 0; else return 1; end if;
					else
						if lum<threasholds(2) then return 2; else return 3; end if;
					end if;
				else
					if lum<threasholds(5) then
						if lum<threasholds(4) then return 4; else return 5; end if;
					else
						if lum<threasholds(6) then return 6; else return 7; end if;
					end if;
				end if;
			else 
				return 8;
			end if;
		end calculatelumindex;

		
	function distance(a:int8; b:int8) return int10 is
		begin
			if a<b then 
				return b-a;
			else
				return a-b;
			end if;
		end distance;
		
	function colordistance(col0:int8; col1:int8; ref0:int8; ref1:int8) return int10 is
		begin
			return distance(col0,ref0)*2 + distance(col1,ref1);
		end colordistance;
	
		
	function determinecolor2(col0:int8; col1:int8; 
		coltable0:T_coltable; coltable1:T_coltable; 
		test0:int4; test1:int4) return int4 is
		begin
			if colordistance(col0,col1,coltable0(test0),coltable1(test0)) 
		   <= colordistance(col0,col1,coltable0(test1),coltable1(test1)) then 
				return test0;
			else 
				return test1;
			end if;
		end determinecolor2;
		
	function determinecolor4(col0:int8; col1:int8; 
		coltable0:T_coltable; coltable1:T_coltable; 
		test0:int4; test1:int4; test2: int4; test3: int4) return int4 is
		variable d : int10;
		variable best : int4;
		variable bestdistance : int10;
		
		begin
			d := colordistance(col0,col1,coltable0(test0),coltable1(test0));
			best := test0;
			bestdistance := d;
			d := colordistance(col0,col1,coltable0(test1),coltable1(test1));
			if d<bestdistance then
				best := test1;
				bestdistance := d;
			end if;
			d := colordistance(col0,col1,coltable0(test2),coltable1(test2));
			if d<bestdistance then
				best := test2;
				bestdistance := d;
			end if;
			d := colordistance(col0,col1,coltable0(test3),coltable1(test3));
			if d<bestdistance then
				best := test3;
				bestdistance := d;
			end if;
			return best;
		end determinecolor4;

		
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
		DVID_HSYNC  : in std_logic;
		DVID_VSYNC  : in std_logic;
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

	

	signal C64REFCLK   : std_logic;  

	signal DVID_CLK    : std_logic;
	signal DVID_HSYNC  : std_logic;
	signal DVID_VSYNC  : std_logic;
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
		DVID_CLK, DVID_HSYNC, DVID_VSYNC, DVID_RGB );
	
   hex0driver : SevenSegmentDriver port map(digit0, '1', HEX0); 
   hex1driver : SevenSegmentDriver port map(digit1, '1', HEX1); 
   hex2driver : SevenSegmentDriver port map(digit2, '1', HEX2); 
   hex3driver : SevenSegmentDriver port map(digit3, '1', HEX3); 
	
  process (C64REFCLK) 
  
  
  variable pixelclockphase : integer range 0 to 7:= 0;
  
  variable in_lum0 : int8; -- last sample
  variable in_lum1 : int8; -- sample history 1
  variable in_lum2 : int8; -- sample history 2
  
  variable in_col0 : int8; -- last sample 
  variable in_col1 : int8; -- sample history 1
  variable in_col2 : int8; -- sample history 2

  variable lumindex : int08;
  variable paletteindex : int4;

  variable syncduration : integer range 0 to 127 := 0;
  variable hpos : integer range 0 to 511 := 0;
  variable vpos : integer range 0 to 511 := 0;

  variable out_pixelclock : std_logic := '0';
  variable out_colorclock : std_logic := '0';
  variable out_adccolclock : std_logic := '0';
  variable out_adclumclock : std_logic := '0';
  variable out_testpin : std_logic := '0';
  variable out_dvid_clk : std_logic := '0';
  variable out_dvid_hsync : std_logic := '0';
  variable out_dvid_vsync : std_logic := '0';
  variable out_dvid_rgb : STD_LOGIC_VECTOR(11 downto 0) := "000000000000";

  	type T_lumtables is array (0 to 7) of T_lumtable;
  	variable lumtables : T_lumtables := (
		(	0,0,0,0,0,0,0,0,0 ),
		(	0,0,0,0,0,0,0,0,0 ),
		(	0,0,0,0,0,0,0,0,0 ),
		(	0,0,0,0,0,0,0,0,0 ),
		(	0,0,0,0,0,0,0,0,0 ),
		(	0,0,0,0,0,0,0,0,0 ),
		(	0,0,0,0,0,0,0,0,0 ),
		(	0,0,0,0,0,0,0,0,0 )
	);
	type T_coltables is array (0 to 3) of T_coltable;
	variable coltables0 : T_coltables := (
		( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
		( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
		( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
		( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 )
	);
	variable coltables1 : T_coltables := (
		( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
		( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
		( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ),
		( 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 )
	);
	
  	type T_palette is array (0 to 15) of int12;
	constant palette : T_palette := (
		16#000#, 16#FFF#, 16#833#, 16#7CC#, 
		16#839#, 16#5A4#, 16#339#, 16#EE7#,
		16#953#, 16#530#, 16#C77#, 16#444#,
		16#777#, 16#AF9#, 16#66E#, 16#BBB#
	);
	
	type T_registers is array (0 to 15) of int8;
	variable registers : T_registers := (
			16#26#,    -- 0: sync threashold
			16#86#,    -- 1: color zero voltage
			16#07#,    -- 2: gray threadshold
			0,0,0,0,0, 
			0,0,0,0,0,0,0,0
	);
		
	
	variable in_button : STD_LOGIC_VECTOR(3 downto 0) := "0000";
   variable prev_button : STD_LOGIC_VECTOR(3 downto 0) := "0000";
	variable tmp_vect8 : std_logic_vector(7 downto 0);
	variable suppresscolorclock : std_logic := '0';
	
	variable tmpquadrant : integer range 0 to 3;
	variable tmpselected : integer range 0 to 15;
  begin
		if rising_edge(C64REFCLK) then
		
		  -- read next incomming digitized values at the right moment
			tmp_vect8(7) := GPIO15;
			tmp_vect8(6) := GPIO17;
			tmp_vect8(5) := GPIO19;
			tmp_vect8(4) := GPIO21;
			tmp_vect8(3) := GPIO20;
			tmp_vect8(2) := GPIO18;
			tmp_vect8(1) := GPIO16;
			tmp_vect8(0) := GPIO14;
		   if pixelclockphase=7 then
			   in_col2 := to_integer(unsigned(tmp_vect8));
		   end if;
		   if pixelclockphase=1 then
			   in_col1 := to_integer(unsigned(tmp_vect8));
		   end if;
		   if pixelclockphase=3 then
			   in_col0 := to_integer(unsigned(tmp_vect8));
 		   end if;  
			tmp_vect8(7) := GPIO6;
			tmp_vect8(6) := GPIO4;
			tmp_vect8(5) := GPIO2;
			tmp_vect8(4) := GPIO0;
			tmp_vect8(3) := GPIO1;
			tmp_vect8(2) := GPIO3;
			tmp_vect8(1) := GPIO5;
			tmp_vect8(0) := GPIO7;
		   if pixelclockphase=0 then			
			   in_lum2 := to_integer(unsigned(tmp_vect8));
	      end if;
		   if pixelclockphase=2 then			
			   in_lum1 := to_integer(unsigned(tmp_vect8));
	      end if;
		   if pixelclockphase=4 then			
			   in_lum0 := to_integer(unsigned(tmp_vect8));
	      end if;
		
			if pixelclockphase=5 then
				-- determine lum index according to column reference
				lumindex := calculatelumindex(in_lum0, lumtables(hpos mod 8));

			end if;
			
		  -- compute the proper palette index
		  if pixelclockphase=6 then
				tmpquadrant := (hpos mod 2) + 2 * (vpos mod 2);				

				case lumindex is 
				when 0 => paletteindex:=0;
				when 1 => 
					paletteindex:=determinecolor2(in_col0,in_col1,
					coltables0(tmpquadrant), coltables1(tmpquadrant), 6,9);
				when 2 => paletteindex:=determinecolor2(in_col0,in_col1,
					coltables0(tmpquadrant), coltables1(tmpquadrant), 11,2);
				when 3 => 
					paletteindex:=determinecolor2(in_col0,in_col1, 
				   coltables0(tmpquadrant), coltables1(tmpquadrant), 4,8);
				when 4 => 
					paletteindex:=determinecolor4(in_col0,in_col1, 
					coltables0(tmpquadrant), coltables1(tmpquadrant), 12,14, 5,10);
				when 5 =>
					paletteindex:=determinecolor4(in_col0,in_col1, 
					coltables0(tmpquadrant), coltables1(tmpquadrant), 12,14, 5,10);
				when 6 =>
					paletteindex:=determinecolor2(in_col0,in_col1, 
				   coltables0(tmpquadrant), coltables1(tmpquadrant), 15,3);
				when 7 => 
					paletteindex:=determinecolor2(in_col0,in_col1, 
					coltables0(tmpquadrant), coltables1(tmpquadrant), 7,13);
				when 8 => paletteindex:=1;
				end case;
		  end if;
		  
		  -- read in the calibration data (when buttons pressed)
		  if pixelclockphase=6 and (BUTTON(0)='0' or BUTTON(1)='0') then
				if vpos=109 and hpos>=94 and hpos<94+16*16 and ((hpos-94) mod 16) < 8 then
					case (hpos-94) / 16 is
					when 0  => lumtables(hpos mod 8)(0) := in_lum0;
					when 6  => lumtables(hpos mod 8)(1) := in_lum0;
					when 11 => lumtables(hpos mod 8)(2) := in_lum0;
					when 4  => lumtables(hpos mod 8)(3) := in_lum0;
					when 12 => lumtables(hpos mod 8)(4) := in_lum0;
					when 5  => lumtables(hpos mod 8)(5) := in_lum0;
					when 15 => lumtables(hpos mod 8)(6) := in_lum0;
					when 7  => lumtables(hpos mod 8)(7) := in_lum0;
					when 1  => lumtables(hpos mod 8)(8) := in_lum0;
					when others =>
					end case;			
					paletteindex := 0; -- mark sample points
				end if;
		  
				if vpos>=112 and vpos<114 and hpos>=94 and hpos<94+16*16  and ((hpos-94) mod 16) < 2 then
					tmpquadrant := (hpos mod 2) + 2 * (vpos mod 2);				
					coltables0(tmpquadrant)((hpos-94)/16) := in_col0;					
					coltables1(tmpquadrant)((hpos-94)/16) := in_col1;					
					paletteindex := 0; -- mark sample points
				end if;
			end if;	
		  
		   -- calculate the DVID signals
		  if pixelclockphase=7 then 
			if vpos=118 and hpos=94 then 
				out_testpin := '1';
			else
				out_testpin := '0';
			end if;
		  
			out_dvid_clk := not out_dvid_clk;
			if vpos<40 then
				out_dvid_vsync := '0';
			else
				out_dvid_vsync := '1';
			end if;
			if hpos<40 then
				out_dvid_hsync := '0';
			else
				out_dvid_hsync := '1';
			end if;
			
			-- create output color according to switch settings
			case SWITCH(2 downto 0) is 
			when "000" =>
				out_dvid_rgb := std_logic_vector(to_unsigned(palette(paletteindex),12));
			when "001" =>
				out_dvid_rgb := "1110" & std_logic_vector(to_unsigned(31*lumindex,8));
			when "010" =>
				out_dvid_rgb := "1110" & std_logic_vector(to_unsigned(in_lum0,8));
			when "011" =>
				out_dvid_rgb := "1110" & std_logic_vector(to_unsigned(in_col0,8));
--			when "100" =>
--				if isgray='1' then
--					out_dvid_rgb := "111011111111";
--				else 
--					out_dvid_rgb := "111000000000";
--				end if;
			when others=>
			end case;

			-- detect sync and increment hpos and vpos counters
			if in_lum2<registers(0) then   -- 0:sync threashold   
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
				if hpos<511 then hpos := hpos+1; end if;
				syncduration := 0;
			end if;
		  end if;
		    
		  -- generate the clock signals going into the VIC-II and the ADCs
			case pixelclockphase is
			when 0 => pixelclockphase:=1; out_adclumclock:='0'; out_adccolclock:='1'; out_pixelclock:='1'; out_colorclock:='0';
			when 1 => pixelclockphase:=2; out_adclumclock:='1'; out_adccolclock:='0'; out_pixelclock:='1'; out_colorclock:='1';
			when 2 => pixelclockphase:=3; out_adclumclock:='0'; out_adccolclock:='1'; out_pixelclock:='0'; out_colorclock:='1'; 
			when 3 => pixelclockphase:=4; out_adclumclock:='1'; out_adccolclock:='0'; out_pixelclock:='0'; out_colorclock:=suppresscolorclock; -- '1'; 
			when 4 => pixelclockphase:=5; out_adclumclock:='0'; out_adccolclock:='1'; out_pixelclock:='0'; out_colorclock:=suppresscolorclock; suppresscolorclock:='0';        
			when 5 => pixelclockphase:=6; out_adclumclock:='1'; out_adccolclock:='0'; out_pixelclock:='0'; out_colorclock:='1';
			when 6 => pixelclockphase:=7; out_adclumclock:='0'; out_adccolclock:='1'; out_pixelclock:='1'; out_colorclock:='1';
			when 7 => pixelclockphase:=0; out_adclumclock:='1'; out_adccolclock:='0'; out_pixelclock:='1'; out_colorclock:='0'; 
			end case;
		end if;

		
		-- output variables as signals
		GPIO8  <= out_testpin;
		GPIO9  <= out_colorclock;
		GPIO10 <= out_adclumclock;
		GPIO11 <= out_pixelclock;
		GPIO12 <= out_adccolclock;
		GPIO13 <= '0';

		DVID_CLK  <= out_dvid_clk;
		DVID_HSYNC <= out_dvid_hsync;
		DVID_vSYNC <= out_dvid_vsync;
		DVID_RGB  <= out_dvid_rgb;
		
		
		------- handle the register user interface ------
		tmpselected := to_integer(unsigned(SWITCH(9 downto 6)));
		if rising_edge(C64REFCLK) and pixelclockphase=0 then
			if in_button(3)='0' and prev_button(3)='1' then
				registers(tmpselected) := registers(tmpselected)+1;
			end if;
			if in_button(2)='0' and prev_button(2)='1' then
				registers(tmpselected) := registers(tmpselected)-1;
			end if;

--			if in_button(3)='0' and prev_button(3)='1' and selectedregister>0 then
--				selectedregister := selectedregister-1;
--			end if;
			if in_button(0)='0' and prev_button(0)='1' then
				suppresscolorclock := '1';
			end if;
			
			prev_button := in_button;
			in_button := BUTTON;
		end if;
		
		
		tmp_vect8 := std_logic_vector(to_unsigned(tmpselected,8));
		digit3 <= tmp_vect8(7 downto 4);
		digit2 <= tmp_vect8(3 downto 0);
		
		tmp_vect8 := std_logic_vector(to_unsigned(registers(tmpselected), 8));
		digit1 <= tmp_vect8(7 downto 4);
		digit0 <= tmp_vect8(3 downto 0);
		
  end process; 


  
  
--	process (atan_zero, atan_x, atan_y) 
--	begin
--		atan_phi <= atan2(atan_zero,atan_x,atan_y);
--		atan_d2 <= 0;	
--	end process;
  
end immediate;

