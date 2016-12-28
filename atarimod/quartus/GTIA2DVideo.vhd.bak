library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- Implement at test pattern generator that generates
-- a valid D-Video signal.
-- Running on the "Delta Board" usin a MAX 5

entity TestPattern is	
	port (
	   -- default clocking and reset
		CLK100: in std_logic;	
      RST: in std_logic;
	
		DVID_CLK    : out std_logic;
		DVID_SYNC   : out std_logic;
		DVID_RGB    : out STD_LOGIC_VECTOR(11 downto 0)	
	);	
end entity;


architecture immediate of TestPattern is

	signal pixelclock : std_logic;

begin
   ---------------- divide the 100Mhz down to 7.142857 Mhz ---
	process (CLK100) 	
	variable divider : integer range 0 to 7 := 0; -- divider 100Mhz / 14 -> 7.142857 Mhz
	variable out_clk : std_logic := '0';
	begin
		if rising_edge(CLK100) then
			-- toggle ouput every 7th of 100mhz clock
			if divider<6 then 
		      divider := divider+1;
			else
				divider := 0;
				out_clk := not out_clk;
			end if;
		end if;
		pixelclock <= out_clk;
	end process;
	

	-------------------- test signal generator ------------
	process (pixelclock)
	                             
	variable totallines : integer range 0 to 511 := 312;
	variable x : integer range 0 to 511 := 0;     
	variable y : integer range 0 to 511 := 0;     
		-- PAL (50,095 Hz frame rate):
		-- horizontal pixels: 457 (sync:34, bp:40, vis:371, fp:12)
		-- lines: 312 (sync+bp:5, vis:304, fp:3) 
		-- NTSC (60.11 Hz frame rate)
		-- horizontal pixels: 457 (same as PAL)
      -- lines: 260 (sync+bp:5, vis: 254, fp:3)
		 
	
	variable out_clk : std_logic := '0';
	variable out_sync : std_logic := '0';
	variable out_rgb : std_logic_vector(11 downto 0);
	
	begin
		
		if rising_edge(pixelclock) then
		
				out_clk := not out_clk;
				
				-- calculate color pattern including a centered reference frame
				out_rgb := std_logic_vector(to_unsigned((x/2) , 4))
							& std_logic_vector(to_unsigned((x/32+y/32), 4))
							& std_logic_vector(to_unsigned((y/2) , 4));
							
				if x<34+40 or y<5 or x>=34+40+371 or y>=totallines-3
				or x=99 or x=418 or y=53 or y=252 then
					out_rgb := "000000000000";
				end if;
	
				-- calculate the hsync   
				if x<34 then
					out_sync := '0';
				else
					out_sync := '1';
				end if;
				
				-- for the vsync the sync signal is created differently
				if y<5 or y>=totallines-3 then				
					if x<17 or (x>=228 and x<228+17) then
						out_sync := '0';
					else 
						out_sync := '1';
					end if;
					if y<2 or (y=2 and x<228) then
						out_sync := not out_sync;
					end if;
				end if;
								
				-- increment the counters for the next pixel
				if x<456 then 
					x := x+1;
				else 
					x := 0;
					if y<totallines-1 then 
						y := y+1;
					else
						y := 0;
					end if;
				end if;
			
--				-- switch between two output modes
--				if SWITCH(9) = '0' then
--					totallines := 312;
--				else
--					totallines := 260;
--				end if;				
		end if;
			
		
		DVID_CLK <= out_clk;	
		DVID_SYNC <= out_sync;
		DVID_RGB <= out_rgb;
	end process;
	
end immediate;

