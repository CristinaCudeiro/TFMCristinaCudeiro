library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Comunicacion_I2C is
    generic(
        DIR_esclavo : std_logic_vector(5 downto 0) := "110100"
    );
    port(
        clk   : in std_logic;
        reset : in std_logic;
		  bit_conf : in std_logic; -- Bit bajo configurable

        scl   : in std_logic;
        sda   : inout std_logic;

        data_in  : in std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0);

        data_valid : out std_logic; -- Indicador de que se han leido todos los bits del dato enviado por el maestro
        read_req   : out std_logic -- Indicador de que el maestro quiere leer datos
    );
end Comunicacion_I2C;

architecture arch of Comunicacion_I2C is

-- Maquina de estados
type state_type is (
    IDLE, -- Espera a que llegue un bit de start 
    ADDRESS, -- Lee la dirección del maestro
    ACK_ADDRESS, -- Si la direccion es la mia leo o escribo
    RECEIVE_DATA, -- Lee datos
    TRANSMIT_DATA, -- Envía datos
    ACK_DATA -- ACK para los datos y envio del stop
);

signal state : state_type := IDLE;
signal bit_count : integer range 0 to 7 := 0;
signal shift_reg : std_logic_vector(7 downto 0);

signal sda_out : std_logic := '1';
--signal sda_in  : std_logic;
signal rw_bit : std_logic;

signal scl_prev : std_logic := '1';
signal sda_prev : std_logic := '1';

-- Señales intermedias para conectar tus registros en cascada (n=3)
signal scl_d1, scl_d2, scl_d3 : std_logic;
signal sda_d1, sda_d2, sda_d3 : std_logic;

signal scl_rising     : std_logic;
signal scl_falling    : std_logic;

signal start_detected : std_logic;
signal stop_detected  : std_logic;

signal dir_completa : std_logic_vector(6 downto 0);

begin

-- Concatenamos direccion
dir_completa <= DIR_esclavo & bit_conf;

sda <= '0' when sda_out = '0' else 'Z';
--sda_in <= sda;

-------------------------------------------------------------------------
-- INSTANCIACIÓN DE TUS REGISTROS TIPO D EN CASCADA (Sincronización)
-------------------------------------------------------------------------
-- Cascada para SCL
Reg_SCL_1: entity work.RegistroTipoD port map(clk => clk, D => scl,    Q => scl_d1);
Reg_SCL_2: entity work.RegistroTipoD port map(clk => clk, D => scl_d1, Q => scl_d2);
Reg_SCL_3: entity work.RegistroTipoD port map(clk => clk, D => scl_d2, Q => scl_d3);

-- Cascada para SDA
Reg_SDA_1: entity work.RegistroTipoD port map(clk => clk, D => sda,    Q => sda_d1);
Reg_SDA_2: entity work.RegistroTipoD port map(clk => clk, D => sda_d1, Q => sda_d2);
Reg_SDA_3: entity work.RegistroTipoD port map(clk => clk, D => sda_d2, Q => sda_d3);


-------------------------------------------------------------------------
-- DETECCIÓN DE FLANCOS Y CONDICIONES
-------------------------------------------------------------------------
-- Comparamos la salida del registro 2 (estado actual retrasado) 
-- con el registro 3 (estado anterior)
scl_rising  <= '1' when scl_d3 = '0' and scl_d2 = '1' else '0';
scl_falling <= '1' when scl_d3 = '1' and scl_d2 = '0' else '0';

-- START: SCL estable en alto, y SDA pasa de 1 a 0
start_detected <= '1' when scl_d2 = '1' and sda_d3 = '1' and sda_d2 = '0' else '0';
-- STOP: SCL estable en alto, y SDA pasa de 0 a 1
stop_detected  <= '1' when scl_d2 = '1' and sda_d3 = '0' and sda_d2 = '1' else '0';

-- Detectar START y STOP

process(clk, reset)
begin
    if reset = '1' then
        state <= IDLE;
        sda_out <= '1';
        bit_count <= 7;
        data_valid <= '0';
        read_req <= '0';
        
    elsif rising_edge(clk) then
        
        data_valid <= '0';
        read_req <= '0';

        if start_detected = '1' then
            state <= ADDRESS;
            bit_count <= 7;
            sda_out <= '1';
        
        elsif stop_detected = '1' then
            state <= IDLE;
            sda_out <= '1';
            
        else
            case state is

                when IDLE =>
                    sda_out <= '1';

                when ADDRESS =>
                    if scl_rising = '1' then 
                        -- Leemos el SDA sincronizado y retrasado
                        shift_reg(bit_count) <= sda_d2; 
                        if bit_count = 0 then
                            rw_bit <= sda_d2;
                        end if;
                    end if;

                    if scl_falling = '1' then
                        if bit_count = 0 then
                            state <= ACK_ADDRESS;
                        else
                            bit_count <= bit_count - 1;
                        end if;
                    end if;

                when ACK_ADDRESS =>
                    if scl_falling = '1' then
                        if shift_reg(7 downto 1) = dir_completa then
                            sda_out <= '0'; 
                            bit_count <= 7;
                            if rw_bit = '0' then
                                state <= RECEIVE_DATA;
                            else
                                state <= TRANSMIT_DATA;
                                read_req <= '1'; 
                                shift_reg <= data_in;
                            end if;
                        else
                            sda_out <= '1'; 
                            state <= IDLE;
                        end if;
                    end if;

                when RECEIVE_DATA =>
                    if scl_rising = '1' then
                        shift_reg(bit_count) <= sda_d2;
                    end if;

                    if scl_falling = '1' then
                        if bit_count = 0 then
                            data_out <= shift_reg;
                            data_valid <= '1'; 
                            state <= ACK_DATA;
                        else
                            bit_count <= bit_count - 1;
                        end if;
                    end if;

                when TRANSMIT_DATA =>
                    if scl_falling = '1' then
                        sda_out <= shift_reg(bit_count);
                        if bit_count = 0 then
                            state <= ACK_DATA;
                        else
                            bit_count <= bit_count - 1;
                        end if;
                    end if;

                when ACK_DATA =>
                    if scl_falling = '1' then
                        sda_out <= '1'; 
                        state <= IDLE; 
                    end if;

            end case;
        end if;
    end if;
end process;



--process(clk)
--
--begin
--    if rising_edge(clk) then
--
--		start_detected <= '0';
--		stop_detected  <= '0';
--				
--		-- Si SCL está en estado alto se mira a ver como estaba y como está ahora SDA
--		if scl = '1' then
--			-- Si pasa de nivel alto a nivel bajo, bit de start
--			if sda_prev = '1' and sda_in = '0' then
--				start_detected <= '1';
--			-- Si pasa de nivel bajo a jivel alto, bit de stop
--			elsif sda_prev = '0' and sda_in = '1' then
--				stop_detected <= '1';
--			end if;
--			-- Si no es ninguno de estos casos, no hace nada
--		end if;
--
--		sda_prev <= sda_in;
--		scl_prev <= scl;
--
--    end if;
--end process;
--
---- Máquina de estados
--process(clk, reset)
--begin
--
--	if reset = '1' then
--		 state <= IDLE;
--		 sda_out <= '1';
--		 bit_count <= 7;
--		 data_valid <= '0';
--		 read_req <= '0';
--
--	elsif rising_edge(clk) then
--
--		case state is
--
--			when IDLE =>
--
--				 data_valid <= '0';
--				 read_req <= '0';
--
--				 if start_detected = '1' then
--					  state <= ADDRESS;
--					  bit_count <= 7;
--				 end if;
--
--			-- Lectura de dirección
--			when ADDRESS =>
--				-- Cuando SCL está a nivel alto se lee
--				if scl_prev = '0' and scl = '1' then
--				
--					shift_reg(bit_count) <= sda_in;
--					-- Cuando se llega al último bit es el de lectura/escritura 
--					if bit_count = 0 then
--						rw_bit <= sda_in;
--						state <= ACK_ADDRESS;
--					else
--						bit_count <= bit_count - 1;
--					end if;
--
--				end if;
--
--			-- ACK de dirección
--			when ACK_ADDRESS =>
--			
--				-- Se compara le dirección enviada con la del esclavo
--				if shift_reg(7 downto 1) = DIR_esclavo then
--					
--					sda_out <= '0';
--				
--					-- Si es nuestra dirección miramos si es para leer o escribir
--					if rw_bit = '0' then
--						state <= RECEIVE_DATA;
--					else
--					
--						-- Si es para recibir, se marca el aviso de que se quieren leer datos
--						state <= TRANSMIT_DATA;
--						read_req <= '1';
--						shift_reg <= data_in;
--					end if;
--
--					bit_count <= 7;
--
--				else
--					sda_out <= '1';
--					state <= IDLE;
--				end if;
--
--			-- Recibir datos del maestro
--			when RECEIVE_DATA =>
--
--				 if scl_prev = '0' and scl = '1' then
--
--					  shift_reg(bit_count) <= sda_in;
--
--					  if bit_count = 0 then
--					  -- Cuando se acaban de leer los datos, se marca el indicador
--							data_out <= shift_reg;
--							data_valid <= '1';
--							state <= ACK_DATA;
--					  else
--							bit_count <= bit_count - 1;
--					  end if;
--
--				 end if;
--
--			-- Enviar datos al maestro
--			when TRANSMIT_DATA =>
--
--				 if scl_prev = '1' and scl = '0' then
--					  sda_out <= shift_reg(bit_count);
--
--					  if bit_count = 0 then
--							state <= ACK_DATA;
--					  else
--							bit_count <= bit_count - 1;
--					  end if;
--
--				 end if;
--
--			-- ACK después de dato
--			when ACK_DATA =>
--
--				 sda_out <= '0';
--
--				 if stop_detected = '1' then
--					  state <= IDLE;
--					  sda_out <= '1';
--				 end if;
--
--			end case;
--
--	end if;
--
--end process;

end arch;