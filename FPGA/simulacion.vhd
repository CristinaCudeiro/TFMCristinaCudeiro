library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- La entidad de un testbench siempre está vacía
entity simulacion is
end simulacion;

architecture sim_arch of simulacion is

    -- Señales para conectar con nuestro módulo
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal scl   : std_logic := '1';
    signal sda   : std_logic := 'Z';
    
    -- Constantes de tiempo
    constant CLK_PERIOD : time := 20 ns;     -- Reloj de 50 MHz de la DE10-Lite
    constant T_HALF_SCL : time := 1250 ns;   -- Medio periodo para I2C a 400 kHz

begin

    -- 1. Instanciamos el módulo que queremos probar (Unit Under Test)
    uut: entity work.Acelerometro
        port map(
            clk   => clk,
            reset => reset,
            scl   => scl,
            sda   => sda
        );

    -- 2. Generador del reloj maestro (50 MHz)
    clk <= not clk after CLK_PERIOD / 2;

    -- 3. Simulamos la resistencia Pull-Up del bus I2C físico
    sda <= 'H'; 

    -- 4. Proceso principal que actúa como el MAESTRO I2C
    process
    
        -- Subrutina para generar la condición de START
        procedure i2c_start is
        begin
            scl <= '1'; sda <= 'Z'; wait for T_HALF_SCL;
            sda <= '0';             wait for T_HALF_SCL; -- SDA baja mientras SCL es alto
            scl <= '0';             wait for T_HALF_SCL;
        end procedure;

        -- Subrutina para generar la condición de STOP
        procedure i2c_stop is
        begin
            sda <= '0'; wait for T_HALF_SCL;
            scl <= '1'; wait for T_HALF_SCL;
            sda <= 'Z'; wait for T_HALF_SCL; -- SDA sube mientras SCL es alto
        end procedure;

        -- Subrutina para enviar 1 byte (y leer el ACK del esclavo)
        procedure i2c_write(data : std_logic_vector(7 downto 0)) is
        begin
            for i in 7 downto 0 loop
                if data(i) = '1' then
                    sda <= 'Z'; -- Dejamos que el pull-up lo ponga a 1
                else
                    sda <= '0'; -- Tiramos el bus a 0
                end if;
                wait for T_HALF_SCL;
                scl <= '1'; wait for T_HALF_SCL * 2; -- Pulso de reloj alto
                scl <= '0'; wait for T_HALF_SCL;
            end loop;
            
            -- Ciclo 9: Soltamos el bus para leer el ACK del esclavo
            sda <= 'Z'; 
            wait for T_HALF_SCL;
            scl <= '1'; wait for T_HALF_SCL * 2;
            scl <= '0'; wait for T_HALF_SCL;
        end procedure;

        -- Subrutina para leer 1 byte (y enviar un NACK al final)
        procedure i2c_read_and_nack is
        begin
            sda <= 'Z'; -- Soltamos SDA para que el esclavo escriba
            for i in 7 downto 0 loop
                wait for T_HALF_SCL;
                scl <= '1'; wait for T_HALF_SCL * 2; -- Leemos en este momento
                scl <= '0'; wait for T_HALF_SCL;
            end loop;
            
            -- Ciclo 9: Enviamos un NACK (dejamos SDA en alto)
            sda <= 'Z'; 
            wait for T_HALF_SCL;
            scl <= '1'; wait for T_HALF_SCL * 2;
            scl <= '0'; wait for T_HALF_SCL;
        end procedure;

    begin
        -- INICIO DE LA SIMULACIÓN
        -- Mantenemos el reset un momento y lo liberamos
        wait for 100 ns;
        reset <= '0';
        wait for 5 us;

        -- =================================================================
        -- SECUENCIA DE LECTURA DE 1 BYTE (Según Datasheet del MPU-3300)
        -- =================================================================
        
        -- 1. Condición de START
        i2c_start;
        
        -- 2. Enviar Dirección Esclavo + Bit de Escritura (1101000 + 0 = 0xD0)
        i2c_write(x"D0");
        
        -- 3. Enviar Dirección del Registro que queremos leer (Ej. 0x28, X_L)
        i2c_write(x"28");
        
        -- 4. START REPETIDO (Repeated Start)
        i2c_start;
        
        -- 5. Enviar Dirección Esclavo + Bit de Lectura (1101000 + 1 = 0xD1)
        i2c_write(x"D1");
        
        -- 6. Leer el dato devuelto por el esclavo y responder con NACK
        i2c_read_and_nack;
        
        -- 7. Condición de STOP
        i2c_stop;

        -- Fin de la prueba. Detenemos el proceso infinito.
        wait;
        
    end process;

end sim_arch;