library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


 

entity VIC2DVideo is	
	port (
		-- Connections to the VIC pins (everything is inverted)
		CLK         : in std_logic;
		DUMMY       : in std_logic;
		
		-- Data from the ADCs 
		LUM         : in std_logic_vector(7 downto 0);
		COL         : in std_logic_vector(7 downto 0);
		
		-- output to the DVideo interface
		DVID_CLK    : out std_logic;
		DVID_SYNC   : out std_logic;
		DVID_RGB    : out STD_LOGIC_VECTOR(11 downto 0)	
	);	
end entity;


architecture immediate of VIC2DVideo is
begin
	process (CLK) 
	
	variable hpos : integer range 0 to 511 := 0;
	
	variable out_clk : std_logic := '0';
	variable out_sync : std_logic := '0';
	variable out_lum : std_logic_vector(7 downto 0) := "00000000";
	
	variable in_lum : integer range 0 to 255;
	variable in_col : integer range 0 to 255;
	variable in_col2 : integer range 0 to 255;

 	begin
	   if rising_edge(CLK) then
			out_clk := not out_clk;						
			
			if hpos>200 and hpos<300 then
--				out_lum := std_logic_vector(to_unsigned(in_col,8)); 
				out_lum := std_logic_vector(to_unsigned(in_col2,8)); 
			else
				out_lum := std_logic_vector(to_unsigned(in_lum,8)); 
			end if;

			if in_lum < 40 then
				out_sync := '0';
				hpos := 0;
			else
				out_sync := '1';
				if hpos<511 then
					hpos := hpos+1;
				end if;
			end if;
			
			
			in_lum := to_integer(unsigned(LUM));
			in_col := to_integer(unsigned(COL));
		end if;
		
		if falling_edge(CLK) then
			in_col2 := to_integer(unsigned(COL));
		end if;
		
		DVID_CLK <= out_clk;
		DVID_SYNC <= out_sync;
		DVID_RGB  <= "0000" & out_lum;
	end process;
	
end immediate;

