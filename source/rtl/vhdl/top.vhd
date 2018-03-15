-------------------------------------------------------------------------------
--  Department of Computer Engineering and Communications
--  Author: LPRS2  <lprs2@rt-rk.com>
--
--  Module Name: top
--
--  Description:
--
--    Simple test for VGA control
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity top is
  generic (
    RES_TYPE             : natural := 1;
    TEXT_MEM_DATA_WIDTH  : natural := 6;
    GRAPH_MEM_DATA_WIDTH : natural := 32
    );
  port (
    clk_i          : in  std_logic;
    reset_n_i      : in  std_logic;
    -- vga
    vga_hsync_o    : out std_logic;
    vga_vsync_o    : out std_logic;
    blank_o        : out std_logic;
    pix_clock_o    : out std_logic;
    psave_o        : out std_logic;
    sync_o         : out std_logic;
    red_o          : out std_logic_vector(7 downto 0);
    green_o        : out std_logic_vector(7 downto 0);
    blue_o         : out std_logic_vector(7 downto 0)
   );
end top;

architecture rtl of top is

  constant RES_NUM : natural := 6;

  type t_param_array is array (0 to RES_NUM-1) of natural;
  
  constant H_RES_ARRAY           : t_param_array := ( 0 => 64, 1 => 640,  2 => 800,  3 => 1024,  4 => 1152,  5 => 1280,  others => 0 );
  constant V_RES_ARRAY           : t_param_array := ( 0 => 48, 1 => 480,  2 => 600,  3 => 768,   4 => 864,   5 => 1024,  others => 0 );
  constant MEM_ADDR_WIDTH_ARRAY  : t_param_array := ( 0 => 12, 1 => 14,   2 => 13,   3 => 14,    4 => 14,    5 => 15,    others => 0 );
  constant MEM_SIZE_ARRAY        : t_param_array := ( 0 => 48, 1 => 4800, 2 => 7500, 3 => 12576, 4 => 15552, 5 => 20480, others => 0 ); 
  
  constant H_RES          : natural := H_RES_ARRAY(RES_TYPE);
  constant V_RES          : natural := V_RES_ARRAY(RES_TYPE);
  constant MEM_ADDR_WIDTH : natural := MEM_ADDR_WIDTH_ARRAY(RES_TYPE);
  constant MEM_SIZE       : natural := MEM_SIZE_ARRAY(RES_TYPE);
  
  constant SEKUNDA_TAKTOVA : std_logic_vector(27 downto 0):= "0000000000000000001111101000";  -- 1000       
  --constant SEKUNDA_TAKTOVA : std_logic_vector(27 downto 0):= "0000000111101000010010000000"; -- 2 000 000
  constant LOKACIJA_CHAR : std_logic_vector(13 downto 0):= "01001011000000"; -- 4800
  constant LOKACIJA_PIXEL : std_logic_vector(19 downto 0):= "00000010010110000000"; -- 9600

  component vga_top is 
    generic (
      H_RES                : natural := 640;
      V_RES                : natural := 480;
      MEM_ADDR_WIDTH       : natural := 32;
      GRAPH_MEM_ADDR_WIDTH : natural := 32;
      TEXT_MEM_DATA_WIDTH  : natural := 32;
      GRAPH_MEM_DATA_WIDTH : natural := 32;
      RES_TYPE             : integer := 1;
      MEM_SIZE             : natural := 4800
      );
    port (
      clk_i               : in  std_logic;
      reset_n_i           : in  std_logic;
      --
      direct_mode_i       : in  std_logic; -- 0 - text and graphics interface mode, 1 - direct mode (direct force RGB component)
      dir_red_i           : in  std_logic_vector(7 downto 0);
      dir_green_i         : in  std_logic_vector(7 downto 0);
      dir_blue_i          : in  std_logic_vector(7 downto 0);
      dir_pixel_column_o  : out std_logic_vector(10 downto 0);
      dir_pixel_row_o     : out std_logic_vector(10 downto 0);
      -- mode interface
      display_mode_i      : in  std_logic_vector(1 downto 0);  -- 00 - text mode, 01 - graphics mode, 01 - text & graphics
      -- text mode interface
      text_addr_i         : in  std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
      text_data_i         : in  std_logic_vector(TEXT_MEM_DATA_WIDTH-1 downto 0);
      text_we_i           : in  std_logic;
      -- graphics mode interface
      graph_addr_i        : in  std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
      graph_data_i        : in  std_logic_vector(GRAPH_MEM_DATA_WIDTH-1 downto 0);
      graph_we_i          : in  std_logic;
      --
      font_size_i         : in  std_logic_vector(3 downto 0);
      show_frame_i        : in  std_logic;
      foreground_color_i  : in  std_logic_vector(23 downto 0);
      background_color_i  : in  std_logic_vector(23 downto 0);
      frame_color_i       : in  std_logic_vector(23 downto 0);
      -- vga
      vga_hsync_o         : out std_logic;
      vga_vsync_o         : out std_logic;
      blank_o             : out std_logic;
      pix_clock_o         : out std_logic;
      vga_rst_n_o         : out std_logic;
      psave_o             : out std_logic;
      sync_o              : out std_logic;
      red_o               : out std_logic_vector(7 downto 0);
      green_o             : out std_logic_vector(7 downto 0);
      blue_o              : out std_logic_vector(7 downto 0)
    );
  end component;
  
  component ODDR2
  generic(
   DDR_ALIGNMENT : string := "NONE";
   INIT          : bit    := '0';
   SRTYPE        : string := "SYNC"
   );
  port(
    Q           : out std_ulogic;
    C0          : in  std_ulogic;
    C1          : in  std_ulogic;
    CE          : in  std_ulogic := 'H';
    D0          : in  std_ulogic;
    D1          : in  std_ulogic;
    R           : in  std_ulogic := 'L';
    S           : in  std_ulogic := 'L'
  );
  end component;
  
  constant update_period     : std_logic_vector(31 downto 0) := conv_std_logic_vector(1, 32);
  
  constant GRAPH_MEM_ADDR_WIDTH : natural := MEM_ADDR_WIDTH + 6;-- graphics addres is scales with minumum char size 8*8 log2(64) = 6
  
  -- text
  signal message_lenght      : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal graphics_lenght     : std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
  
  signal direct_mode         : std_logic;
  --
  signal font_size           : std_logic_vector(3 downto 0);
  signal show_frame          : std_logic;
  signal display_mode        : std_logic_vector(1 downto 0);  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
  signal foreground_color    : std_logic_vector(23 downto 0);
  signal background_color    : std_logic_vector(23 downto 0);
  signal frame_color         : std_logic_vector(23 downto 0);

  signal char_we             : std_logic;
  signal char_address        : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal char_value          : std_logic_vector(5 downto 0);

  signal pixel_address       : std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
  signal pixel_value         : std_logic_vector(GRAPH_MEM_DATA_WIDTH-1 downto 0);
  signal pixel_we            : std_logic;

  signal pix_clock_s         : std_logic;
  signal vga_rst_n_s         : std_logic;
  signal pix_clock_n         : std_logic;
   
  signal dir_red             : std_logic_vector(7 downto 0);
  signal dir_green           : std_logic_vector(7 downto 0);
  signal dir_blue            : std_logic_vector(7 downto 0);
  signal dir_pixel_column    : std_logic_vector(10 downto 0);
  signal dir_pixel_row       : std_logic_vector(10 downto 0);
  
  signal s_combined_color : std_logic_vector (23 downto 0);  -- rgb po 8 bita
  
  signal s_count_addr : std_logic_vector (MEM_ADDR_WIDTH-1 downto 0);
  signal s_count_addr_next : std_logic_vector (MEM_ADDR_WIDTH-1 downto 0);
  
  signal s_count_addr_pixel : std_logic_vector (19 downto 0);
  signal s_count_addr_pixel_next : std_logic_vector (19 downto 0);
  
  signal s_brojac_sec : std_logic_vector (27 downto 0);
  signal s_brojac_sec_next : std_logic_vector (27 downto 0);
  
  signal s_sekunda : std_logic;
  
  signal s_pomeraj : std_logic_vector (7 downto 0);
  signal s_pomeraj_next : std_logic_vector (7 downto 0);
  signal s_pomeri_za : std_logic_vector (7 downto 0);

begin

  -- calculate message lenght from font size
  message_lenght <= conv_std_logic_vector(MEM_SIZE/64, MEM_ADDR_WIDTH)when (font_size = 3) else -- note: some resolution with font size (32, 64)  give non integer message lenght (like 480x640 on 64 pixel font size) 480/64= 7.5
                    conv_std_logic_vector(MEM_SIZE/16, MEM_ADDR_WIDTH)when (font_size = 2) else
                    conv_std_logic_vector(MEM_SIZE/4 , MEM_ADDR_WIDTH)when (font_size = 1) else
                    conv_std_logic_vector(MEM_SIZE   , MEM_ADDR_WIDTH);
  
  graphics_lenght <= conv_std_logic_vector(MEM_SIZE*8*8, GRAPH_MEM_ADDR_WIDTH);
  
  -- Deo ZADATKA 1
  
  -- TODO: POGLEDATI top.ucf FAJL. Izmeniti po potrebi!
  -- removed to inputs pin
  direct_mode <= '0';
  display_mode     <= "11";  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
  
  font_size        <= x"1";
  show_frame       <= '0';
  foreground_color <= x"FFFFFF";
  background_color <= x"000000";
  frame_color      <= x"FF0000";

  clk5m_inst : ODDR2
  generic map(
    DDR_ALIGNMENT => "NONE",  -- Sets output alignment to "NONE","C0", "C1" 
    INIT => '0',              -- Sets initial state of the Q output to '0' or '1'
    SRTYPE => "SYNC"          -- Specifies "SYNC" or "ASYNC" set/reset
  )
  port map (
    Q  => pix_clock_o,       -- 1-bit output data
    C0 => pix_clock_s,       -- 1-bit clock input
    C1 => pix_clock_n,       -- 1-bit clock input
    CE => '1',               -- 1-bit clock enable input
    D0 => '1',               -- 1-bit data input (associated with C0)
    D1 => '0',               -- 1-bit data input (associated with C1)
    R  => '0',               -- 1-bit reset input
    S  => '0'                -- 1-bit set input
  );
  pix_clock_n <= not(pix_clock_s);

  -- component instantiation
  vga_top_i: vga_top
  generic map(
    RES_TYPE             => RES_TYPE,
    H_RES                => H_RES,
    V_RES                => V_RES,
    MEM_ADDR_WIDTH       => MEM_ADDR_WIDTH,
    GRAPH_MEM_ADDR_WIDTH => GRAPH_MEM_ADDR_WIDTH,
    TEXT_MEM_DATA_WIDTH  => TEXT_MEM_DATA_WIDTH,
    GRAPH_MEM_DATA_WIDTH => GRAPH_MEM_DATA_WIDTH,
    MEM_SIZE             => MEM_SIZE
  )
  port map(
    clk_i              => clk_i,
    reset_n_i          => reset_n_i,
    --
    direct_mode_i      => direct_mode,
    dir_red_i          => dir_red,
    dir_green_i        => dir_green,
    dir_blue_i         => dir_blue,
    dir_pixel_column_o => dir_pixel_column,
    dir_pixel_row_o    => dir_pixel_row,
    -- cfg
    display_mode_i     => display_mode,  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
    -- text mode interface
    text_addr_i        => char_address,
    text_data_i        => char_value,
    text_we_i          => char_we,
    -- graphics mode interface
    graph_addr_i       => pixel_address,
    graph_data_i       => pixel_value,
    graph_we_i         => pixel_we,
    -- cfg
    font_size_i        => font_size,
    show_frame_i       => show_frame,
    foreground_color_i => foreground_color,
    background_color_i => background_color,
    frame_color_i      => frame_color,
    -- vga
    vga_hsync_o        => vga_hsync_o,
    vga_vsync_o        => vga_vsync_o,
    blank_o            => blank_o,
    pix_clock_o        => pix_clock_s,
    vga_rst_n_o        => vga_rst_n_s,
    psave_o            => psave_o,
    sync_o             => sync_o,
    red_o              => red_o,
    green_o            => green_o,
    blue_o             => blue_o     
  );
  
  -- ZADATAK 1
  
  -- na osnovu signala iz vga_top modula dir_pixel_column i dir_pixel_row realizovati logiku koja genereise
  --dir_red
  --dir_green
  --dir_blue
  
  -- direct_mod 1
  
  -- http://avisynth.nl/index.php/ColorBars_theory
  s_combined_color <= x"b4b4b4" when ((dir_pixel_row >= 0) and (dir_pixel_row < 80)) else
					       x"b4b410" when ((dir_pixel_row >= 80) and (dir_pixel_row < 180)) else
						    x"10b4b4" when ((dir_pixel_row >= 160) and (dir_pixel_row < 240)) else
						    x"10b410" when ((dir_pixel_row >= 240) and (dir_pixel_row < 320)) else
						    x"b410b4" when ((dir_pixel_row >= 320) and (dir_pixel_row < 400)) else
						    x"b41010" when ((dir_pixel_row >= 400) and (dir_pixel_row < 480)) else
						    x"ebebeb" when ((dir_pixel_row >= 480) and (dir_pixel_row < 560)) else
						    x"101010" when ((dir_pixel_row >= 560) and (dir_pixel_row < 640)) else
						    x"101010";
						
  dir_red <= s_combined_color(23 downto 16);
  dir_green <= s_combined_color(15 downto 8);
  dir_blue <= s_combined_color(7 downto 0);
 
  -- ZADATAK 2
  
  -- koristeci signale realizovati logiku koja pise po TXT_MEM
  --char_address
  --char_value
  --char_we
  
  -- show_frame 0, direct_mod 0 i display_mod 00
  
  char_we <= '1';
  
  -- koristimo clock i reset od vga modula
  process (pix_clock_s, vga_rst_n_s) begin
		if(vga_rst_n_s = '0') then
			s_count_addr <= (others => '0');
		elsif (pix_clock_s'event and pix_clock_s = '1') then
			s_count_addr <= s_count_addr_next;
		end if;
  end process;
  
  process (s_count_addr, s_count_addr_next) begin
		-- 80x60
		if (s_count_addr_next = LOKACIJA_CHAR) then
			s_count_addr_next <= (others => '0');
		else
			s_count_addr_next <= s_count_addr + 1;
		end if;
  end process;
  
  char_address <= s_count_addr;
  
  char_value <= "000001" when (char_address = (("00" & x"000") + ("000000" & s_pomeri_za))) else -- a
					 "001100" when (char_address = (("00" & x"001") + ("000000" & s_pomeri_za))) else -- l
					 "000101" when (char_address = (("00" & x"002") + ("000000" & s_pomeri_za))) else -- e
					 "001011" when (char_address = (("00" & x"003") + ("000000" & s_pomeri_za))) else -- k
					 "010011" when (char_address = (("00" & x"004") + ("000000" & s_pomeri_za))) else -- s
					 "000001" when (char_address = (("00" & x"005") + ("000000" & s_pomeri_za))) else -- a
					 "100000" when (char_address = (("00" & x"006") + ("000000" & s_pomeri_za))) else -- razmak
					 "010010" when (char_address = (("00" & x"007") + ("000000" & s_pomeri_za))) else -- r
 					 "000001" when (char_address = (("00" & x"008") + ("000000" & s_pomeri_za))) else -- a
					 "110010" when (char_address = (("00" & x"009") + ("000000" & s_pomeri_za))) else -- 2
					 "110001" when (char_address = (("00" & x"00A") + ("000000" & s_pomeri_za))) else -- 1
					 "111000" when (char_address = (("00" & x"00B") + ("000000" & s_pomeri_za))) else -- 8
					 "100000";
					 
  -- ZADATAK 3 i 5, objedinjeni pomerac
  
  -- FIXME: Brojanje sekundi nije bas po satu. 1s != 7s
  -- napraviti brojac od 0 do 2 000 000 za jednu sekundu
  process (pix_clock_s, vga_rst_n_s) begin
		if(vga_rst_n_s = '0') then
			s_brojac_sec <= (others => '0');
		elsif (pix_clock_s'event and pix_clock_s = '1') then
			s_brojac_sec <= s_brojac_sec_next;
		end if;
  end process;
  
  process (s_brojac_sec, s_brojac_sec_next) begin
		-- 2 000 000
		if (s_brojac_sec_next = SEKUNDA_TAKTOVA) then
			s_brojac_sec_next <= (others => '0');
		else
			s_brojac_sec_next <= s_brojac_sec + 1;
		end if;
  end process;
  
  -- realizovati logiku koja kada otkucamo 1s postavi flag na 1
  s_sekunda <= '1' when (s_brojac_sec = SEKUNDA_TAKTOVA) else 
               '0';
  
  -- tu vrednost dodati char_value adresi
  process (pix_clock_s, vga_rst_n_s) begin
		if(vga_rst_n_s = '0') then
			s_pomeraj <= (others => '0');
		elsif (pix_clock_s'event and pix_clock_s = '1') then
			s_pomeraj <= s_pomeraj_next;
		end if;
  end process;
  
  process (s_pomeraj, s_pomeraj_next, s_sekunda) begin
		-- pomeraj za X mesta
		if (s_pomeraj_next = "00001010") then
			s_pomeraj_next <= (others => '0');
		elsif (s_sekunda = '1') then
		  s_pomeraj_next <= s_pomeraj + 1;
		else
		  s_pomeraj_next <= s_pomeraj;
		end if;
  end process;
  
  s_pomeri_za <= s_pomeraj;
  
  -- koristeci signale realizovati logiku koja pise po GRAPH_MEM
  --pixel_address
  --pixel_value
  --pixel_we
  
  -- show_frame 0, direct_mod 0 i display_mod 10
  
  pixel_we <= '1';
  
  -- osvezavanje adresa
  process (pix_clock_s, vga_rst_n_s) begin
		if(vga_rst_n_s = '0') then
			s_count_addr_pixel <= (others => '0');
		elsif (pix_clock_s'event and pix_clock_s = '1') then
			s_count_addr_pixel <= s_count_addr_pixel_next;
		end if;
  end process;
  
  process (s_count_addr_pixel, s_count_addr_pixel_next) begin
		-- 20*480
		if (s_count_addr_pixel_next = LOKACIJA_PIXEL) then
			s_count_addr_pixel_next <= (others => '0');
		else
			s_count_addr_pixel_next <= s_count_addr_pixel + 1;
		end if;
  end process;
  
  pixel_address <= s_count_addr_pixel;
  
  -- dodela vrednosti. pravimo kvadrat na sredini ekrana
  -- vrednost adrese dobijamo: red*20 + kolona
  
  pixel_value <= (others => '1') when (pixel_address = (x"0127A" + (x"000" & s_pomeri_za))) else
					  (others => '1') when (pixel_address = (x"0128E" + (x"000" & s_pomeri_za))) else
					  (others => '1') when (pixel_address = (x"012A2" + (x"000" & s_pomeri_za))) else
					  (others => '1') when (pixel_address = (x"012B6" + (x"000" & s_pomeri_za))) else
					  (others => '1') when (pixel_address = (x"012CA" + (x"000" & s_pomeri_za))) else
					  (others => '1') when (pixel_address = (x"012DE" + (x"000" & s_pomeri_za))) else
					  (others => '1') when (pixel_address = (x"012F2" + (x"000" & s_pomeri_za))) else
					  (others => '1') when (pixel_address = (x"01306" + (x"000" & s_pomeri_za))) else
					  (others => '0');
 
end rtl;