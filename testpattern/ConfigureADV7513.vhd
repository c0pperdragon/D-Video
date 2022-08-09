library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Chip configuration sequence

entity ConfigureADV7513 is	
	port (
		CLK50: in std_logic;			
		
		adv7513_scl: inout std_logic; 
		adv7513_sda: inout std_logic;
		
		SERIALOUT: out std_logic
	);
end entity;


architecture immediate of ConfigureADV7513 is
begin		
	
	-- Control program to initialize the HDMI transmitter and
	-- to retrieve monitor configuration data to select 
	-- correct screen resolution. 
	-- The process implements a serial program with subroutine calls
	-- using a big state machine.
	process (CLK50)
		type T_hexdigit is array(0 to 15) of integer range 0 to 255;
		constant hexdigit : T_hexdigit :=
			(48,49,50,51,52,53,54,55,56,57, 65,66,67,68,69,70);
	
		-- configuration data
		type T_CONFIGPAIR is array(0 to 1) of integer range 0 to 255;
		type T_CONFIGDATA is array(natural range <>) of T_CONFIGPAIR;
		constant CONFIGDATA : T_CONFIGDATA := (
					-- power registers
				(16#41#, 2#00000000#), -- power down inactive
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

					-- sync adjustment activation
				(16#41#, 16#00#), -- disable sync adjustment

					-- video input format
				(16#15#, 16#00#),-- inputID = 0 (standard)

					-- video output format
				                 -- 0x16[7]   = 0b0  .. Output format = 4x4x4
								     -- 0x16[5:4] = 0b11 .. color depth = 8 bit
									  -- 0x16[3:2] = 0x00 .. input style undefined
									  -- 0x16[1]   = 0b0  .. DDR input edge
									  -- 0x16[0]   = 0b0  .. output color space = RGB
				(16#16#, 16#30#),		
				
					-- sync polarity not used (only pass-through)
				(16#17#, 16#00#), 		

					-- output color space converter disable
				(16#18#, 16#00#),   		
				
					-- edid address (slave address=3F)
				(16#43#, 2#01111110#),
					-- various unused options - force to default
				(16#48#, 16#00#),
				(16#BA#, 16#60#),
				(16#D0#, 16#30#),
				(16#40#, 16#00#),
				(16#D5#, 16#00#),
				(16#FB#, 16#00#),
				(16#3B#, 16#00#)
	  );
	
	
		-- implement the program counter with states
		type t_pc is (
			main0,main1,main2,main3,main10,
--			main11,main12,main13,main14,main15,main16,main17,main99,
			i2c0,i2c1,i2c2,i2c3,i2c3a,i2c4,i2c5,i2c6,i2c7,i2c8,i2c9,
			i2c10,i2c11,i2c12,i2c13,i2c14,i2c16,i2c17,i2c18,i2c19,
			i2c20,i2c21,i2c99,i2c100,i2c101,
			i2cpulse0,i2cpulse1,i2cpulse2,
--			uart0,uart1,uart2,
			delay0,delay1,
			millis0,millis1
		);
		variable pc : t_pc := main0;
	  	
		variable main_i:integer range 0 to 255;
--		variable main_edid_hor:  unsigned(11 downto 0);
--		variable main_edid_vert: unsigned(11 downto 0);
		
--		-- subroutine: uart	
--		variable uart_retadr:t_pc;   
--		variable uart_data:unsigned(7 downto 0);         -- data to send
--		variable uart_i:integer range 0 to 11;        
		
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
--		variable out_tx : std_logic := '1';
		variable out_scl : std_logic := '1';
		variable out_sda : std_logic := '1';
--		variable out_resolution : integer range 0 to numres-1;
		
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
			-- program the hdmi transmitter registers
			when main1 =>
				pc := i2c0;
				i2c_address := to_unsigned(16#39#,7);
				i2c_register := to_unsigned(CONFIGDATA(main_i)(0),8);
				i2c_data := to_unsigned(CONFIGDATA(main_i)(1),8);
				i2c_rw := '0';			
				i2c_retadr := main2;	
			when main2 =>
--				if i2c_error/="00000000" then
--					pc := uart0;
--					uart_data := i2c_error; 
--					uart_retadr := main10;
--				else
					pc := main3;
--				end if;
			when main3 =>
				if main_i<CONFIGDATA'LENGTH-1 then
					main_i := main_i + 1;
					pc := main1;
				else
					main_i := 0;
					pc := main10;
				end if;
			when main10 =>
				pc := main10;
							
			-- i2c transfer
			when i2c0 =>
				delay_micros := 3;   -- configure i2c step speed (ca. 100k bit/s)
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
		SERIALOUT <= '0'; -- out_tx;
		if out_scl='0' then adv7513_scl <= '0'; else adv7513_scl <= 'Z'; end if; 
		if out_sda='0' then adv7513_sda <= '0'; else adv7513_sda <= 'Z'; end if; 
--		resolution <= out_resolution;	
			
	end process;
	
	

end immediate;

