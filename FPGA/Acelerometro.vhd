library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Acelerometro is
    port(

        clk   : in std_logic;
        reset : in std_logic;

        scl : in std_logic;
        sda : inout std_logic

    );
end Acelerometro;

architecture arch of Acelerometro is

signal data_from_i2c : std_logic_vector(7 downto 0);
signal data_to_i2c   : std_logic_vector(7 downto 0);

signal data_valid : std_logic;
signal read_req   : std_logic;

signal reg_addr : std_logic_vector(7 downto 0);

-- Registro de un acelerometro, 6 registros de 8 bits
type reg_array is array (0 to 5) of std_logic_vector(7 downto 0);

signal registers : reg_array := (
    x"12", -- GYRO_XOUT_H 
    x"34", -- GYRO_XOUT_L 
    x"56", -- GYRO_YOUT_H 
    x"78", -- GYRO_YOUT_L 
    x"9A", -- GYRO_ZOUT_H 
    x"BC"  -- GYRO_ZOUT_L 
);

begin

	i2c_inst : entity work.Comunicacion_I2C
	generic map(
		 DIR_esclavo => "110100"
	)
	port map(

		 clk => clk,
		 reset => reset,
		 bit_conf => '0', -- Bit bajo configurable


		 scl => scl,
		 sda => sda,

		 data_in => data_to_i2c,
		 data_out => data_from_i2c,

		 data_valid => data_valid,
		 read_req => read_req
	);

	-- lógica de registros

	-- Proceso 1: Guarda la dirección que el maestro quiere leer
    process(clk)
    begin
        if rising_edge(clk) then
            if data_valid = '1' then
                reg_addr <= data_from_i2c;
            end if;
        end if;
    end process;

    -- Proceso 2: Concurrente (sin reloj). 
    process(reg_addr, registers)
    begin
        case reg_addr is
            when x"28" => data_to_i2c <= registers(0);
            when x"29" => data_to_i2c <= registers(1);
            when x"2A" => data_to_i2c <= registers(2);
            when x"2B" => data_to_i2c <= registers(3);
            when x"2C" => data_to_i2c <= registers(4);
            when x"2D" => data_to_i2c <= registers(5);
            when others => data_to_i2c <= x"00";
        end case;
    end process;

end arch;