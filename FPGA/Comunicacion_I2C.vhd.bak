library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_slave is
    generic(
        SLAVE_ADDR : std_logic_vector(6 downto 0) := "0011101"
    );
    port(
        clk   : in std_logic;
        reset : in std_logic;

        scl   : in std_logic;
        sda   : inout std_logic;

        data_in  : in std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0);

        data_valid : out std_logic;
        read_req   : out std_logic
    );
end i2c_slave;

architecture Behavioral of i2c_slave is

type state_type is (
    IDLE,
    ADDRESS,
    ACK_ADDRESS,
    RECEIVE_DATA,
    TRANSMIT_DATA,
    ACK_DATA
);

signal state : state_type := IDLE;

signal bit_count : integer range 0 to 7 := 0;

signal shift_reg : std_logic_vector(7 downto 0);

signal sda_out : std_logic := '1';
signal sda_in  : std_logic;

signal rw_bit : std_logic;

signal scl_prev : std_logic := '1';
signal sda_prev : std_logic := '1';

signal start_detected : std_logic;
signal stop_detected  : std_logic;

begin

sda <= '0' when sda_out = '0' else 'Z';
sda_in <= sda;

-- Detectar START y STOP
process(clk)
begin
    if rising_edge(clk) then

        start_detected <= '0';
        stop_detected  <= '0';

        if scl = '1' then
            if sda_prev = '1' and sda_in = '0' then
                start_detected <= '1';
            elsif sda_prev = '0' and sda_in = '1' then
                stop_detected <= '1';
            end if;
        end if;

        sda_prev <= sda_in;
        scl_prev <= scl;

    end if;
end process;

-- Máquina de estados
process(clk, reset)
begin

if reset = '1' then
    state <= IDLE;
    sda_out <= '1';
    bit_count <= 7;
    data_valid <= '0';
    read_req <= '0';

elsif rising_edge(clk) then

case state is

when IDLE =>

    data_valid <= '0';
    read_req <= '0';

    if start_detected = '1' then
        state <= ADDRESS;
        bit_count <= 7;
    end if;

-- Lectura de dirección
when ADDRESS =>

    if scl_prev = '0' and scl = '1' then

        shift_reg(bit_count) <= sda_in;

        if bit_count = 0 then
            rw_bit <= sda_in;
            state <= ACK_ADDRESS;
        else
            bit_count <= bit_count - 1;
        end if;

    end if;

-- ACK de dirección
when ACK_ADDRESS =>

    if shift_reg(7 downto 1) = SLAVE_ADDR then

        sda_out <= '0';

        if rw_bit = '0' then
            state <= RECEIVE_DATA;
        else
            state <= TRANSMIT_DATA;
            read_req <= '1';
            shift_reg <= data_in;
        end if;

        bit_count <= 7;

    else
        sda_out <= '1';
        state <= IDLE;
    end if;

-- Recibir datos del maestro
when RECEIVE_DATA =>

    if scl_prev = '0' and scl = '1' then

        shift_reg(bit_count) <= sda_in;

        if bit_count = 0 then
            data_out <= shift_reg;
            data_valid <= '1';
            state <= ACK_DATA;
        else
            bit_count <= bit_count - 1;
        end if;

    end if;

-- Enviar datos al maestro
when TRANSMIT_DATA =>

    if scl_prev = '1' and scl = '0' then
        sda_out <= shift_reg(bit_count);

        if bit_count = 0 then
            state <= ACK_DATA;
        else
            bit_count <= bit_count - 1;
        end if;

    end if;

-- ACK después de dato
when ACK_DATA =>

    sda_out <= '0';

    if stop_detected = '1' then
        state <= IDLE;
        sda_out <= '1';
    end if;

end case;

end if;

end process;

end Behavioral;