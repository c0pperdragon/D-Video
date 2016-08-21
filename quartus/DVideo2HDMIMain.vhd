library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- running on board: Cyclone 5 GX Starter Kit 

entity DVideo2HDMIMain is	
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
		DVID_CLK   : in std_logic;
		DVID_SYNC  : in std_logic;
		DVID_DATA  : in STD_LOGIC_VECTOR(11 downto 0)
	);	
end entity;


architecture immediate of DVideo2HDMIMain is

   component PLL_90 is
	port (
		refclk   : in  std_logic; --  refclk.clk
		rst      : in  std_logic; --   reset.reset
		outclk_0 : out std_logic  -- outclk0.clk
	);
   end component;

   component PLL_500 is
	port (
		refclk   : in  std_logic; --  refclk.clk
		rst      : in  std_logic; --   reset.reset
		outclk_0 : out std_logic  -- outclk0.clk
	);
   end component;

	component VideoRAM is
   PORT
	(
		data		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (18 DOWNTO 0);
		rdclock		: IN STD_LOGIC ;
		wraddress		: IN STD_LOGIC_VECTOR (18 DOWNTO 0);
		wrclock		: IN STD_LOGIC  := '1';
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (11 DOWNTO 0)
	);
	end component;
	
	component SevenSegmentDriver is
	port (
		data:     in STD_LOGIC_VECTOR(3 downto 0);
		en:       in STD_LOGIC;
		q:       out STD_LOGIC_VECTOR (6 downto 0)
	);	
	end component;
	
	
	signal clkphasedetector: std_logic;  -- clock of maximum speed to detect the exact phase timings
	signal clkpixel : std_logic;         -- pixel clock to drive HDMI 

	signal framestart : std_logic;       -- signals the first part of an incomming video frame  
	
	signal ram_data: STD_LOGIC_VECTOR (11 DOWNTO 0);
	signal ram_rdaddress: STD_LOGIC_VECTOR (18 DOWNTO 0);
	signal ram_wraddress : STD_LOGIC_VECTOR (18 DOWNTO 0);
	signal ram_q : STD_LOGIC_VECTOR (11 DOWNTO 0);

	signal colorphase_r: STD_LOGIC_VECTOR(6 downto 0); -- rising edge after clock 
	signal colorphase_f: STD_LOGIC_VECTOR(6 downto 0); -- falling edge after clock 
	                                                 --   measured in 2ns from rising clock 
	signal digit0: STD_LOGIC_VECTOR(3 downto 0);
	signal digit1: STD_LOGIC_VECTOR(3 downto 0);
	signal digit2: STD_LOGIC_VECTOR(3 downto 0);
	signal digit3: STD_LOGIC_VECTOR(3 downto 0);

	
begin		
	phaseclockgenerator: PLL_500	port map (CLK50, not RST, clkphasedetector);
	pixelclockgenerator: PLL_90	port map (CLK50, not RST, clkpixel);
   videoram1 : VideoRAM port map(ram_data, 
	                              ram_rdaddress, clkpixel, 
	                              ram_wraddress, clkpixel, '1',
											ram_q);
   digitsdriver0: SevenSegmentDriver port map (digit0, '1', HEX0);
   digitsdriver1: SevenSegmentDriver port map (digit1, '1', HEX1);
   digitsdriver2: SevenSegmentDriver port map (digit2, '1', HEX2);
   digitsdriver3: SevenSegmentDriver port map (digit3, '1', HEX3);
	
			
			
	--------------- listen to color pin and determine its phase -----------
   process (clkphasedetector) 

	variable in_clk : std_logic;
	variable prev_clk : std_logic;
	variable in_col : std_logic;
	variable prev_col : std_logic;
	
   variable counter : integer range 0 to 127;  -- 2ns since rising clock
	
	variable trigger_samplestart : boolean;   -- pipelined trigger computation
	variable trigger_sampleend:    boolean;   -- pipelined trigger computation
	variable trigger_rising : boolean;   -- pipelined trigger computation
	variable trigger_falling : boolean;   -- pipelined trigger computation
	
		
	variable rising : integer range 0 to 127;
	variable falling : integer range 0 to 127;
	variable out_rising : integer range 0 to 127;
	variable out_falling : integer range 0 to 127;
	                                                --   measured in ns from rising clock  
		
	begin
		-- this is an extremely highly clocked circuit to take in the
		-- samples from 60ns to 240ns after the rising edge of the clock (180ns duration)
		-- everything is done in 2ns steps
	   if rising_edge(clkphasedetector) then

			-- respond to the triggers that were set in previous tick
			if trigger_sampleend then
				out_rising := rising;
				out_falling := falling;
			end if;
			if trigger_rising then
				rising := counter;
			end if;
			if trigger_falling then
				falling := counter;
			end if;
			
			-- set various trigger points
			trigger_rising    := (in_col='1' and prev_col='0') or trigger_samplestart;
			trigger_falling   := (in_col='0' and prev_col='1') or trigger_samplestart;
			trigger_samplestart := (counter=29);  -- trigger for the sample trigger
			trigger_sampleend := (counter=120);
			
			-- make the counter start from rising clock and then continue
			if in_clk='1' and prev_clk='0' then 
				counter := 0;
			else 
				counter := counter+1;
			end if;
				 			
			-- receive input signals for next cycle
			prev_clk := in_clk;
			in_clk := DVID_CLK;
			prev_col := in_col;
			in_col := DVID_DATA(6);
		end if;
			
		-- send output
		colorphase_r <= std_logic_vector(to_unsigned(out_rising, 7));
		colorphase_f <= std_logic_vector(to_unsigned(out_falling, 7));
	end process;
			
			
   ----------- read video signal and fill data in video ram --------------
	process (clkpixel)	

	type T_time2signal is array(0 to 127) of integer range 0 to 15;	
	constant rising2signal : T_time2signal := (
		 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 
       0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 
       4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  5,  5,  5,  5,  5,  5, 
       5,  5,  5,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  7, 
       7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  8,  8,  8,  8,  8, 
       8,  8,  8,  9,  9,  9,  9,  9,  9,  9,  9,  9, 10, 10, 10, 10, 
      10, 10, 10, 10, 10, 10, 11, 11, 11, 11, 11, 11, 11, 12, 12, 12, 
      12, 12, 12, 13, 13, 13, 13, 13, 13, 13, 13, 13, 14, 14, 14, 14
	);
	constant falling2signal : T_time2signal := (
       0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 
       0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 
      10, 10, 10, 10, 11, 11, 11, 11, 11, 11, 11, 11, 12, 12, 12, 12, 
      12, 12, 12, 12, 12, 13, 13, 13, 13, 13, 13, 13, 13, 14, 14, 14, 
      14, 14, 14, 14, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15,  1,  1, 
       1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  2,  2,  3,  3, 
       3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  4,  4,  4, 
       4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  5,  5,  5
	);
	type T_signal2hue is array(0 to 16*2-1) of integer range 0 to 15;	
	constant signal2hue : T_signal2hue := (
	     0,  0,
		 11,  1,
		  0,  2,
		 10,  3,
		  9,  4,
		  8,  5,
		  7,  6,
		  6,  7,
		  5,  8,
		  4,  9,
		  3, 10,
		  2,  0,
		  1, 11,
		 14, 12,
		 13, 13,
		 12, 14
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
	    
	
	variable synclength : integer range 0 to 2000 := 0;
	variable topoverscan : integer range 0 to 100 := 0;
	variable pixelvalue : unsigned(11 downto 0) := (others => '0');
	variable x : integer range 0 to 1023 := 0;
	variable y : integer range 0 to 287 := 0;
	variable calibration : integer range -64 to 63 := 0;
	
	variable in_dvid_clk  : std_logic;	
	variable in_dvid_sync : std_logic;
	variable in_dvid_data : STD_LOGIC_VECTOR(11 downto 0);
	variable prev_dvid_clk : std_logic;
	variable in_colorphase_r : integer range 0 to 127;
	variable in_colorphase_f : integer range 0 to 127;
	
	variable out_framestart : std_logic := '0';
	
	variable in_lum_0 : std_logic_vector(3 downto 0);
	variable in_lum_1 : std_logic_vector(3 downto 0);

	variable tmp_phaseoff_r : integer range 0 to 127;
	variable tmp_phaseoff_f : integer range 0 to 127;
	variable tmp_signal : integer range 0 to 15;
	variable tmp_hue : integer range 0 to 15;
	variable tmp_lum : integer range 0 to 15;
	variable tmp_led : std_logic_vector(17 downto 0);
	begin	
		if rising_edge(clkpixel) then

		
		  if RST='0' then
			   synclength := 0;
				topoverscan := 0;
				pixelvalue := (others => '0');
			   x := 0;
			   y := 0;
				
			-- process on every change of the dvideo clock
		  elsif in_dvid_clk /= prev_dvid_clk then
		  
			
		   if y=100 + to_integer(unsigned(SWITCH(1 downto 1))) 
			and x=to_integer(unsigned(SWITCH(9 downto 2))) then
				digit0 <= std_logic_vector(to_unsigned(in_colorphase_f mod 16,4));
				digit1 <= std_logic_vector(to_unsigned(in_colorphase_f / 16,4));
				digit2 <= std_logic_vector(to_unsigned(in_colorphase_r mod 16,4));
				digit3 <= std_logic_vector(to_unsigned(in_colorphase_r / 16,4));
				tmp_led := (others => '0');
				if BUTTON(0) = '1' then
				    tmp_led(in_colorphase_r mod 16) := '1';
			   else 
				    tmp_led(in_colorphase_f mod 16) := '1';
			   end if;
				LED <= tmp_led;
			end if;
							
			-- count length of sync
			if in_dvid_sync='0' then
			   synclength := synclength + 1;
	  			if x<1023 then
				   x := x+1;
				end if;
				
	         pixelvalue := (others => '0');
				
			-- detect end of sync (ignore small glitches)
         elsif synclength > 2 then
			   x := 0;
				
			   -- this was vsync
				if synclength > 100 then
				   y := 0;
				elsif y<287 then
				   y := y+1;
				end if;

				synclength := 0;
	         pixelvalue := (others => '0');
			-- normal image 
			else 
					
				synclength := 0;

				if in_colorphase_r=16#1f# and in_colorphase_f=16#1f# then
					tmp_signal := 0;
				elsif in_colorphase_f=16#1f# then 
					tmp_signal := rising2signal(in_colorphase_r); -- + calibration/8);
				elsif in_colorphase_r=16#1f# then
					tmp_signal := falling2signal(in_colorphase_f); -- + calibration/8);
				else
					if in_colorphase_r < 16#4c# then
						tmp_phaseoff_r := 16#4c# - in_colorphase_r;
					else
						tmp_phaseoff_r := in_colorphase_r - 16#4c#;
					end if;
					if in_colorphase_f < 16#4c# then
						tmp_phaseoff_f := 16#4c# - in_colorphase_f;
					else
						tmp_phaseoff_f := in_colorphase_f - 16#4c#;
					end if;
					if tmp_phaseoff_r < tmp_phaseoff_f then
						tmp_signal := rising2signal(in_colorphase_r); -- + calibration/8);
					else
						tmp_signal := falling2signal(in_colorphase_f); -- + calibration/8);
					end if;
				end if;
				
				
			   tmp_lum := to_integer(unsigned(in_lum_1));
				tmp_hue := signal2hue(tmp_signal*2 + (y mod 2));	
								
				pixelvalue := to_unsigned(rgbtable(tmp_hue*16+tmp_lum),12);


				-- delay the usage of the luminance to match it with the hue
				in_lum_1 := in_lum_0;
				in_lum_0 := in_dvid_data(3 downto 0);
			

				-- progress the horizontal counter
				if x<1023 then
				   x := x+1;
				end if;
					
			end if;

		  -- calibrate small temperature dependent deviation on the color burst
		  if (y mod 2)=1 then
			  if x=8 then 
   			  calibration := 16#4f# - in_colorphase_f;
			  elsif x>8 and x<16 then
   			  calibration := calibration + (16#4f# - in_colorphase_f);
           end if;			  
		  end if;

		  -- detect frame start and notify the HDMI signal generator
		  if y>=1 and y<10 then
   		  out_framestart := '1';
		  else
		     out_framestart := '0';
		  end if;
			
		 end if;  -- RST   
		
       -- read from dvid port to be processed in next iteration		
		 prev_dvid_clk := in_dvid_clk;
  	    in_dvid_clk := DVID_CLK;
		 in_dvid_sync := DVID_SYNC;
		 in_dvid_data := DVID_DATA;
		 
		 -- read color phase to be processed in next iteration
       in_colorphase_r := to_integer(unsigned(colorphase_r));
       in_colorphase_f := to_integer(unsigned(colorphase_f));
		 
		end if;   -- rising_edge

	
		framestart <= out_framestart;
		ram_wraddress <= std_logic_vector(to_unsigned(y*1024+x,19));
		ram_data 	<= std_logic_vector(pixelvalue);	
			
	end process;	
	
	
	-- create the hdmi video signals 
	process (clkpixel) 
	 -- timings for XSGA
	constant h_sync : integer := 112;
	constant h_bp : integer := 248;
	constant h_fp : integer := 48 + 32;
	constant h_total : integer := h_sync + h_bp + 1280 + h_fp;
	constant v_sync : integer := 3;
	constant v_bp : integer := 1;
	constant v_fp : integer := 38;
	constant v_total : integer := v_sync + v_bp + 1024 + v_fp;
	
	variable x : integer range 0 to h_total := 0; 
	variable y : integer range 0 to v_total := 0;
	
   variable out_hs : std_logic;
	variable out_vs : std_logic;
	variable out_rgb : unsigned (11 downto 0);
	variable out_de : std_logic;
	
	variable tmp_x : integer range 0 to h_total-1;
	variable tmp_y : integer range 0 to v_total-1;
	variable tmp_y_us : unsigned(7 downto 0);
	variable tmp_data : unsigned(7 downto 0);

	variable speedup : integer range 0 to 63 := 32;
	variable in_framestart : std_logic;
	variable prev_framestart : std_logic;
	
	begin
		if rising_edge(clkpixel) then		
		
         -- write output signals to registers 
			if y<v_sync then
				out_vs := '1';
			else 
			   out_vs := '0';
			end if;
			if x<h_sync then
				out_hs := '1';
			else 
			   out_hs := '0';
			end if;
   	
			
			tmp_x := x+3-(h_sync+h_bp);
			tmp_y := y-(v_sync+v_bp);				

			-- request video data for next pixel
		   ram_rdaddress <= std_logic_vector(to_unsigned((tmp_y/4+33)*1024+tmp_x/4+66,19));
				
			-- determine the color according to the sample info
			if y>=v_sync+v_bp and y<v_total-v_fp and
			   x>=h_sync+h_bp and x<h_total-h_fp then

				out_de := '1';
				out_rgb := unsigned(ram_q);
	
	         if SWITCH(0)='1' and (tmp_y mod 4) = 0 then
				   out_rgb(11 downto 8) := "0" & out_rgb(11 downto 9);
				   out_rgb(7 downto 4)  := "0" & out_rgb(7 downto 5);
				   out_rgb(3 downto 0)  := "0" & out_rgb(3 downto 1);
				end if;
	
			else
     		   out_de := '0';
			   out_rgb := (others=>'0');
			end if;
			
			
			-- continue with next pixel in next clock
			if RST='0' then
				x := 0;
				y := 0;
			 elsif x < (h_total-1) - speedup then
				x := x+1;
			 else 
				-- detect start of input frame and adjust speed to sync with it
				prev_framestart := in_framestart;
				in_framestart := framestart;
				if in_framestart='1' and prev_framestart='0' then
					if tmp_y>=932 then 
					   speedup := 0;	
               elsif tmp_y<=900-31 then
					   speedup := 63;
					elsif tmp_y<900 then
					   speedup := 32 + 900 - tmp_y;
					else 
					   speedup := 32 - (tmp_y - 900);
					end if;
				end if;
				
				-- switch to next line
			   x := 0;
				if y >= v_total-1 then
				   y := 0;
				else
				   y := y+1;
				end if;
				
			 end if;
			 
		end if;
		
      adv7511_hs <= out_hs; 
      adv7511_vs <= out_vs;
      adv7511_clk <= not clkpixel;
      adv7511_de <= out_de;
      adv7511_d <= std_logic_vector(out_rgb(11 downto 8)) 
		           & std_logic_vector(out_rgb(11 downto 8))
					  & std_logic_vector(out_rgb(7 downto 4))
					  & std_logic_vector(out_rgb(7 downto 4))
					  & std_logic_vector(out_rgb(3 downto 0))
					  & std_logic_vector(out_rgb(3 downto 0));
	end process;
	
	
	
	-- send initialization data to HDMI driver via a I2C interface
	process (CLK50)
	  constant initdelay:integer := 100;
	  -- data to be sent to the I2C slave
	  constant num:integer := 23;	  
	  type T_TRIPPLET is array (0 to 2) of integer range 0 to 255;
     type T_DATA is array(0 to num-1) of T_TRIPPLET;
     constant DATA : T_DATA := (
                    -- power registers
				(16#72#, 16#41#, 16#00#), -- power down inactive
				(16#72#, 16#D6#, 2#11000000#), -- HPD is always high
				
                    -- fixed registers
				(16#72#, 16#98#, 16#03#), 
				(16#72#, 16#9A#, 16#e0#), 
				(16#72#, 16#9C#, 16#30#),
				(16#72#, 16#9D#, 16#01#),
				(16#72#, 16#A2#, 16#A4#),
				(16#72#, 16#A3#, 16#A4#),
				(16#72#, 16#E0#, 16#D0#),
				(16#72#, 16#F9#, 16#00#),
				
				                 -- force to DVI mode
				(16#72#, 16#AF#, 16#00#),  

  				                 -- video input and output format
				(16#72#, 16#15#, 16#00#),        -- inputID = 1 (standard)
				                 -- 0x16[7]   = 0b0  .. Output format = 4x4x4
								     -- 0x16[5:4] = 0b11 .. color depth = 8 bit
									  -- 0x16[3:2] = 0x00 .. input style undefined
									  -- 0x16[1]   = 0b0  .. DDR input edge
									  -- 0x16[0]   = 0b0  .. output color space = RGB
				(16#72#, 16#16#, 16#30#),		
				
				                 -- various unused options - force to default
				(16#72#, 16#17#, 16#00#), 		
				(16#72#, 16#18#, 16#00#),  -- output color space converter disable 		
				(16#72#, 16#48#, 16#00#),
				(16#72#, 16#BA#, 16#60#),
				(16#72#, 16#D0#, 16#30#),
				(16#72#, 16#40#, 16#00#),
				(16#72#, 16#41#, 16#00#),
				(16#72#, 16#D5#, 16#00#),
				(16#72#, 16#FB#, 16#00#),
				(16#72#, 16#3B#, 16#00#)
	  );
	  -- divide down main clock to get slower state machine clock
	  constant clockdivider:integer := 2000;  	  
	  variable clockcounter: integer range 0 to clockdivider-1 := 0;

	  -- states of the machine
	  subtype t_state is integer range 0 to 11;
	  constant state_delay  : integer := 0;
	  constant state_idle   : integer := 1;
	  constant state_start0 : integer := 2;
	  constant state_start1 : integer := 3;
	  constant state_send0  : integer := 4;
	  constant state_send1  : integer := 5;
	  constant state_send2  : integer := 6;
	  constant state_ack0   : integer := 7;
	  constant state_ack1   : integer := 8;
	  constant state_ack2   : integer := 9;
	  constant state_stop0  : integer := 10;
	  constant state_stop1  : integer := 11;
	  variable state : t_state := state_delay;

	  variable delaycounter:integer range 0 to initdelay-1 := 0;
	  variable currentline: integer range 0 to num-1;
	  variable currentbyte: integer range 0 to 2 := 0; 
	  variable currentbit:  integer range 0 to 7 := 0;
	  
	  -- registers for the output signals
	  variable out_scl : std_logic := '1';
	  variable out_sda : std_logic := '1';

	  -- temporary
	  variable tmp8 : unsigned(7 downto 0);
	  variable tmptripplet : T_TRIPPLET;
	  
	  begin
		if rising_edge(CLK50) then
		
			-- process reset
			if RST='0' then
            state := state_delay;
				delaycounter := 0;
			
         -- divide input clock to get slower state machine clock
 		   elsif clockcounter+1<clockdivider then
		      clockcounter := clockcounter+1;

			else
			   clockcounter := 0;
				
				case state is
				when state_delay =>
					if delaycounter < initdelay-1 then
					   delaycounter := delaycounter+1;
				   else 
					   state := state_start0;
						currentline := 0;
					end if;
				when state_start0 =>
				   state := state_start1;
					currentbyte := 0;
					currentbit := 7;
				when state_start1 =>
				   state := state_send0;
				when state_send0 =>
				   state := state_send1;
				when state_send1 =>
				   if adv7511_scl/='0' then  -- continue when not stretching the clock
					   state := state_send2;
				   end if;
			   when state_send2 =>
				   if currentbit > 0 then
					   currentbit := currentbit -1;
						state := state_send0;
				   else 
					   state := state_ack0;
				   end if;
				when state_ack0 =>
			      state := state_ack1;
				when state_ack1 =>
				   if adv7511_scl/='0' then  -- continue when not stretching the clock
  	         state := state_ack2;
			   	end if;
				when state_ack2 =>
				   if currentbyte < 2 then
					   currentbyte := currentbyte + 1;
						currentbit := 7;
						state := state_send0;
					else 
					   state := state_stop0;
				   end if;
				when state_stop0 =>
				   state := state_stop1;
				when state_stop1 =>
				   if adv7511_scl/='0' then -- continue when not stretching the clock
					   state := state_idle;
				   end if;
    		   when state_idle =>
	            if currentline < num-1 then
					   currentline := currentline+1;
		            state := state_start0;
					end if;		
	       	end case;
	      end if;  -- clock divider

			-- compute output registers 
			if state=state_start0 or state=state_start1 
			or state=state_stop0 or state=state_stop1 then
			   out_sda := '0';
			elsif state=state_send0 or state=state_send1 or state=state_send2 then
			   tmptripplet := DATA(currentline);
				tmp8 := to_unsigned(tmptripplet(currentbyte),8);
            out_sda := tmp8(currentbit);
 			else 
			   out_sda := '1';
         end if;
			if state=state_delay or state=state_idle or state=state_start0
			or state=state_send1 or state=state_ack1 or state=state_stop1 then
			  out_scl := '1';
			else 
			  out_scl := '0';
			end if;
			
		end if;   -- clock	

	   -- set output signals according to registers
		if out_scl='0' then
		   adv7511_scl <= '0';
		else 
		   adv7511_scl <= 'Z';
	   end if;
		if out_sda='0' then
		   adv7511_sda <= '0';
		else 
		   adv7511_sda <= 'Z';
	   end if;	
	end process;
	
	
end immediate;


