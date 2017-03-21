library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- running on D-Video board 

entity DVideo2HDMI is	
	port (
	   -- default clocking and reset
		CLK50: in std_logic;	
      RST: in std_logic;
		
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
end entity;


architecture immediate of DVideo2HDMI is

   component PLL_119_5 is
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
   end component;


	component VideoRAM is
   PORT
	(
		data		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (14 DOWNTO 0);
		rdclock		: IN STD_LOGIC ;
		wraddress		: IN STD_LOGIC_VECTOR (14 DOWNTO 0);
		wrclock		: IN STD_LOGIC  := '1';
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (11 DOWNTO 0)
	);
	end component;
	                    -- incomming data (already aligned with CLK50)	
	signal in_available : std_logic;
	signal in_rgb : std_logic_vector(11 downto 0);
	signal in_hsync : std_logic;
	signal in_vsync : std_logic;
	
	signal clkpixel : std_logic;         -- pixel clock to drive HDMI 
	signal framestart : std_logic;       -- signals the first part of an incomming video frame  
	
	signal ram_data: STD_LOGIC_VECTOR (11 DOWNTO 0);
	signal ram_rdaddress: STD_LOGIC_VECTOR (14 DOWNTO 0);
	signal ram_wraddress : STD_LOGIC_VECTOR (14 DOWNTO 0);
	signal ram_wren : STD_LOGIC;
	signal ram_q : STD_LOGIC_VECTOR (11 DOWNTO 0);
	
begin		
	pixelclockgenerator: PLL_119_5	port map (not RST, CLK50, clkpixel);
   videoram1 : VideoRAM port map(ram_data, 
	                              ram_rdaddress, clkpixel, 
	                              ram_wraddress, CLK50, ram_wren,
											ram_q);
	
  -- clock in the DVID data on every edge 
  -- delay signals to get a zero-hold time trigger on DVID_CLK 

  process (CLK50) 
  variable a0 : std_logic_vector(14 downto 0) := "000000000000000";
  variable b0 : std_logic_vector(14 downto 0) := "000000000000000";
  variable a1 : std_logic_vector(14 downto 0) := "000000000000000";
  variable b1 : std_logic_vector(14 downto 0) := "000000000000000";
  variable a2 : std_logic_vector(14 downto 0) := "000000000000000";
  variable b2 : std_logic_vector(14 downto 0) := "000000000000000";
  variable a3 : std_logic_vector(14 downto 0) := "000000000000000";
  variable b3 : std_logic_vector(14 downto 0) := "000000000000000";
  variable level : std_logic := '0';
  
  variable data : std_logic_vector(13 downto 0) := "00000000000000";
  variable available : std_logic := '0';
  begin
		-- only on rising edge, check what DVID_CLK edge has happened
		if rising_edge(CLK50) then
			if a2(14)=b1(14) and b1(14)/=level then
				level := b1(14);
				data := b3(13 downto 0);
				available := '1';
			elsif a1(14)=b1(14) and b1(14)/=level then
				level := b1(14);
				data := a3(13 downto 0);
				available := '1';
			else
				available := '0';
			end if;
		end if;
  
		-- pipe next data in with 100MHz sample rate
		if rising_edge(CLK50) then
			b3 := b2;
			b2 := b1;
			b1 := b0;
			a3 := a2;
			a2 := a1;
			a1 := a0;
			a0 := DVID_CLK & DVID_HSYNC & DVID_VSYNC & DVID_RGB;			
		end if;		
	   if falling_edge(CLK50) then
			b0 := DVID_CLK & DVID_HSYNC & DVID_VSYNC & DVID_RGB;
      end if;

		in_available <= available;
		in_hsync <= data(13);
		in_vsync <= data(12);
		in_rgb <= data(11 downto 0);
  end process; 
			
			
  ------------------- process the pixel stream ------------------------
  process (CLK50)	    
	
	variable pixelvalue : unsigned(11 downto 0) := "000000000000";
	variable x : integer range 0 to 1023 := 0;
	variable y : integer range 0 to 511 := 0;
		
	variable out_framestart : std_logic := '0';
	
	begin	
		if rising_edge(CLK50) then
		
		  if RST='0' then
				pixelvalue := (others => '0');
			   x := 0;
			   y := 0;
				
		  -- process whenever there is new incomming data  
		  elsif in_available='1' then
		  										
			-- sync signals reset the counter
			if in_vsync='0' then 
				
				y:= 0;
				x:= 0;
	         pixelvalue := (others => '0');
				
			elsif in_hsync='0' then
				if x>0 then 
					y := y+1;
				end if;
				x:=0;
	         pixelvalue := (others => '0');				

			-- progress the horizontal counter
			else 			
				if x<1023 then
				   x := x+1;
				end if;
            pixelvalue := unsigned(in_rgb);
					
			end if;

		  -- detect frame start and notify the HDMI signal generator
		  if y=10 then
   		  out_framestart := '1';
		  else
		     out_framestart := '0';
		  end if;
			
		 end if;  -- RST, processing data				 
		end if;   
		
	
		framestart <= out_framestart;
		
		ram_data <= std_logic_vector(pixelvalue);	
		ram_wren <= '1';
		ram_wraddress <= std_logic_vector(to_unsigned(y,6)) 
		               & std_logic_vector(to_unsigned(x,9));
	end process;	
	
	
	------------------- create the output hdmi video signals ----------------------
	process (clkpixel) 
	 -- timings for XSGA
	constant h_sync : integer := 176;
	constant h_bp : integer := 264;
	constant h_fp : integer := 88 + 32;   
	constant h_total : integer := h_sync + h_bp + 1680 + h_fp;
	constant v_sync : integer := 6;
	constant v_bp : integer := 24;
	constant v_fp : integer := 3;
	constant v_total : integer := v_sync + v_bp + 1050 + v_fp;
	
	variable x : integer range 0 to h_total := 0; 
	variable y : integer range 0 to v_total := 0;
	
	variable out_clk : std_logic := '0';
   variable out_hs : std_logic := '0';
	variable out_vs : std_logic := '0';
	variable out_rgb : std_logic_vector (23 downto 0) := "000000000000000000000000";
	variable out_de : std_logic := '0';
	
	variable speedup : integer range 0 to 63 := 32;
	variable in_framestart : std_logic := '0';
	variable prev_framestart : std_logic := '0';

	variable tmp_x : integer range 0 to h_total-1;
	variable tmp_y : integer range 0 to v_total-1;
	variable tmp_y_us : unsigned(7 downto 0);
	variable tmp_data : unsigned(7 downto 0);
	
	begin
		if rising_edge(clkpixel) then		
		
         -- write output signals to registers 
			out_clk := not out_clk;   -- using double data rate
			if y<v_sync then
				out_vs := '1';
			else 
			   out_vs := '0';
			end if;
			if x<h_sync then
				out_hs := '0';
			else 
			   out_hs := '1';
			end if;
   	
			
			tmp_x := x-(h_sync+h_bp);
			tmp_y := y-(v_sync+v_bp);				

			-- request video data for next pixel
		   ram_rdaddress <= std_logic_vector(to_unsigned(tmp_y/4,6))
			               & std_logic_vector(to_unsigned(tmp_x/4,9));

				
			-- determine the color according to the sample info
			if y>=v_sync+v_bp and y<v_total-v_fp and
			   x>=h_sync+h_bp and x<h_total-h_fp then

				out_de := '1';

--				if SWITCH(3 downto 0)="0000" then
					out_rgb := ram_q(11 downto 8) 
					         & ram_q(11 downto 8)
								& ram_q(7 downto 4)
								& ram_q(7 downto 4)
								& ram_q(3 downto 0)
								& ram_q(3 downto 0);
--				else
--					out_rgb := "000000000000000000000000";
--					if ram_q(11)='1' then
--						out_rgb(23 downto 16) := ram_q(7 downto 0);
--					end if;
--					if ram_q(10)='1' then
--						out_rgb(15 downto 8) := ram_q(7 downto 0);
--					end if;
--					if ram_q(9)='1' then
--						out_rgb(7 downto 0) := ram_q(7 downto 0);
--					end if;
--				end if;

			else
     		   out_de := '0';
			   out_rgb := (others=>'0');
			end if;
			
			-- detect start of input frame and adjust speed to sync with it
			if in_framestart='1' and prev_framestart='0' then
				if y>=v_sync+v_bp+31 then 
				   speedup := 0;	
            elsif y<=v_sync+v_bp-31 then
				   speedup := 63;
				elsif y < v_sync+v_bp then
				   speedup := 32 + (v_sync+v_bp - y);
				else 
				   speedup := 32 - (y - (v_sync+v_bp));
				end if;
			end if;			
			prev_framestart := in_framestart;
			in_framestart := framestart;
			
			-- continue with next pixel in next clock
			if RST='0' then
				x := 0;
				y := 0;
			 elsif x < (h_total-1) - speedup then
				x := x+1;
			 else 				
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
      adv7511_clk <= out_clk; 
      adv7511_de <= out_de;
		adv7511_d <= out_rgb;
							  
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
	  variable currentline: integer range 0 to num-1 := 0;
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


