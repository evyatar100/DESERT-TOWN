#===============================================================================
# TempleStickers - data tables (Michal's final 12 signs, docs/research/
# temple-activities-concepts.md "Final signs and stickers").
#===============================================================================

module TempleStickers
  HONOREES = %w[kusama yonath curry parton].freeze

  # One board per honoree. The prompt follows the board, not the sticker.
  BOARDS = {
    "kusama" => { prompt_key: "TEMPLE_PROMPT_KUSAMA" },
    "yonath" => { prompt_key: "TEMPLE_PROMPT_YONATH" },
    "curry"  => { prompt_key: "TEMPLE_PROMPT_CURRY" },
    "parton" => { prompt_key: "TEMPLE_PROMPT_PARTON" }
  }.freeze

  # Sticker id == sign id (sign key TEMPLE_SIGN_<id>). map/x/y are for phase 2.
  # shape/color drive the placeholder art in 005_art.rb only.
  STICKERS = {
    "KUSAMA_DOT"     => { honoree: "kusama", map: 113, x: 3,  y: 10, shape: :circle,   color: [200, 40, 40] },
    "KUSAMA_MIRROR"  => { honoree: "kusama", map: 96,  x: 25, y: 32, shape: :ring,     color: [200, 40, 40] },
    "KUSAMA_PUMPKIN" => { honoree: "kusama", map: 96,  x: 23, y: 16, shape: :blob,     color: [220, 180, 40] },
    "YONATH_CRYSTAL" => { honoree: "yonath", map: 113, x: 4,  y: 17, shape: :diamond,  color: [120, 170, 230] },
    "YONATH_BEAR"    => { honoree: "yonath", map: 96,  x: 14, y: 35, shape: :blob,     color: [235, 235, 245] },
    "YONATH_KEY"     => { honoree: "yonath", map: 96,  x: 18, y: 16, shape: :square,   color: [79, 114, 184] },
    "CURRY_HEEL"     => { honoree: "curry",  map: 113, x: 10, y: 9,  shape: :triangle, color: [40, 40, 48] },
    "CURRY_BUBBLE"   => { honoree: "curry",  map: 96,  x: 12, y: 24, shape: :circle,   color: [140, 60, 160] },
    "CURRY_TICKET"   => { honoree: "curry",  map: 96,  x: 17, y: 43, shape: :square,   color: [181, 72, 63] },
    "PARTON_BOOK"    => { honoree: "parton", map: 113, x: 10, y: 15, shape: :square,   color: [216, 138, 59] },
    "PARTON_NAILS"   => { honoree: "parton", map: 96,  x: 12, y: 47, shape: :triangle, color: [230, 90, 170] },
    "PARTON_SONG"    => { honoree: "parton", map: 96,  x: 25, y: 27, shape: :diamond,  color: [216, 170, 59] }
  }.freeze

  PAGE_COLS = 7
  PAGE_ROWS = 4
  PAGE_CELLS = PAGE_COLS * PAGE_ROWS
  NAME_MAX = 12
  SENTENCE_MAX = 40
  CODE_MAX = 12
  # A tab is one Inception depth; a full tab grows another sheet (page).
  MAX_PAGES_PER_BOARD = 300
  WALL_FILE = "temple_wall.dat"
  STAFF_FILE = "temple_staff.cfg"

  def self.stickers_for(honoree)
    STICKERS.select { |_id, s| s[:honoree] == honoree }.keys
  end

  def self.home_board(sticker_id)
    s = STICKERS[sticker_id]
    s ? s[:honoree] : nil
  end

  def self.board?(board)
    BOARDS.key?(board.to_s)
  end

  # Current Inception depth (survives Game.start_new); 0 outside the arcade plugin.
  def self.depth
    defined?(DesertTownArcade) ? DesertTownArcade.depth.to_i : 0
  end

  # Same folder as Game.rxdata (SaveData::FILE_PATH falls back to "." too).
  def self.data_dir
    if defined?(System) && System.respond_to?(:data_directory) && File.directory?(System.data_directory)
      return System.data_directory
    end
    "."
  end
end
