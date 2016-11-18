library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity GTIA is	
	port (
		-- Connections to the real GTIAs pins
		CLK         : in std_logic;
		A           : in std_logic_vector(4 downto 0);
		D           : in std_logic_vector(7 downto 0);
		AN          : in std_logic_vector(2 downto 0);
		W           : in std_logic;
		CS          : in std_logic;
		PHI2        : in std_logic;
		HALT        : in std_logic;
		
		-- Output to DVID interface (CLK is bypassed directly) ---
		DVID_SYNC   : out std_logic;
		DVID_RGB    : out std_logic_vector(11 downto 0)
	);	
end entity;


architecture immediate of GTIA is		
begin		
	process (CLK) 

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

	-- registers of the GTIA
	variable HPOSP0 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSP1 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSP2 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSP3 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSM0 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSM1 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSM2 : std_logic_vector (7 downto 0) := "00000000";
	variable HPOSM3 : std_logic_vector (7 downto 0) := "00000000";
	variable SIZEP0 : std_logic_vector (1 downto 0) := "00";
	variable SIZEP1 : std_logic_vector (1 downto 0) := "00";
	variable SIZEP2 : std_logic_vector (1 downto 0) := "00";
	variable SIZEP3 : std_logic_vector (1 downto 0) := "00";
	variable SIZEM  : std_logic_vector (1 downto 0) := "00";
	variable GRAFP0 : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP1 : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP2 : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFP3 : std_logic_vector (7 downto 0) := "00000000";
	variable GRAFM  : std_logic_vector (7 downto 0) := "00000000";
	variable COLPM0 : std_logic_vector (7 downto 1) := "0000000";
	variable COLPM1 : std_logic_vector (7 downto 1) := "0000000";
	variable COLPM2 : std_logic_vector (7 downto 1) := "0000000";
	variable COLPM3 : std_logic_vector (7 downto 1) := "0000000";
	variable COLPF0 : std_logic_vector (7 downto 1) := "0100010";
	variable COLPF1 : std_logic_vector (7 downto 1) := "0100110";
	variable COLPF2 : std_logic_vector (7 downto 1) := "0011010";
	variable COLPF3 : std_logic_vector (7 downto 1) := "0011111";
	variable COLBK  : std_logic_vector (7 downto 1) := "0000000";
	variable PRIOR  : std_logic_vector (7 downto 0) := "00000000";
	variable VDELAY : std_logic_vector (7 downto 0) := "00000000";
	variable GRACTL : std_logic_vector (2 downto 0) := "000";

	-- variables for synchronious operation
	variable vsync : integer range 0 to 1 := 0;
	variable vcounter : integer range 0 to 1 := 0;
	variable hcounter : integer range 0 to 227 := 0;
	variable highres : std_logic := '0';
	variable nextcommand : std_logic_vector(2 downto 0) := "000";
	variable command : std_logic_vector(2 downto 0) := "000";
	variable prevcommand : std_logic_vector(2 downto 0) := "000";

	variable color : std_logic_vector(7 downto 0) := "00000000";
	variable override_lum : std_logic_vector(1 downto 0) := "00"; 
	
	variable tmp_colorlines : std_logic_vector(9 downto 0);
	variable tmp_4bitvalue : std_logic_vector(3 downto 0);
	variable tmp_color : std_logic_vector(7 downto 0);
	variable tmp_x : integer range 0 to 240;
	
	begin
		--------------------- clocked logic -----------------------
		if rising_edge(CLK) then

			-- default color lines to show only background
			override_lum := "00";
			tmp_colorlines := "0000000000";
			
			-- compose the 4bit pixel value that is used in GTIA modes
			if (hcounter mod 2) = 0 then
				tmp_4bitvalue := prevcommand(1 downto 0) & command(1 downto 0);
			else 
				tmp_4bitvalue := command(1 downto 0) & nextcommand(1 downto 0);
			end if;

			----- count pixels and set vsync to default value
			if hcounter<227 then
				hcounter := hcounter+1;
			else 
				hcounter := 0;
				if vcounter=0 then vcounter := 1; else vcounter:=0; end if;
			end if;
			
			----- process previously read antic command ---
			vsync := 0;			
			if command(2) = '1' then	 -- playfield command
				-- interpret bits according to gtia mode				
				case PRIOR(7 downto 6) is
				when "00" =>   -- 4-color playfield or 1.5-color highres
					if highres='0' then
						tmp_colorlines(4 + to_integer(unsigned(command(1 downto 0)))) := '1';
					else
						tmp_colorlines(6) := '1';
						override_lum := command(1 downto 0);
					end if;
				when "01"  =>   -- single hue, 16 luminances
					tmp_colorlines(8) := '1';
				when "10" =>   -- indexed color look up 
					case tmp_4bitvalue is
					when "0000" => tmp_colorlines(0) := '1';
					when "0001" => tmp_colorlines(1) := '1';
					when "0010" => tmp_colorlines(2) := '1';
					when "0011" => tmp_colorlines(3) := '1';
					when "0100" => tmp_colorlines(4) := '1';
					when "0101" => tmp_colorlines(5) := '1';
					when "0110" => tmp_colorlines(6) := '1';
					when "0111" => tmp_colorlines(7) := '1';
					when "1000" =>
					when "1001" =>
					when "1010" =>
					when "1011" =>
					when "1100" => tmp_colorlines(4) := '1';
					when "1101" => tmp_colorlines(5) := '1';
					when "1110" => tmp_colorlines(6) := '1';
					when "1111" => tmp_colorlines(7) := '1';
					end case;
				when "11"  =>   -- 16 hues, single luminance
					tmp_colorlines(9) := '1';
				end case;
			elsif command(1) = '1' then  -- blank command
				highres := command(0);
			elsif  command(0) = '1' then  -- vsync command
				if prevcommand /= "001" then -- check if previous command was vsync already
					vcounter := 0;
					hcounter := 0;
				end if;
				vsync := 1;
			else                          -- background color
			end if;
			
			-- check if players are visible ----
			tmp_x := to_integer(unsigned(HPOSP0));
			if hcounter>=tmp_x and hcounter < tmp_x+8 then
				if GRAFP0(hcounter-tmp_x)='1' then
					tmp_colorlines(0) := '1';
				end if;
			end if;
			tmp_x := to_integer(unsigned(HPOSP1));
			if hcounter>=tmp_x and hcounter < tmp_x+8 then
				if GRAFP1(hcounter-tmp_x)='1' then
					tmp_colorlines(1) := '1';
				end if;
			end if;
			tmp_x := to_integer(unsigned(HPOSP2));
			if hcounter>=tmp_x and hcounter < tmp_x+8 then
				if GRAFP2(hcounter-tmp_x)='1' then
					tmp_colorlines(2) := '1';
				end if;
			end if;
			tmp_x := to_integer(unsigned(HPOSP3));
			if hcounter>=tmp_x and hcounter < tmp_x+8 then
				if GRAFP3(hcounter-tmp_x)='1' then
					tmp_colorlines(3) := '1';
				end if;
			end if;
	
			-- check if missiles are visible ----
			tmp_x := to_integer(unsigned(HPOSM0));
			if hcounter>=tmp_x and hcounter < tmp_x+2 then
				if GRAFM(hcounter-tmp_x)='1' then
					if PRIOR(4)='1' then
						tmp_colorlines(7) := '1';
					else 
						tmp_colorlines(0) := '1';
					end if;
				end if;
			end if;
			tmp_x := to_integer(unsigned(HPOSM1));
			if hcounter>=tmp_x and hcounter < tmp_x+2 then
				if GRAFM(2 + (hcounter-tmp_x))='1' then
					if PRIOR(4)='1' then
						tmp_colorlines(7) := '1';
					else 
						tmp_colorlines(1) := '1';
					end if;
				end if;
			end if;
			tmp_x := to_integer(unsigned(HPOSM2));
			if hcounter>=tmp_x and hcounter < tmp_x+2 then
				if GRAFM(4 + (hcounter-tmp_x))='1' then
					if PRIOR(4)='1' then
						tmp_colorlines(7) := '1';
					else 
						tmp_colorlines(2) := '1';
					end if;
				end if;
			end if;
			tmp_x := to_integer(unsigned(HPOSM3));
			if hcounter>=tmp_x and hcounter < tmp_x+2 then
				if GRAFM(6 + (hcounter-tmp_x))='1' then
					if PRIOR(4)='1' then
						tmp_colorlines(7) := '1';
					else 
						tmp_colorlines(3) := '1';
					end if;
				end if;
			end if;
		
		   -- todo: apply priorities
		
			-- select color according to color lines
			if tmp_colorlines(0)='1' then
				color := COLPM0 & "0";
			elsif tmp_colorlines(1)='1' then
				color := COLPM1 & "0";
			elsif tmp_colorlines(2)='1' then
				color := COLPM2 & "0";
			elsif tmp_colorlines(3)='1' then
				color := COLPM3 & "0";
			elsif tmp_colorlines(4)='1' then
				color := COLPF0 & "0";
			elsif tmp_colorlines(5)='1' then
				color := COLPF1 & "0";
			elsif tmp_colorlines(6)='1' then
				color := COLPF2 & "0";
			elsif tmp_colorlines(7)='1' then
				color := COLPF3 & "0";
			elsif tmp_colorlines(8)='1' then   -- single hue, 16 lums
			   color := COLBK(7 downto 4) & ((COLBK(3 downto 1) & '0') or tmp_4bitvalue);
			elsif tmp_colorlines(9)='1' then   -- 16 hues, single lum
			   color := (COLBK(7 downto 4) or tmp_4bitvalue) & COLBK(3 downto 1) & '0';
			else
				color := COLBK & "0";
		   end if;
		
			----- receive next antic command ----
			prevcommand := command;
			command := nextcommand;
			nextcommand := an;

			----- let cPU write to the registers -----
			if (phi2='1') and (cs='0') and (w='0') then
				case a is
					when "00000" => HPOSP0 := D;
					when "00001" => HPOSP1 := D;
					when "00010" => HPOSP2 := D;
					when "00011" => HPOSP3 := D;
					when "00100" => HPOSM0 := D;
					when "00101" => HPOSM1 := D;
					when "00110" => HPOSM2 := D;
					when "00111" => HPOSM3 := D;				
					when "01000" => SIZEP0 := D(1 downto 0);
					when "01001" => SIZEP1 := D(1 downto 0);
					when "01010" => SIZEP2 := D(1 downto 0);
					when "01011" => SIZEP3 := D(1 downto 0);
					when "01100" => SIZEM  := D(1 downto 0);
					when "01101" => GRAFP0 := D;
					when "01110" => GRAFP1 := D;
					when "01111" => GRAFP2 := D;
					when "10000" => GRAFP3 := D;
					when "10001" => GRAFM  := D;					
					when "10010" => COLPM0 := D(7 downto 1);
					when "10011" => COLPM1 := D(7 downto 1);
					when "10100" => COLPM2 := D(7 downto 1);
					when "10101" => COLPM3 := D(7 downto 1);
					when "10110" => COLPF0 := D(7 downto 1);
					when "10111" => COLPF1 := D(7 downto 1);
					when "11000" => COLPF2 := D(7 downto 1);
					when "11001" => COLPF3 := D(7 downto 1);
					when "11010" => COLBK  := D(7 downto 1);
					when "11011" => PRIOR  := D;
					when "11100" => VDELAY := D;
					when "11101" => GRACTL := D(2 downto 0);
					when "11110" => 
					when "11111" => 
				end case;
			end if;
		end if;
		
		
		-------------------- asynchronous logic ---------------------
				
		-- modify lum in high-res modes depending on clock phase
		tmp_color := color;
		if (override_lum(0)='1' and CLK='0') or (override_lum(1)='1' and CLK='1') then
			tmp_color(3 downto 0) := COLPF1(3 downto 1) & "0";  
		end if;
								
		-- apply rgbpalette to convert lum/hue to rgb				
		DVID_RGB <= std_logic_vector(to_unsigned(
						  rgbtable(to_integer(unsigned(tmp_color))), 
			         12));			
						
		-- generate csync --
		if vsync=1 then
			if hcounter<22 then
				DVID_SYNC <= '1';
			else
				DVID_SYNC <= '0';
			end if;		
		else 
			if hcounter<22 then
				DVID_SYNC <= '0';
			else
				DVID_SYNC <= '1';
			end if;
		end if;
				
	end process;
end immediate;

