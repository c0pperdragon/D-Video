library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement a PAL upscaler for a 288p video signal to 1680x1050 HDMI.
-- All lines are quadrupled, and the horizontal sync slip between input and output is
-- compensated by adding/removing pixels from the end of each output line (my monitor can handle that).
-- To match the vertical resolution also, the output will append as much additional blanking
-- lines as necessary.
--
-- To keep a reasonable aspect ratio when quadrupling the output lines, the input signal must 
-- be sampled with about 30 Mhz. 
-- As there is only a single PLL, the output pixel clock must be some possible multiple of this, which
-- for simplicity can just be 120.
-- 
-- PAL line frequency: 15625 Hz -> 1920 samples per line total, 312 lines per frame (50.08 Hz)

-- HDMI geometry     TOTAL   SYNC   BP  VISIBLE   FP
--    horizontal:    1920    44     64     1680  132
--    vertical:      1248    8      64     1050  126

entity Upscaler1680x1050 is	
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
		
		-- ADC interface
		R : in std_logic_vector(7 downto 0);   --  Y in YPbPr mode
		G : in std_logic_vector(7 downto 0);   -- Pb in YPbPr mode
		B : in std_logic_vector(7 downto 0);   -- Pr in YPbPr mode
		ENCODE : out std_logic;
		
		-- CSYNC signal (not through ADCs)
		CSYNC : in std_logic;

		-- for testing
		DEBUG: out std_logic
	);	
end entity;


architecture immediate of Upscaler1680x1050 is

component PLL120x4 is
PORT
	(
		inclk0: IN STD_LOGIC;
		c0		: OUT STD_LOGIC ;
		c1		: OUT STD_LOGIC ;
		c2		: OUT STD_LOGIC ;
		c3		: OUT STD_LOGIC 
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
	
component ram_dual is
	generic
	(
		data_width : integer := 8;
		addr_width : integer := 16
	); 
	port 
	(
		data	: in std_logic_vector(data_width-1 downto 0);
		raddr	: in std_logic_vector(addr_width-1 downto 0);
		waddr	: in std_logic_vector(addr_width-1 downto 0);
		we		: in std_logic := '1';
		rclk	: in std_logic;
		wclk	: in std_logic;
		q		: out std_logic_vector(data_width-1 downto 0)
	);	
end component;
	
	
-- 4 phase shifted clocks running at 120Mhz. 
-- when using both edges, the 120 mhz can be sliced to 8 parts.
signal CLOCK0 : std_logic;    -- 120 MHz
signal CLOCK1 : std_logic;    -- 120 MHz, 1.04 ns late
signal CLOCK2 : std_logic;    -- 120 MHz, 2.08 ns late
signal CLOCK3 : std_logic;    -- 120 MHz, 3,12 ns late

signal SYNCHISTORY : std_logic_vector(7 downto 0); -- higher index means later sample time
signal SAMPLETRIGGER : std_logic;
signal SAMPLEDELAY : integer range 0 to 7;

signal QUARTERLINEBEGIN : boolean;
signal FIRSTLINEBEGIN : boolean;
signal VERTICALSHIFT : integer range 0 to 1;

signal bufferwraddress : integer range 0 to 8191;
signal bufferwrdata : std_logic_vector(23 downto 0);
signal bufferrdaddress : integer range 0 to 8191;
signal bufferq : std_logic_vector(23 downto 0);
		
begin		
	pixelclockgenerator: PLL120x4 port map ( CLK50, CLOCK0, CLOCK1, CLOCK2, CLOCK3 );
	
	configurator: ConfigureADV7513 port map 
		( CLK50, adv7513_scl, adv7513_sda, open);

	linebuffer : ram_dual generic map(data_width => 24, addr_width => 13)
		port map (
			bufferwrdata,
			std_logic_vector(to_unsigned(bufferrdaddress,13)),
			std_logic_vector(to_unsigned(bufferwraddress,13)),
			'1',
			CLOCK0,
			CLOCK0,
			bufferq		
		);
	
	
	-- Sample the CSYNC signal at different points and produce a 
	-- history vector. This output is synchronized with the main clock (CLOCK0)
	process (CLOCK0,CLOCK1,CLOCK2,CLOCK3)
		variable a : std_logic_vector(7 downto 0); -- to take the sample at 8 different times
		variable b : std_logic_vector(7 downto 0); -- to collect for use at a required output time
	begin
		if rising_edge(CLOCK0) then 
			SYNCHISTORY <= b; 
			b(3 downto 0) := a(3 downto 0);
			a(0) := CSYNC;
		end if;
		if rising_edge(CLOCK1) then 
			a(1) := CSYNC; 
		end if;
		if rising_edge(CLOCK2) then 
			a(2) := CSYNC; 
		end if;
		if rising_edge(CLOCK3) then 
			a(3) := CSYNC; 
		end if;
		if falling_edge(CLOCK0) then 
			b(7 downto 4) := a(7 downto 4);
			a(4) := CSYNC; 
		end if;
		if falling_edge(CLOCK1) then 
			a(5) := CSYNC; 
		end if;
		if falling_edge(CLOCK2) then 
			a(6) := CSYNC; 
		end if;
		if falling_edge(CLOCK3) then 
			a(7) := CSYNC; 
		end if;			
	end process;
	
	-- produce an ENCODE output that is a variably delayed copy of 
	-- SAMPLETRIGGER (which is synchronious to CLOCK0)
	process (CLOCK0, CLOCK1, CLOCK2, CLOCK3, SAMPLETRIGGER)
		variable a : std_logic_vector(7 downto 0); -- prepare individual bits for the delay output
		variable b : std_logic_vector(7 downto 0); -- keep data longer if needed 	
		variable x : std_logic_vector(7 downto 0); -- delayed flip-flops when are then combined asynchronously
	begin
		-- take prepared data into the flip-flops at the correct time
		if falling_edge(CLOCK0) then
			x(0) := a(0); 
			b := a;
		end if;
		if falling_edge(CLOCK1) then 
			x(1) := a(1); 
		end if;
		if falling_edge(CLOCK2) then 
			x(2) := a(2); 
		end if;
		if falling_edge(CLOCK3) then 
			x(3) := a(3); 
		end if;			
		if rising_edge(CLOCK0) then 
			x(4) := b(4); 
			a := "00000000";
			a(SAMPLEDELAY) := SAMPLETRIGGER;
		end if;
		if rising_edge(CLOCK1) then 
			x(5) := b(5); 
		end if;
		if rising_edge(CLOCK2) then 
			x(6) := b(6); 
		end if;
		if rising_edge(CLOCK3) then 
			x(7) := b(7);  
		end if;
			
		-- combine staggered signals
		ENCODE <= x(0) or x(1) or x(2) or x(3) or x(4) or x(5) or x(6) or x(7);	
	end process;
	
	------ input sampling ---
	process (CLOCK0)
		variable prev_csync : std_logic_vector(15 downto 0);
		variable in_y : integer range 0 to 255;
		variable in_pr : integer range 0 to 255;
		variable in_pb : integer range 0 to 255;

		variable triggercounter : integer range 0 to 3;
		variable x4 : integer range 0 to 8191;
		variable y : integer range 0 to 511;
		variable prevx4 : integer range 0 to 8191;
		variable synclowtime : integer range 0 to 8191;
		variable shiftedframe : boolean;
		
		variable scaled_r : integer range 0 to 255;
		variable scaled_g : integer range 0 to 255;
		variable scaled_b : integer range 0 to 255;
		
		variable tmp_r : integer range -512 to 511;
		variable tmp_g : integer range -512 to 511;
		variable tmp_b : integer range -512 to 511;
		
		variable yzero : integer range 0 to 255 := 151;    -- zero level for y signal
		variable pbzero : integer range 0 to 255 := 151;   -- zero level for pb signal
		variable przero : integer range 0 to 255 := 156;   -- zero level for pr signal		
		variable ysummer  : integer range 0 to 256*64-1;
		variable pbsummer : integer range 0 to 256*64-1;
		variable prsummer : integer range 0 to 256*64-1;
		
		constant rgbzero: integer := 15;		
	begin
		if rising_edge(CLOCK0) then
			-- take sample at correct phase and adjust colors
			-- this will only work correctly when there was only one normal sync pulse in the line
			-- for lines with vsync or short syncs, this timing will be off for the second half
			-- of the line, but as there is no image there anyway, it will not matter
			if x4 mod 4 = 0 then
				-- do clipping and and additional scaling of rgb channels
				if tmp_r<0 then scaled_r:=0; 
				elsif tmp_r>144 then scaled_r:=255;
				else scaled_r := tmp_r + tmp_r/2 + tmp_r/4;
				end if;
				if tmp_g<0 then scaled_g:=0; 
				elsif tmp_g>144 then scaled_g:=255;
				else scaled_g := tmp_g + tmp_g/2 + tmp_g/4;
				end if;
				if tmp_b<0 then scaled_b:=0; 
				elsif tmp_b>144 then scaled_b:=255;
				else scaled_b := tmp_b + tmp_b/2 + tmp_b/4;
				end if;
				
				-- do pipelined YPbPr computation
				tmp_r := in_y;
				tmp_r := tmp_r - yzero; 
				tmp_r := tmp_r + in_pr;
				tmp_r := tmp_r - przero;
				tmp_g := in_y;
				tmp_g := tmp_g - yzero;
				tmp_g := tmp_g ; -- - (in_pb*13/128); 
				tmp_g := tmp_g ; -- + (pbzero*13/128); 
				tmp_g := tmp_g ; -- - (in_pr*50/128);  -- 38
				tmp_g := tmp_g ; -- + (przero*50/128); -- 38
				tmp_b := in_y;
				tmp_b := tmp_b - yzero;
				tmp_b := tmp_b + in_pb;
				tmp_b := tmp_b - pbzero;
				
				if x4/4 = 250 then
					ysummer  := in_y;
					pbsummer := in_pb;
					prsummer := in_pr;
				elsif x4/4 = 250+64 then
					yzero  := 75; -- ysummer / 64;
					pbzero := pbsummer / 64;
					przero := prsummer / 64;
				else
					ysummer  := ysummer  + in_y;
					pbsummer := pbsummer + in_pb;
					prsummer := prsummer + in_pr;
				end if;				
				
				-- for RGB mode, do use RGB values linearly
				tmp_r := in_y;	 tmp_r := tmp_r - rgbzero;
				tmp_g := in_pb; tmp_g := tmp_g - rgbzero;				
				tmp_b := in_pr; tmp_b := tmp_b - rgbzero;
			end if;
			
			-- generate the sync pulses to lock the HDMI output to the input
--			QUARTERLINEBEGIN <= x4=0 or x4=prevx4/4 or x4=prevx4/2 or x4=prevx4/2+prevx4/4;			
			FIRSTLINEBEGIN <= (y=14) and (x4<2400);

			-- adjust sample delay and trigger to fit the sync edge as closely as possible
			if SYNCHISTORY(7)='0' and prev_csync(0)='1' then
				if SYNCHISTORY(6)='1' then SAMPLEDELAY <= 7; 
				elsif SYNCHISTORY(5)='1' then SAMPLEDELAY <= 6;
				elsif SYNCHISTORY(4)='1' then SAMPLEDELAY <= 5;
				elsif SYNCHISTORY(3)='1' then SAMPLEDELAY <= 4;
				elsif SYNCHISTORY(2)='1' then SAMPLEDELAY <= 3;
				elsif SYNCHISTORY(1)='1' then SAMPLEDELAY <= 2;
				elsif SYNCHISTORY(0)='1' then SAMPLEDELAY <= 1;
				else SAMPLEDELAY <= 0; end if;				
				triggercounter := 0;
			elsif triggercounter = 0 then
				triggercounter := 1;
				SAMPLETRIGGER <= '0';
			elsif triggercounter = 1 then
				triggercounter := 2;
			elsif triggercounter = 2 then
				triggercounter := 3;
				SAMPLETRIGGER <= '1';
			else
				triggercounter := 0;
			end if;
			
			-- Progress counters according to sync 
			-- Only accept clean falling sync edge if not comming too early.
			-- Also check if the frame should be shifted by half a line (for interlace)
			if prev_csync="1100000000000000" and x4>=7000 then
				if synclowtime>6000 then
					y := 0;
					shiftedframe := false;
				else
					if y<511 then
						y := y+1;
					end if;
					if synclowtime>3000 then
						shiftedframe := true;
					end if;
				end if;
				synclowtime := 0;
				prevx4 := x4;
				x4 := 0;
			else
				-- keep track of how much time the csync was low (to detect a vsync)
				if prev_csync(0)='0' and synclowtime<8191 then
					synclowtime := synclowtime+1;
				end if;
				-- normal x counter progressing
				if x4<8191 then 
					x4 := x4+1;
            end if;
			end if;
			
			-- registered input
			prev_csync := prev_csync(14 downto 0) & SYNCHISTORY(7);
			in_y := to_integer(unsigned(R));
			in_pb := to_integer(unsigned(G));
			in_pr := to_integer(unsigned(B));
		end if;
		
		-- determine where to write next pixel to and what to write
		bufferwraddress <= (x4/4) + 2048*(y mod 4);
		bufferwrdata <= std_logic_vector(to_unsigned(scaled_r,8))
			& std_logic_vector(to_unsigned(scaled_g,8))
			& std_logic_vector(to_unsigned(scaled_b,8));
			
		-- notify HDMI output about interlacing
		VERTICALSHIFT <= 0;
		if shiftedframe then VERTICALSHIFT <= 1; end if;
	end process;

	
	
	------- pixel output generation 
	process (CLOCK0, VERTICALSHIFT, QUARTERLINEBEGIN, FIRSTLINEBEGIN)	

      constant h_sync : integer := 44;
		constant h_bp :   integer := 64;
		constant h_img :  integer := 1680;
		-- constant h_fp :   integer := 132;

		constant v_sync : integer := 8;
		constant v_bp :   integer := 64;
		constant v_img :  integer := 1050;
		-- constant v_fp :   integer := 500; -- need external sync for proper frame
		
		variable x:integer range 0 to 2047:= 0;  
		variable y:integer range 0 to 2047:= 0;  		
	begin
      adv7513_clk <= CLOCK0; -- CLOCK1;

		if rising_edge(CLOCK0) then 
		
			-- create syncs
			if x<h_sync then
				adv7513_hs <= '1';
			else
				adv7513_hs <= '0';
			end if;
			if y<v_sync then
				adv7513_vs <= '1';
			else
				adv7513_vs <= '0';
			end if;
			
			if   x<h_sync+h_bp or x>=h_sync+h_bp+h_img 
			or   y<v_sync+v_bp or y>=v_sync+v_bp+v_img 
			-- outside visible range
			then
				adv7513_de <= '0';
				adv7513_d <= "000000000000000000000000";
			-- cropped because no analog signal there
			elsif x>=h_sync+h_bp+h_img-40 then
				adv7513_de <= '1';
				adv7513_d <= "000000000000000000000000";			
			-- visible 
			else
				adv7513_de <= '1';
				adv7513_d <= bufferq;
			end if;

			-- progress counters
			if QUARTERLINEBEGIN then
				x := 0;
				if FIRSTLINEBEGIN then
					y := 0;
				elsif y<2047 then
					y := y + 1;
				end if;
			elsif x<2047 then
				x := x +1;
			end if;
		end if;

		-- determine from which address to fetch next pixel
		bufferrdaddress <= x + 140 + 2048*(((y+VERTICALSHIFT*2)/4) mod 4);
			
	end process;

	
	------ create line syncs from frame sync --------------
	process (CLOCK0, FIRSTLINEBEGIN)	
		variable framelength:integer range 0 to 4194303 := 0;  
		variable pixelcounter:integer range 0 to 4194303 := 0; 
		variable accu:integer range 0 to 4194303:= 0; 		
		variable prevfirstlinebegin : boolean;
		
		constant numlines : integer := 312*4;
	begin		
		if rising_edge(CLOCK0) then 
			QUARTERLINEBEGIN <= false;
			
			if FIRSTLINEBEGIN and not prevfirstlinebegin then
				framelength := pixelcounter;
				pixelcounter := 1;		
				accu := framelength;
				QUARTERLINEBEGIN <= true;
			else
				pixelcounter := pixelcounter+1;				
				if accu >= numlines then
					accu := accu - numlines;
				else
					accu := accu + framelength - numlines;
					QUARTERLINEBEGIN <= true;
				end if;				
			end if;
			
			prevfirstlinebegin := FIRSTLINEBEGIN;
		end if;
			
	end process;

	
	------- debug signal 
	process (CLOCK0, QUARTERLINEBEGIN, FIRSTLINEBEGIN)	
		variable count:integer range 0 to 2047:= 0; 		
	begin
		
		if rising_edge(CLOCK0) then 
			if QUARTERLINEBEGIN then
				count := 120*10;
				DEBUG <= '0';
			elsif count > 0 then
				count := count-1;
				DEBUG <= '0';
			else
				DEBUG <= '1';
			end if;
		end if;
			
	end process;
	

	
	
		
end immediate;

