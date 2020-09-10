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
		R : in std_logic_vector(7 downto 0);
		G : in std_logic_vector(7 downto 0);
		B : in std_logic_vector(7 downto 0);
		ENCODE : out std_logic;
		
		-- CSYNC signal (not through ADCs)
		CSYNC : in std_logic
	);	
end entity;


architecture immediate of Upscaler1680x1050 is

component PLL120 is
PORT
	(
		inclk0: IN STD_LOGIC  := '0';
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
	
	
signal CLKPIXEL    : std_logic;

signal QUARTERLINEBEGIN : boolean;
signal FIRSTLINEBEGIN : boolean;

signal bufferwraddress : integer range 0 to 4095;
signal bufferwrdata : std_logic_vector(23 downto 0);
signal bufferrdaddress : integer range 0 to 4095;
signal bufferq : std_logic_vector(23 downto 0);
		
begin		
	pixelclockgenerator: PLL120 port map ( CLK50, CLKPIXEL );
	
	configurator: ConfigureADV7513 port map 
		( CLK50, adv7513_scl, adv7513_sda, open);

	linebuffer : ram_dual generic map(data_width => 24, addr_width => 12)
		port map (
			bufferwrdata,
			std_logic_vector(to_unsigned(bufferrdaddress,12)),
			std_logic_vector(to_unsigned(bufferwraddress,12)),
			'1',
			CLKPIXEL,
			CLKPIXEL,
			bufferq		
		);
	

	------ input sampling ---
	process (CLKPIXEL)
		variable in_csync : std_logic;
		variable prev_csync : std_logic;
		variable in_r : integer range 0 to 255;
		variable in_g : integer range 0 to 255;
		variable in_b : integer range 0 to 255;

		variable x4 : integer range 0 to 8191;
		variable y : integer range 0 to 511;
		variable prevx4 : integer range 0 to 8191;
		variable synclowtime : integer range 0 to 8191;
				
		variable scaled_r : integer range 0 to 255;
		variable scaled_g : integer range 0 to 255;
		variable scaled_b : integer range 0 to 255;
		constant darkest : integer := 20;
		constant lightest : integer := 190;
	begin
		if rising_edge(CLKPIXEL) then
			-- take sample at correct phase and adjust colors
			if x4 mod 4 = 0 then
					if in_r<darkest then scaled_r:=0; 
					elsif in_r>lightest then scaled_r:=255;
					else scaled_r := (in_r-darkest) + (in_r-darkest)/2;
					end if;
					if in_g<darkest then scaled_g:=0; 
					elsif in_g>lightest then scaled_g:=255;
					else scaled_g := (in_g-darkest) + (in_g-darkest)/2;
					end if;
					if in_b<darkest then scaled_b:=0; 
					elsif in_b>lightest then scaled_b:=255;
					else scaled_b := (in_b-darkest) + (in_b-darkest)/2;
					end if;
			end if;
						
			-- emit follow-up encode pulses for the ADCs 
			if x4 mod 4 = 0 then
				ENCODE <= '1';
			elsif x4 mod 4 = 2 then
				ENCODE <= '0';
			end if;			
			
			-- generate the sync pulses to lock the HDMI output to
			QUARTERLINEBEGIN <= x4=0 or x4=prevx4/4 or x4=prevx4/2 or x4=prevx4/2+prevx4/4;			
			FIRSTLINEBEGIN <= x4=0 and y=10;
			
			-- progress counters according to sync 
			-- detect falling edge of csync (only accept if in approximately correct place)
			if in_csync='0' and prev_csync='1' and x4>=7000 then
				if synclowtime>4000 then
					y := 0;
				elsif y<511 then
					y := y+1;
				end if;
				synclowtime := 0;
				prevx4 := x4;
				x4 := 0;
			else
				-- keep track of how much time the csync was low (to detect a vsync)
				if in_csync='0' and synclowtime<8191 then
					synclowtime := synclowtime+1;
				end if;
				-- normal x counter progressing
				if x4<8191 then 
					x4 := x4+1;
				end if;
			end if;
			
			-- registered input
			prev_csync := in_csync;
			in_csync := CSYNC;
			in_r := to_integer(unsigned(R));
			in_g := to_integer(unsigned(G));
			in_b := to_integer(unsigned(B));
		end if;
		
		-- determine where to write next pixel to and what to write
		bufferwraddress <= (x4/4) + 2048*(y mod 2);
		bufferwrdata <= std_logic_vector(to_unsigned(scaled_r,8))
			& std_logic_vector(to_unsigned(scaled_g,8))
			& std_logic_vector(to_unsigned(scaled_b,8));
		
	end process;

	
	------- forward the pixel clock to the HDMI transmitter 
	process (CLKPIXEL)
	begin
      adv7513_clk <= CLKPIXEL;
	end process;
	
	------- pixel output generation 
	process (CLKPIXEL) 
	
		constant h_sync : integer := 44;
		constant h_bp :   integer := 64;
		constant h_img :  integer := 1680;
		constant h_fp :   integer := 132;

		constant v_sync : integer := 8;
		constant v_bp :   integer := 64;
		constant v_img :  integer := 1050;
		constant v_fp :   integer := 126 + 500; -- need external sync for proper frame
		
		variable x:integer range 0 to 2047:= 0;  
		variable y:integer range 0 to 2047:= 0;  	

	--	variable inputlinetime : integer range 0 to 16383;
	--	constant w : integer range 0 to 4095 := 2256;
		
	--	variable in_y : integer range 0 to 511;
	--	variable in_pb : integer range 0 to 511;
	--	variable in_pr : integer range 0 to 511;
	--	variable tmp_g : integer range 0 to 8191;
		
	
	begin
		if rising_edge(CLKPIXEL) then
		
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
				x := h_sync+h_bp+h_img+h_fp/2;
				if FIRSTLINEBEGIN then
					y := v_sync+v_bp+v_img+v_fp-1-4;
				end if;
			elsif x<h_sync+h_bp+h_img+h_fp-1 then
				x:=x+1;
			else
				x := 0;
				if y<v_sync+v_bp+v_img+v_fp-1 then
					y := y+1;
				else
					y := 0;
				end if;
			end if;
		end if;

		-- determine from which address to fetch next pixel
		bufferrdaddress <= x + 150 + 2048*((y/4) mod 2);
			
	end process;
	

	
	

end immediate;

