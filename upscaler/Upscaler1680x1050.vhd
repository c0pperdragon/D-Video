library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement an upscaler from a standard resoultion video signal to 1680x1050 HDMI.
-- All lines are quadrupled, and the horizontal sync slip between input and output is
-- compensated by adding/removing pixels from the end of each output line.
-- To match the vertical resolution also, the output will append as much additional blanking
-- lines as necessary.
--
-- The default horizontal output pixel timings for this mode is: 1680 1784 1968 2256   
-- When quadrupling every input line we need a output line frequency of 62500Hz, and thus 
-- an output pixel frequency of 141Mhz.
-- 
-- NTSC line frequency: 15734 Hz  ->  2240 total pixels in quadrupel output mode


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
		Y : in std_logic_vector(7 downto 0);
		PB : in std_logic_vector(7 downto 0);
		PR : in std_logic_vector(7 downto 0);
		ENCODE : out std_logic
	);	
end entity;


architecture immediate of Upscaler1680x1050 is

component PLL141 is
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

signal Y_IN : std_logic_vector(7 downto 0);
signal PB_IN : std_logic_vector(7 downto 0);
signal PR_IN : std_logic_vector(7 downto 0);
signal PB_IDLE : std_logic_vector(7 downto 0);
signal PR_IDLE : std_logic_vector(7 downto 0);

signal HSYNC : std_logic;
signal VSYNC : std_logic;
signal EVENLINE : std_logic;

signal bufferrdaddress : std_logic_vector(11 downto 0);
signal bufferwraddress : std_logic_vector(11 downto 0);
signal bufferq : std_logic_vector(23 downto 0);
		
begin		
	pixelclockgenerator: PLL141 port map ( CLK50, CLKPIXEL );
	
	configurator: ConfigureADV7513 port map 
		( CLK50, adv7513_scl, adv7513_sda, open);

	linebuffer : ram_dual generic map(data_width => 24, addr_width => 12)
		port map (
			Y_IN & PB_IN & PR_IN,
			bufferrdaddress,
			bufferwraddress,
			'1',
			CLKPIXEL,
			CLKPIXEL,
			bufferq		
		);
	
	------- drive the ADCs 	
	process (CLKPIXEL) 
	variable p:std_logic := '0';
	begin
		if rising_edge(CLKPIXEL) then
			if p='0' then
				p:='1';
				ENCODE <= '1';
				Y_IN <= Y;
				PB_IN <= PB;
				PR_IN <= PR;
			else
				p:='0';
				ENCODE <= '0';
			end if;
		end if;
	end process;

	------ scan input lines and detect hsync and vsync	
	process (CLKPIXEL)
	constant tunex : integer := 1700;
	
	variable x : integer range 0 to 16383;
	variable syncduration : integer range 0 to 16383;
	variable nowsync : boolean := false;
	variable prevsync : boolean := false;
	
	begin
		if rising_edge(CLKPIXEL) then
			
			if nowsync and (not prevsync) and x>8000 then
				HSYNC <= '0';
				if syncduration>6000 then 
					VSYNC <= '0';
				else
					VSYNC <= '1';
				end if;
				x := 0;
				syncduration := 0;
				bufferwraddress <= EVENLINE & "11111111111";
				if EVENLINE='0' then
					EVENLINE <= '1';
				else
					EVENLINE <= '0';
				end if;
			else
				HSYNC <= '1';
				VSYNC <= '1';
				
				if x=100 then
					PB_IDLE <= PB_IN;
					PR_IDLE <= PR_IN;
				end if;
				
				if x>=tunex and x<tunex+8192 then
					bufferwraddress <= EVENLINE & std_logic_vector(to_unsigned((x-tunex)/4,11));
				else
					bufferwraddress <= EVENLINE & "11111111111";				
				end if;
				if x/=16383 then x := x+1; end if;
				if nowsync and syncduration/=16383 then syncduration:=syncduration+1; end if;
			end if;
		
			prevsync := nowsync;
			nowsync := to_integer(unsigned(Y_IN)) < 30;
		end if;
	end process;
	
	
	
	
	------- send the pixel clock to the HDMI transmitter 
	process (CLKPIXEL)
	begin
      adv7513_clk <= CLKPIXEL;
	end process;
	
	
	------- generator for the HDMI test image 	
	process (CLKPIXEL) 
	
	constant h_sync : integer := 184;
	constant h_bp :   integer := 288;
	constant h_img :  integer := 1680;
--	constant h_fp :   integer := 104;

	constant v_fp :   integer := 4;
	constant v_sync : integer := 2;
	constant v_bp :   integer := 2;
--	constant v_img :  integer := 1050;
--	constant v_fp :   integer := 312*4 - v_sync - v_bp - v_img;   -- 50Hz
--	constant v_img :  integer := 1040;
	
	variable x:integer range 0 to 4095:= 0;  
	variable y:integer range 0 to 2047:= 0;  	

	variable inputlinetime : integer range 0 to 16383;
	constant w : integer range 0 to 4095 := 2242;
	
	variable in_y : integer range 0 to 511;
	variable in_pb : integer range 0 to 511;
	variable in_pr : integer range 0 to 511;
	variable tmp_g : integer range 0 to 8191;
	
	begin

		if rising_edge(CLKPIXEL) then
			-- create output signals
			if x<h_sync then
				adv7513_hs <= '1';
			else
				adv7513_hs <= '0';
			end if;
			if y>=v_fp and y<v_fp+v_sync then
				adv7513_vs <= '1';
			else
				adv7513_vs <= '0';
			end if;
			
			if   x>=h_sync+h_bp and x<h_sync+h_bp+h_img 
			and  y>=v_fp+v_sync+v_bp -- and y<v_fp+v_sync+v_bp+v_img 
			then
				adv7513_de <= '1';
				
--				if x=h_sync+h_bp or y=v_fp+v_sync+v_bp or x=h_sync+h_bp+h_img-1 or y=v_fp+v_sync+v_bp+v_img-1 then
--					adv7513_d <= "111111111111111111111111";
--				else
					-- compute output green
					tmp_g := 4096
					       + in_y * 8 
					       + 256 * 3
							 - in_pb * 3        
							 + 256 * 4
							 - in_pr * 4;       
					if tmp_g<4096 then 
						adv7513_d(23 downto 16) <= "00000000";
					elsif tmp_g>=4096+255*4 then
						adv7513_d(15 downto 8) <= "11111111";
					else
						adv7513_d(15 downto 8) <= std_logic_vector(to_unsigned((tmp_g-4096)/4,8));
					end if;
               -- compute output blue
					if in_y+in_pb > 256+127 then
						adv7513_d(7 downto 0) <= "11111111";
					elsif in_y+in_pb < 256 then
						adv7513_d(7 downto 0) <= "00000000";
					else
						adv7513_d(7 downto 0) <= std_logic_vector(to_unsigned((in_y+in_pb-256)*2,8));
					end if;
					-- compute output red
					if in_y+in_pr > 256+127 then
						adv7513_d(23 downto 16) <= "11111111";
					elsif in_y+in_pr < 256 then
						adv7513_d(23 downto 16) <= "00000000";
					else
						adv7513_d(23 downto 16) <= std_logic_vector(to_unsigned((in_y+in_pr-256)*2,8));
					end if;					
--				end if;		
				
			else
				adv7513_de <= '0';
				adv7513_d <= "000000000000000000000000";
			end if;
			
			-- from where to read next data
			bufferrdaddress <= (not EVENLINE) & std_logic_vector(to_unsigned(x+2-(h_sync+h_bp),11));
			
			-- progress counters
			if x<w-1 and HSYNC='1' then
				x:=x+1;
			else
				if x>w/2 then
--					if y=263*4-1 then
--						y:=0;
					if y>100 and VSYNC='0' then
						y := 0;
					else
						y := y+1;
					end if;
--					if y>50 and VSYNC='0' then
--						y := 0;
--					elsif y<263*4-1 then
--						y := y+1;
--					else
--						y := y+1;
--					end if;
				end if;
				x:= 0;
			end if;
			
--			if HSYNC='0' then
--				w := inputlinetime / 4;
--				inputlinetime := 0;
--			else
--				inputlinetime := inputlinetime+1;
--			end if;
			
			-- take into registers and scale   (in_pb/in_pr having 256 as 0-point)
			in_y := to_integer(unsigned(bufferq(23 downto 16)));
			if in_y<70 then 
				in_y:=0;
			else
				in_y:=(in_y-70);
			end if;
			in_pb := 256 - to_integer(unsigned(PB_IDLE)) + to_integer(unsigned(bufferq(15 downto 8)));
			in_pr := 256 - to_integer(unsigned(PR_IDLE)) + to_integer(unsigned(bufferq(7 downto 0)));
		end if;
			
	end process;
	

	
	

end immediate;

