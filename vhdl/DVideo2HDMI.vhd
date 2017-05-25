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
		adv7513_scl: inout std_logic; 
		adv7513_sda: inout std_logic; 
      adv7513_hs : out std_logic; 
      adv7513_vs : out std_logic;
      adv7513_clk : out std_logic;
      adv7513_d : out STD_LOGIC_VECTOR(23 downto 0);
      adv7513_de : out std_logic;
	
		-- DVideo input -----
		DVID_CLK    : in std_logic;
		DVID_HSYNC  : in std_logic;
		DVID_VSYNC  : in std_logic;
		DVID_RGB    : in STD_LOGIC_VECTOR(11 downto 0);
		
		-- debugging output ---
		DEBUG : out std_logic
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
	
	function hexdigit(i:integer) return integer is 
	begin 
		if i<=9 then
			return i+48;
		else
			return i+55;
		end if;
	end hexdigit;

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
	
	-- communication between processes
	signal i2c_idle : boolean;
	signal i2c_start : boolean;
	signal i2c_address : unsigned(6 downto 0);
	signal i2c_register : unsigned(7 downto 0);
	signal i2c_data : unsigned(7 downto 0);
		
	signal uart_idle : boolean;    
	signal uart_start : boolean;
	signal uart_byte : unsigned(7 downto 0);
	
begin		
	pixelclockgenerator: PLL_119_5	port map (RST, CLK50, clkpixel);
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
	variable visiblearea : std_logic := '0';
	variable bufferaddress : integer range 0 to 24999;
	
	variable out_framestart : std_logic := '0';
	
	begin	
		if rising_edge(CLK50) then
		
		  if RST='1' then
				pixelvalue := (others => '0');
			   x := 0;
			   y := 0;
				
		  -- process whenever there is new incomming data  
		  elsif in_available='1' then
		  	
			-- compute where to store the incomming pixel data
			visiblearea := '0';
			bufferaddress := 0;
			if x<400 and y<270 and in_vsync='0' and in_hsync='0' then
				visiblearea := '1';
				bufferaddress := (x + y*400) mod 25000;
			end if;

			-- sync signals reset the counter
			if in_vsync='1' then 
				y:= 0;
				x:= 0;
	         pixelvalue := (others => '0');
				
			elsif in_hsync='1' then
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
		ram_wren <= visiblearea;
		ram_wraddress <= std_logic_vector(to_unsigned(bufferaddress,15));
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
	variable insidevisible : std_logic;
	
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
	variable pixelx : integer range 0 to 511;
	variable pixely : integer range 0 to 511;
	variable bufferaddress0 : integer range 0 to 24999;
	variable bufferaddress1 : integer range 0 to 24999;
	
	begin
		if rising_edge(clkpixel) then		
		
         -- write output signals to registers 
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
			if x>=h_sync+h_bp and x<h_total-h_fp and y>=v_sync+v_bp and y<v_total-v_fp then
				out_de := '1';
			else
				out_de := '0';
			end if;
   	
			-- determine the color according to the sample info
			if insidevisible='1' then
				out_rgb :=    ram_q(11 downto 8) 
					         & ram_q(11 downto 8)
								& ram_q(7 downto 4)
								& ram_q(7 downto 4)
								& ram_q(3 downto 0)
								& ram_q(3 downto 0);
			else
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
			

			-- request video data for next pixel (pipeline computation)
			bufferaddress1 := bufferaddress0;
			bufferaddress0 := (pixelx+pixely*400) mod 25000;
			
			-- determine low-res pixel to display (and if any should be visible)
			pixelx := (x-(h_sync+h_bp+40) + 4) / 4;
			pixely := (y-(v_sync+v_bp-15)) / 4;
			 if x>=(h_sync+h_bp+40) and x<(h_sync+h_bp+40+400*4) and
			    y>=(v_sync+v_bp-15) and y<(v_sync+v_bp-15+270*4) 
			 then 
			   insidevisible := '1';
			 else 
			   insidevisible := '0';
			 end if;
			 

			-- continue with next high-res pixel in next clock
			if RST='1' then
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
	
		
      adv7513_clk <= clkpixel; 
      adv7513_hs <= out_hs; 
      adv7513_vs <= out_vs;
      adv7513_de <= out_de;
		adv7513_d <= out_rgb;			

		ram_rdaddress <= std_logic_vector(to_unsigned(bufferaddress1,15));
	end process;
	
	

	
	-- Control program to initialize the HDMI transmitter and
	-- to retrieve monitor configuration data to select 
	-- correct screen resolution. 
	-- The process implements a serial program with subroutine calls
	-- using a big state machine.
	process (CLK50)
		-- configuration data
		type T_CONFIGPAIR is array(0 to 1) of integer range 0 to 255;
		type T_CONFIGDATA is array(natural range <>) of T_CONFIGPAIR;
		constant CONFIGDATA : T_CONFIGDATA := (
                    -- power registers
				(16#41#, 16#00#), -- power down inactive
				(16#D6#, 2#11000000#), -- HPD is always high
				
                    -- fixed registers
				(16#98#, 16#03#), 
				(16#9A#, 16#e0#), 
				(16#9C#, 16#30#),
				(16#9D#, 16#01#),
				(16#A2#, 16#A4#),
				(16#A3#, 16#A4#),
				(16#E0#, 16#D0#),
				(16#F9#, 16#00#),
				
				                 -- force to DVI mode
				(16#AF#, 16#00#),  

  				                 -- video input and output format
				(16#15#, 16#00#),        -- inputID = 1 (standard)
				                 -- 0x16[7]   = 0b0  .. Output format = 4x4x4
								     -- 0x16[5:4] = 0b11 .. color depth = 8 bit
									  -- 0x16[3:2] = 0x00 .. input style undefined
									  -- 0x16[1]   = 0b0  .. DDR input edge
									  -- 0x16[0]   = 0b0  .. output color space = RGB
				(16#16#, 16#30#),		
				
				                 -- various unused options - force to default
				(16#17#, 16#00#), 		
				(16#18#, 16#00#),  -- output color space converter disable 		
				(16#48#, 16#00#),
				(16#BA#, 16#60#),
				(16#D0#, 16#30#),
				(16#40#, 16#00#),
				(16#41#, 16#00#),
				(16#D5#, 16#00#),
				(16#FB#, 16#00#),
				(16#3B#, 16#00#)
	  );
	
	
		-- implement the program counter with states
		type t_pc is (
			main0,main1,main2,main3,main10,main11,main12,main13,main14,main99,
			i2c0,i2c1,i2c2,i2c3,i2c3a,i2c4,i2c5,i2c6,i2c7,i2c8,i2c9,
			i2c10,i2c11,i2c12,i2c13,i2c14,i2c16,i2c17,i2c18,i2c19,
			i2c20,i2c21,i2c99,i2c100,i2c101,
			i2cpulse0,i2cpulse1,i2cpulse2,
			uart0,uart1,uart2,
			delay0,delay1,
			millis0,millis1
		);
		variable pc : t_pc := main0;
	  	
		variable main_i:integer range 0 to 255;
	
		-- subroutine: uart	
		variable uart_retadr:t_pc;   
		variable uart_data:unsigned(7 downto 0);         -- data to send
		variable uart_i:integer range 0 to 11;        
		
		-- subroutine: i2cwrite
		variable i2c_retadr : t_pc;
		variable i2c_address : unsigned(6 downto 0);
		variable i2c_register : unsigned(7 downto 0);
		variable i2c_data : unsigned(7 downto 0);
		variable i2c_rw : std_logic;  -- '0'=w
		variable i2c_error : unsigned(7 downto 0);
		variable i2c_i : integer range 0 to 7;

		-- subroute i2cpulse
		variable i2cpulse_retadr : t_pc;
		variable i2cpulse_sda : std_logic;
		
		-- subroutine: delay
		variable delay_retadr:t_pc;
		variable delay_micros:integer range 0 to 1000;  -- microseconds to delay
		variable delay_i:integer range 0 to 1000*50;

		-- subroutine: millis
		variable millis_retadr:t_pc;
		variable millis_millis:integer range 0 to 1000;  -- microseconds to delay
		variable millis_i:integer range 0 to 1000*50;
		
		-- output signal buffers 
		variable out_tx : std_logic := '1';
		variable out_scl : std_logic := '1';
		variable out_sda : std_logic := '1';
		
	begin

		-- synchronious program execution
		if rising_edge(CLK50) then
			case pc is
			
			-- main routine
			when main0 =>
				main_i := 0;
				pc := millis0;
				millis_millis := 200;  -- wait 200 millis before start
				millis_retadr := main1;
			when main1 =>
				pc := i2c0;
				i2c_address := to_unsigned(16#39#,7);
				i2c_register := to_unsigned(CONFIGDATA(main_i)(0),8);
				i2c_data := to_unsigned(CONFIGDATA(main_i)(1),8);
				i2c_rw := '0';			
				i2c_retadr := main2;	
			when main2 =>
				if i2c_error/="00000000" then
					pc := uart0;
					uart_data := i2c_error; 
					uart_retadr := main99;
				else
					pc := main3;
				end if;
			when main3 =>
				if main_i<CONFIGDATA'LENGTH-1 then
					main_i := main_i + 1;
					pc := main1;
				else
					main_i := 0;
					pc := main10;
				end if;
			when main10 =>
				pc := i2c0;
				i2c_address := to_unsigned(16#39#,7);
				i2c_register := to_unsigned(main_i,8);
				i2c_rw := '1';			
				i2c_retadr := main11;
			when main11 =>
				if i2c_error/="00000000" then
					pc := uart0;
					uart_data := i2c_error; 
					uart_retadr := main99;
				else				
					pc := uart0;
					uart_data := to_unsigned(hexdigit(to_integer(i2c_data(7 downto 4))),8);
					uart_retadr := main12;
				end if;
			when main12 =>
				pc := uart0;
				uart_data := to_unsigned(hexdigit(to_integer(i2c_data(3 downto 0))),8);
				uart_retadr := main13;
			when main13 =>
				pc := uart0;
				if (main_i mod 16) = 15 then 
					uart_data := to_unsigned(10,8);
				else
					uart_data := to_unsigned(32,8);
				end if;
				uart_retadr := main14;			
			when main14 =>
				if main_i < 255 then
					main_i := main_i + 1;
					pc := main10;
				else
					pc := uart0;
					uart_data := to_unsigned(10,8);
					uart_retadr := main99;			
				end if;
			
			when main99 =>
				pc := millis0;
				millis_millis := 1000;
				millis_retadr := main0;
					
			-- uart transmit
			when uart0 =>
				out_tx := '0'; -- start bit
				uart_i := 0;
				pc := delay0;
				delay_micros := 104;  -- delay setting for for 9600 baud
				delay_retadr := uart1;
			when uart1 =>
				out_tx := uart_data(uart_i);  -- data bits
				pc := delay0;
				if uart_i<7 then 
					uart_i := uart_i+1;
					delay_retadr := uart1;
				else 
					delay_retadr := uart2;
				end if;	
			when uart2 =>
				out_tx := '1'; -- stop bit and idle level
				pc := delay0;
				delay_retadr := uart_retadr;				
			
			-- i2c transfer
			when i2c0 =>
				delay_micros := 100;   -- configure i2c step speed
				i2c_error := to_unsigned(0,8);
				out_sda := '0';    	-- start condition 1  
				out_scl := '1';
				pc := delay0;
				delay_retadr := i2c1;
			when i2c1 =>
				out_sda := '0';       -- start condition 2
				out_scl := '0';
				pc := delay0;
				delay_retadr := i2c2;
				i2c_i := 6;
			when i2c2 =>
				out_sda := i2c_address(i2c_i);   -- sending address
				pc := i2cpulse0;
				if i2c_i>0 then
					i2c_i := i2c_i -1;
					i2cpulse_retadr := i2c2;
				else
					i2cpulse_retadr := i2c3;
				end if;
			when i2c3 =>                         
				out_sda := '0';               -- write mode 
				pc := i2cpulse0;
				i2cpulse_retadr := i2c3a;
			when i2c3a =>                         
				out_sda := '1';              -- let slave send ack
				pc := i2cpulse0;
				i2cpulse_retadr := i2c4;
			when i2c4 =>   
				if i2cpulse_sda='0' then    -- ack received
					i2c_i := 7;
					pc := i2c5;
				else
					i2c_error := to_unsigned(69,8);  -- 'E'
					pc := i2c99;
				end if;
			when i2c5 =>
				out_sda := i2c_register(i2c_i);   -- sending register number
				pc := i2cpulse0;
				if i2c_i>0 then
					i2c_i := i2c_i -1;
					i2cpulse_retadr := i2c5;
				else
					i2cpulse_retadr := i2c6;
				end if;
			when i2c6 =>
				out_sda := '1';                  -- let slave send ack
				pc := i2cpulse0;
				i2cpulse_retadr := i2c7;
			when i2c7 =>
				if i2cpulse_sda='0' then         -- received ack
					i2c_i := 7;
					if i2c_rw='0' then     
						pc := i2c8;   -- set register
					else
						pc := i2c11;  -- read register
					end if;
				else
					i2c_error :=  to_unsigned(70,8);  -- 'F'
					pc := i2c99;
				end if;
			when i2c8 =>
				out_sda := i2c_data(i2c_i);     -- sending data
				pc := i2cpulse0;
				if i2c_i>0 then
					i2c_i := i2c_i -1;
					i2cpulse_retadr := i2c8;
				else
					i2cpulse_retadr := i2c9;
				end if;
			when i2c9 => 
				out_sda := '1';                  -- let slave send ack
				pc := i2cpulse0;
				i2cpulse_retadr := i2c10;
			when i2c10 =>
				if i2cpulse_sda='0' then         -- received ack
					pc := i2c99;
				else
					i2c_error :=  to_unsigned(71,8);  -- 'G'
					pc := i2c99;
				end if;
				
			when i2c11 =>	                 
				out_sda := '1';                  -- restart condition 1
				out_scl := '0';                  
				pc := delay0;
				delay_retadr := i2c12;
			when i2c12 =>	                 
				out_sda := '1';                  -- restart condtion 2
				out_scl := '1';                 
				pc := delay0;
				delay_retadr := i2c13;
			when i2c13 =>	                 
				out_sda := '0';                  -- restart condition 3
				out_scl := '1';                 
				pc := delay0;
				delay_retadr := i2c14;
			when i2c14 =>	                 
				out_sda := '0';                  -- restart condition 4
				out_scl := '0';                 
				pc := delay0;
				delay_retadr := i2c16;
				i2c_i := 6;
			when i2c16 =>
				out_sda := i2c_address(i2c_i);   -- sending address
				pc := i2cpulse0;
				if i2c_i>0 then
					i2c_i := i2c_i -1;
					i2cpulse_retadr := i2c16;
				else
					i2cpulse_retadr := i2c17;
				end if;
			when i2c17 =>                         
				out_sda := '1';               -- read mode 
				pc := i2cpulse0;
				i2cpulse_retadr := i2c18;
			when i2c18 =>                         
				out_sda := '1';              -- let slave send ack
				pc := i2cpulse0;
				i2cpulse_retadr := i2c19;
			when i2c19 =>   
				if i2cpulse_sda='0' then     -- ack received
					i2c_i := 7;
					pc := i2c20;
				else
					i2c_error := to_unsigned(82,8);  -- 'R'
					pc := i2c99;
				end if;
			when i2c20 =>
				out_sda := '1';              -- let slave send data
				pc := i2cpulse0;
				i2cpulse_retadr := i2c21;
			when i2c21 =>
				i2c_data(i2c_i) := i2cpulse_sda;    -- reive data
				if i2c_i>0 then
					i2c_i := i2c_i-1;
					pc := i2c20;
				else
					out_sda := '1';                -- send final nack 
					pc := i2cpulse0;
					i2cpulse_retadr := i2c99;
				end if;
								
			when i2c99 =>
				out_sda := '0';                  -- end condition 1
				out_scl := '0';
				pc := delay0;
				delay_retadr := i2c100;
			when i2c100 =>
				out_sda := '0';                  -- end condition 2
				out_scl := '1';
				pc := delay0;
				delay_retadr := i2c101;
			when i2c101 =>
				out_sda := '1';                  -- end condition 3
				out_scl := '1';
				pc := delay0;
				delay_retadr := i2c_retadr;
				
			-- perform a single i2c clock
			when i2cpulse0 =>
				out_scl := '0';
				pc := delay0;
				delay_retadr := i2cpulse1;				
			when i2cpulse1 =>
				out_scl := '1';
				pc := delay0;
				delay_retadr := i2cpulse2;
			when i2cpulse2 =>
				if adv7513_scl='1' then  -- proceed if slave does not stretch the clock
					i2cpulse_sda := adv7513_sda;  -- sample data at correct time
					out_scl := '0';
					pc := delay0;
					delay_retadr := i2cpulse_retadr;
				else 
					pc := delay0;					
					delay_retadr := i2cpulse2;
				end if;
			
			-- delay
			when delay0 =>
				delay_i := delay_micros * 50;
				pc := delay1;
			when delay1 =>
				if delay_i>0 then
					delay_i := delay_i -1;
				else
					pc := delay_retadr;
				end if;
				
			-- millis
			when millis0 =>
				millis_i := millis_millis;
				pc := millis1;
			when millis1 =>
				pc := delay0;
				delay_micros := 1000;
				if millis_i>0 then
					millis_i := millis_i-1;
					delay_retadr := millis1;
				else
					delay_retadr := millis_retadr;
				end if;
				
			end case;
		end if;

	   -- async logic: set output signals according to registers
		DEBUG <= out_tx;
		if out_scl='0' then adv7513_scl <= '0'; else adv7513_scl <= 'Z'; end if; 
		if out_sda='0' then adv7513_sda <= '0'; else adv7513_sda <= 'Z'; end if; 
			
	end process;
	
end immediate;


