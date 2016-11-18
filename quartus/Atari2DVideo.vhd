library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity Atari2DVideo is	
	port (
		CLK100: in std_logic;	
		SWITCH: in STD_LOGIC_VECTOR(9 downto 0);
		BUTTON: in STD_LOGIC_VECTOR(3 downto 0);
				
		-- Connections to GTIA pins
		ATARI_CLK    : in std_logic;
		ATARI_SYNC   : in std_logic;
		ATARI_LUM    : in std_logic_vector(3 downto 0);
		ATARI_COL    : in std_logic;
		ATARI_PAL    : out std_logic;
	
		-- Output to DVID interface ---
		DVID_CLK    : out std_logic;
		DVID_SYNC   : out std_logic;
		DVID_RGB    : out std_logic_vector(11 downto 0)
	);	
end entity;


architecture immediate of Atari2DVideo is
		
begin		

  
  process (CLK100) 

	type T_delay2phase is array(0 to 63) of integer range 0 to 15;
	constant evenlow2phase : T_delay2phase := (
    -- 1 on 18,  2 on 20, 3 on 24, 4 on 27, 5 on 31, 6 on 35, 7 on 38, 8 on 42
		0,0,0,0,0,0,0,0,0,0,           -- 0  - 9      
		1,1,1,1,1,1,1,1,1,1,           -- 10 - 19
		2,2,2,3,3,3,4,4,4,4,           -- 20 - 29
		5,5,5,5,6,6,6,7,7,7,           -- 30 - 39
		7,8,8,8,8,8,8,8,8,8,           -- 40 - 49
		8,8,8,8,8,8,8,8,8,8,8,8,8,8    -- 50 - 63
	);
	constant oddhigh2phase : T_delay2phase := (
	-- 1 on 21, 2 on 25, 3 on 29, 4 on 32, 5 on 36, 6 on 40, 7 on 43, 8 on 47 
		0,0,0,0,0,0,0,0,0,0,           -- 0  - 9      
		1,1,1,1,1,1,1,1,1,1,           -- 10 - 19
		1,1,1,2,2,2,2,3,3,3,           -- 20 - 29
		3,4,4,4,4,5,5,5,5,6,           -- 30 - 39
		6,6,7,7,7,7,8,8,8,8,           -- 40 - 49
		8,8,8,8,8,8,8,8,8,8,8,8,8,8    -- 50 - 63
	);
	constant evenhigh2phase : T_delay2phase := (
	-- 9 on 23, 10 on 25, 11 on 28, 12 on 35, 13 on 39, 14 on 42, 15 on 46  
		0,0,0,0,0,0,0,0,0,0,           -- 0  - 9      
		9,9,9,9,9,9,9,9,9,9,           -- 10 - 19
		9,9,9,9,10,10,10,11,11,11,        -- 20 - 29
		11,11,12,12,12,12,12,13,13,13, -- 30 - 39
		13,14,14,14,14,15,15,15,15,15, -- 40 - 49
		15,15,15,15,15,15,15,15,15,15,15,15,15,15  -- 50 - 63
	);
	constant oddlow2phase : T_delay2phase := (
	-- 9 on 20, 10 on 25, 11 on 28, 12 on 36, 13 on 39, 14 on 43, 15 on 47
		0,0,0,0,0,0,0,0,0,0,           -- 0  - 9      
		9,9,9,9,9,9,9,9,9,9,           -- 10 - 19
		9,9,9,10,10,10,10,11,11,11,    -- 20 - 29
		11,11,11,12,12,12,12,12,13,13, -- 30 - 39
		13,14,14,14,14,15,15,15,15,15, -- 40 - 49
		15,15,15,15,15,15,15,15,15,15,15,15,15,15  -- 50 - 63
	);
	
  	type T_phase2hue is array(0 to 16*2-1) of integer range 0 to 15;	
	constant phase2hue : T_phase2hue := (
	     0,  0,
		  0,  2,
		  11, 1,
		  12, 14,
		  13, 13,
		  14, 12,
        1,  11,		  
		  2,  0,
		  3,  10,
		  4,  9,
		  5,  8,
		  6,  7,
		  7,  6,
		  8,  5,
		  9,  4,
		  10, 3
 	);
  
  	type T_rgbtable is array (0 to 255) of integer range 0 to 4095;
   constant rgbtable : T_rgbtable := (
		16#000#,16#111#,16#222#,16#333#,16#444#,16#555#,16#666#,16#777#,16#888#,16#999#,16#aaa#,16#bbb#,16#ccc#,16#ddd#,16#eee#,16#fff#,
		16#310#,16#410#,16#520#,16#620#,16#730#,16#930#,16#a40#,16#b40#,16#c50#,16#d50#,16#f60#,16#f71#,16#f83#,16#f95#,16#fa7#,16#fb8#,
		16#300#,16#400#,16#500#,16#600#,16#700#,16#900#,16#a00#,16#b00#,16#c00#,16#d00#,16#f00#,16#f12#,16#f33#,16#f55#,16#f77#,16#f89#,
		16#301#,16#401#,16#502#,16#602#,16#703#,16#903#,16#a04#,16#b04#,16#c05#,16#d05#,16#f06#,16#f17#,16#f38#,16#f59#,16#f7a#,16#f8b#,
		16#302#,16#403#,16#504#,16#605#,16#706#,16#907#,16#a08#,16#b09#,16#c0a#,16#d0b#,16#f0c#,16#f1d#,16#f3d#,16#f5d#,16#f7d#,16#f8e#,
		16#203#,16#204#,16#305#,16#406#,16#507#,16#609#,16#70a#,16#70b#,16#80c#,16#90d#,16#a0f#,16#b1f#,16#b3f#,16#c5f#,16#c7f#,16#d8f#,
		16#003#,16#104#,16#105#,16#106#,16#207#,16#209#,16#20a#,16#30b#,16#30c#,16#30d#,16#40f#,16#51f#,16#63f#,16#85f#,16#97f#,16#a8f#,
		16#003#,16#004#,16#005#,16#006#,16#017#,16#019#,16#01a#,16#01b#,16#01c#,16#02d#,16#02f#,16#13f#,16#35f#,16#56f#,16#78f#,16#89f#,
		16#013#,16#024#,16#035#,16#036#,16#047#,16#059#,16#05a#,16#06b#,16#07c#,16#08d#,16#08f#,16#19f#,16#3af#,16#5bf#,16#7bf#,16#8cf#,
		16#032#,16#044#,16#055#,16#066#,16#077#,16#098#,16#0aa#,16#0bb#,16#0cc#,16#0dd#,16#0fe#,16#1fe#,16#3fe#,16#5fe#,16#7fe#,16#8fe#,
		16#031#,16#042#,16#053#,16#063#,16#074#,16#095#,16#0a5#,16#0b6#,16#0c7#,16#0d7#,16#0f8#,16#1f9#,16#3fa#,16#5fa#,16#7fb#,16#8fc#,
		16#030#,16#040#,16#050#,16#060#,16#071#,16#091#,16#0a1#,16#0b1#,16#0c1#,16#0d1#,16#0f1#,16#1f3#,16#3f5#,16#5f6#,16#7f8#,16#8f9#,
		16#030#,16#140#,16#150#,16#160#,16#270#,16#290#,16#3a0#,16#3b0#,16#3c0#,16#4d0#,16#4f0#,16#5f1#,16#7f3#,16#8f5#,16#9f7#,16#af8#,
		16#230#,16#340#,16#350#,16#460#,16#570#,16#690#,16#7a0#,16#8b0#,16#9c0#,16#9d0#,16#af0#,16#bf1#,16#bf3#,16#cf5#,16#cf7#,16#df8#,
		16#320#,16#430#,16#540#,16#650#,16#760#,16#970#,16#a80#,16#b90#,16#ca0#,16#db0#,16#fc0#,16#fd1#,16#fd3#,16#fd5#,16#fd7#,16#fe8#,
		16#310#,16#410#,16#520#,16#620#,16#730#,16#930#,16#a40#,16#b40#,16#c50#,16#d50#,16#f60#,16#f71#,16#f83#,16#f95#,16#fa7#,16#fb8#
	);


  variable prev_clock : std_logic;
  variable in_clock : std_logic;
  variable prev_col : std_logic;
  variable in_col : std_logic;
  
  variable timer : std_logic_vector(27 downto 0);
  variable phase : integer range 0 to 31;
--  variable horizontal : integer range 0 to 255;
--  variable isoddline : integer range 0 to 1;
  
--  variable sync : std_logic;
--  variable lum0 : integer range 0 to 15;
--  variable lum1 : integer range 0 to 15;
--  variable phase  : integer range 0 to 15;
--  variable hue    : integer range 0 to 15;

  variable out_clk : std_logic;
  variable out_sync : std_logic;
  variable out_lum : std_logic_vector(3 downto 0);
  variable out_phase : integer range 0 to 31;
  variable out_endcol : std_logic;
  variable out_pal : std_logic;
    
  begin
	if rising_edge(CLK100) then
	
		-- trigger various actions depending on the state of the timer
		-- (timer=0 is rising edge of atari pixel clock)
		
		if timer(3)='1' then
			if out_sync='0' then
				out_pal := '0';
			else
				out_pal := not out_pal;
			end if;
		end if;
		-- suitable time to let data be received 
		if timer(4)='1' then
			out_clk := '0';
		end if;
		-- sample the first lum and sync values and directly 
		-- expose on output
		if timer(12)='1' then
			out_lum := ATARI_LUM;
			out_sync := ATARI_SYNC;
		end if;
		-- suitable time to let data be received 
		if timer(20)='1' then
			out_clk := '1';
		end if;
		-- sample the second lum and directly expose on output 
		-- at the same time collect the sampled col signal
		if timer(26)='1' then
			out_lum := ATARI_LUM;
			out_endcol := in_col;
		end if;
		
		-- detect rising edge to inject new trigger into the timer
		timer := timer(26 downto 0) & '0';
		if in_clock='1' and prev_clock='0' then
			timer(0) := '1';
		end if;
		
		-- sample incomming clock and memorize previous state to detect edges
		prev_clock := in_clocK;
		in_clock := ATARI_CLK;
		
		prev_col := in_col;
		in_col := ATARI_COL;
		
	end if;
	

	-- async computations.  this will take longer that 10 ns, but the 
	-- timings on the DVID interface are much more relaxed.
	
	ATARI_PAL <= out_pal;
	
	DVID_CLK <= out_clk;	
	DVID_SYNC <= out_sync;
	DVID_RGB <= out_lum & out_lum 
	   & out_endcol & std_logic_vector(to_unsigned(out_phase,3));
  end process;

end immediate;

