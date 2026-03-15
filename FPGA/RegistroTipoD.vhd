library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RegistroTipoD is
	port(
	
		clk	: in std_logic;
		D		: in std_logic;
		Q		: out std_logic
		
	);
end RegistroTipoD;

architecture arq of RegistroTipoD is

begin
	
	process(clk)
	begin
	
		if (clk'event and clk='1') then
			Q <= D;
		end if;

	end process;
end arq;