----------------------------------------------------------------------------------
-- Created for: UB EE478
-- Engineer: Serena LaFave
-- Create Date: 12/02/2019 04:46:44 PM
-- Project Name: Song Recorder with Playback Function
-- Target Devices: xc7z010clg400-1
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FinalProject is
  Port (clk : in STD_LOGIC;
        mode : in STD_LOGIC;
        btn0 : in STD_LOGIC;
        btn1 : in STD_LOGIC;
        btn2 : in STD_LOGIC;
        btn3 : in STD_LOGIC;
        light: out STD_LOGIC_VECTOR(3 downto 0);
        mclk : out STD_LOGIC;
        bclk : out STD_LOGIC;
        mute : out STD_LOGIC;
        pbdat : out STD_LOGIC;
        pblrc : out STD_LOGIC);
end FinalProject;

architecture Behavioral of FinalProject is

component ssm2603_i2s
  port (clk: in std_logic;
        r_data: in std_logic_vector(23 downto 0);
        l_data: in std_logic_vector(23 downto 0);
        bclk: out std_logic;
        pbdat: out std_logic;
        pblrc: out std_logic;
        mclk: out std_logic;
        mute: out std_logic;
        ready: out std_logic);
end component;

-- Audio Codec (SSM2603)
signal r_data, l_data: std_logic_vector(23 downto 0);
signal mclk_sig: std_logic;
signal ready: std_logic;

-- 4 Hz clock
signal clk4: std_logic;
signal clk4_cnt: integer range 0 to 3071500 := 0;

-- Audio square waves
signal tone_terminal_count, tone_counter: integer range 0 to 100;

-- Notes
constant N0: integer range 0 to 100 := 97; -- C5
constant N1: integer range 0 to 100 := 82; -- D5
constant N2: integer range 0 to 100 := 73; -- E5
constant N3: integer range 0 to 100 := 69; -- F5

-- Recording mode (mode = 0)
type recording_stream is array(39 downto 0) of integer range 0 to 100;
signal rec_cnt: integer range 0 to 50 := 0;
signal rec_arr: recording_stream := (others => 0);
type rec_state_type is (REC_IDLE, RECORDING);
signal rec_state: rec_state_type := REC_IDLE;

-- Playback mode (mode = 1)
signal play_cnt: integer range 0 to 50 := 0;
type play_state_type is (PLAY_IDLE, PLAYING);
signal play_state: play_state_type := PLAY_IDLE;

-- LEDs
signal light_sig: std_logic_vector(3 downto 0) := "0000";
signal light_cnt: integer range 0 to 5 := 0;

------------------------------------------------------------

begin

codec: ssm2603_i2s port map(
    clk => clk,
    mclk => mclk_sig,
    bclk => bclk,
    mute => mute,
    pblrc => pblrc,
    pbdat => pbdat,
    l_data => l_data,
    r_data => r_data,
    ready => ready
);

mclk <= mclk_sig;

-- 4 Hz clock
slow_clock_proc: process(mclk_sig)
begin
    if rising_edge(mclk_sig) then
        if clk4_cnt = 3071500 then
            clk4 <= '1';
            clk4_cnt<= 0;
        else
            clk4 <= '0';
            clk4_cnt <= clk4_cnt + 1;
        end if;
    end if;
end process;

-- Tone counter
tone_counter_proc: process(mclk_sig)
begin
    if rising_edge(mclk_sig) then
        if ready = '1' then
            if tone_counter = tone_terminal_count then
                tone_counter <= 0;
            else
                tone_counter <= tone_counter + 1;
            end if;
        end if;
    end if;
end process;

-- Note Data
l_data <= (others => '0') when (tone_terminal_count = 0)
        OR (tone_counter < (tone_terminal_count/2))
    else x"0FFFFF";

r_data <= (others => '0') when (tone_terminal_count = 0)
        OR (tone_counter < (tone_terminal_count/2))
    else x"0FFFFF";

-- Modes
mode_proc: process(mclk_sig)
begin
    if rising_edge(mclk_sig) then
        if mode = '0' then -- Recording mode
            play_state <= PLAY_IDLE;
            case rec_state is
                when REC_IDLE =>
                    light_sig <= "1010";
                    light_cnt <= 0;
                    rec_cnt <= 0;
                    tone_terminal_count <= 0;
                    if (btn0 OR btn1 OR btn2 OR btn3) = '1' then
                        rec_arr <= (others => 0);
                        light_sig <= "1111";
                        rec_state <= RECORDING;                        
                    end if;
                when RECORDING =>
                    if clk4 = '1' then
                        if rec_cnt <= rec_arr'length then
                            if light_cnt = 5 then
                                light_sig <= NOT light_sig;
                                light_cnt <= 0;
                            else
                                light_cnt <= light_cnt + 1;
                            end if;
                            if btn3 = '1' then 
                                tone_terminal_count <= N0;
                                rec_arr(rec_cnt) <= N0;
                            elsif btn2 = '1' then
                                tone_terminal_count <= N1;
                                rec_arr(rec_cnt) <= N1;
                            elsif btn1 = '1' then
                                tone_terminal_count <= N2;                  
                                rec_arr(rec_cnt) <= N2;
                            elsif btn0 = '1' then
                                tone_terminal_count <= N3;
                                rec_arr(rec_cnt) <= N3;
                            else
                                tone_terminal_count <= 0;
                                rec_arr(rec_cnt) <= 0;                               
                            end if;
                            rec_cnt <= rec_cnt + 1; 
                            
                        else
                            tone_terminal_count <= 0;
                            rec_state <= REC_IDLE;
                        end if;
                    end if;
            end case; -- recording state
        elsif mode = '1' then -- Playback mode
            rec_state <= REC_IDLE;
            case play_state is
                when PLAY_IDLE =>
                    light_sig <= "1010";
                    play_cnt <= 0;
                    if (btn0 OR btn1 OR btn2 OR btn3) = '1' then
                        play_state <= PLAYING;
                    end if;
                when PLAYING =>
                    light_sig <= "1111";
                    if clk4 = '1' then
                        -- note playing
                        if play_cnt <= rec_arr'length then
                            tone_terminal_count <= rec_arr(play_cnt);
                            play_cnt <= play_cnt + 1;
                        else
                            tone_terminal_count <= 0;
                            play_state <= PLAY_IDLE;
                        end if;
                    end if;
            end case; -- playback state
        end if; -- mode
    end if; -- rising_edge
end process;

light <= light_sig;

end Behavioral;
