library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- running on board: Cyclone 5 GX Starter Kit 

entity SevenSegmentDriver is	
	port (
		data:     in STD_LOGIC_VECTOR(3 downto 0);
		en:       in STD_LOGIC;
		segments: out STD_LOGIC_VECTOR (6 downto 0)
	);	
end entity;


architecture immediate of SevenSegmentDriver is
begin		
	process (data,en)		
	begin	
	   if en='0' then
		   data <= "0000000";
		else
		
		
		
		end if;
		if rising_edge(clkpixel) then
		
		  if RST='0' then
			   synclength := 0;
				topoverscan := 0;
				pixelvalue := (others => '0');
			   x := 0;
			   y := 0;
			   xp := 0;
				
			-- process on every change of the dvideo clock
		  elsif in_dvid_clk /= prev_dvid_clk then
			
			if x<0 then
			   xp := 0;
			elsif x>=1024 then
		      xp := 1013;
			else 
			   xp := x;
			end if;
							
			-- count length of sync
			if in_dvid_sync='0' then
			   synclength := synclength + 1;
	  			if x<4093 then
				   x := x+1;
				end if;
				
	         pixelvalue := (others => '0');
				
			-- detect end of sync (ignore small glitches)
         elsif synclength > 2 then
			   x := 0;
				
			   -- this was vsync
				if synclength > 100 then
				   y := 0;
					topoverscan := 0;
				elsif topoverscan<33 then
				   topoverscan := topoverscan+1;
				elsif y<255 then
				   y := y+1;
				end if;

				synclength := 0;
	         pixelvalue := (others => '0');
			-- normal image 
			else 
				if x<4093 then
				   x := x+1;
				end if;
					
				synclength := 0;
								
				pixelvalue := unsigned(in_dvid_data(3 downto 0)) 
				            & unsigned(in_dvid_data(3 downto 0))
								& unsigned(in_dvid_data(3 downto 0));
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

		end if;   -- rising_edge
		
		framestart <= out_framestart;
		
		ram_wraddress <= std_logic_vector(to_unsigned(y*1024+xp,18));
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
		   ram_rdaddress <= std_logic_vector(to_unsigned((tmp_y/4)*1024+tmp_x/4+63,18));
				
			-- determine the color according to the sample info
			if y>=v_sync+v_bp and y<v_total-v_fp and
			   x>=h_sync+h_bp and x<h_total-h_fp then

				out_de := '1';
				out_rgb := unsigned(ram_q);
	
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


