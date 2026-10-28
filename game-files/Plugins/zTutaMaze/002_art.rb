#===============================================================================
# Tuta maze - art. Adi's PNGs are used only at their exact size (SIZES); otherwise a
# drawn fallback of the same layout. Maze, HUD, panels and VFX are always procedural.
#===============================================================================

module TutaMaze
  module Art
    PICTURES = "Graphics/Pictures/Tuta/"
    SIZES = {
      "tuta_run" => [128, 128], "tuta_poses" => [128, 128], "owner_man_run" => [128, 160],
      "owner_woman_run" => [128, 160], "owner_poses" => [96, 80], "berries" => [64, 16],
      "tuta_win" => [256, 192], "tuta_lose" => [256, 192]
    }.freeze
    STATUE = ["Graphics/Characters/tuta_statue", 192, 320].freeze   # map event sheet, 4x4 of 48x80
    TILE = 24
    ORIGIN = [4, 24].freeze      # playfield offset; the HUD is y 0-23
    RUN_CELL = [32, 32].freeze
    POSE_CELL = 64
    OWNER_CELL = [32, 40].freeze
    BERRY = 16
    ROW = { down: 0, left: 1, right: 2, up: 3 }.freeze
    # Palette (spec): walls, floor, couch.
    WALL = [60, 36, 36].freeze        # #3C2424
    WALL_EDGE = [216, 138, 59].freeze # #D88A3B
    WALL_SHADOW = [36, 36, 36].freeze # #242424
    FLOOR = [26, 20, 32].freeze       # #1A1420
    SOFA = [122, 42, 58].freeze       # #7A2A3A
    SOFA_DARK = [90, 30, 42].freeze   # #5A1E2A
    DOOR = [232, 160, 176].freeze
    OUTLINE = [20, 20, 20].freeze     # #141414
    T_WHITE = [242, 236, 220].freeze
    T_BLACK = [28, 28, 28].freeze
    T_EYE = [168, 184, 200].freeze
    TONGUE = [224, 122, 138].freeze
    MAN_SHIRT = [181, 72, 63].freeze
    MAN_HAIR = [42, 32, 24].freeze
    MAN_SKIN = [210, 145, 103].freeze
    WOMAN_TOP = [79, 114, 184].freeze
    WOMAN_HAIR = [107, 74, 46].freeze
    WOMAN_SKIN = [228, 156, 108].freeze
    JEANS = [34, 58, 92].freeze
    BERRY_RED = [224, 64, 60].freeze
    BERRY_DARK = [168, 42, 44].freeze
    SEED = [248, 216, 104].freeze
    LEAF = [95, 154, 108].freeze
    GOLD = [248, 216, 104].freeze
    GOLD_DARK = [181, 132, 46].freeze
    GOLD_LIGHT = [255, 244, 176].freeze
    HEART = [224, 64, 96].freeze
    INK = [24, 18, 28].freeze
    TEXT = [248, 240, 224].freeze

    def self.color(rgb, alpha = 255)
      Color.new(rgb[0], rgb[1], rgb[2], alpha)
    end

    def self.mix(a, b, s)
      a.each_index.map { |i| (a[i] + (b[i] - a[i]) * s).round }
    end

    # The PNG when it exists at its exact canvas size; nil otherwise (the caller falls back).
    def self.picture(name)
      path = defined?(pbResolveBitmap) ? pbResolveBitmap(PICTURES + name) : nil
      return nil unless path
      bmp = Bitmap.new(path)
      return bmp if [bmp.width, bmp.height] == SIZES[name]
      echoln("[TutaMaze] #{name}.png is #{bmp.width}x#{bmp.height}, want #{SIZES[name].join('x')}: fallback") if defined?(echoln)
      bmp.dispose
      nil
    end

    # Always a bitmap of the SIZES layout: the PNG, or the drawn fallback.
    def self.sheet(name)
      picture(name) || send("fallback_#{name}")
    end

    def self.screen_of(x, y)
      [ORIGIN[0] + (x * TILE).round + TILE / 2, ORIGIN[1] + (y * TILE).round + TILE / 2]
    end

    #--- primitives -------------------------------------------------------------
    def self.disc(bmp, cx, cy, r, rgb)
      (-r..r).each do |dy|
        w = Math.sqrt(r * r - dy * dy).floor
        bmp.fill_rect(cx - w, cy + dy, w * 2 + 1, 1, color(rgb))
      end
    end

    def self.blob(bmp, cx, cy, r, rgb)
      disc(bmp, cx, cy, r + 1, OUTLINE)
      disc(bmp, cx, cy, r, rgb)
    end

    def self.heart(bmp, x, y, s, rgb)
      disc(bmp, x + s, y + s, s, rgb)
      disc(bmp, x + 3 * s, y + s, s, rgb)
      (0..2 * s).each { |i| bmp.fill_rect(x + i, y + s + i, [4 * s + 1 - 2 * i, 1].max, 1, color(rgb)) }
    end

    #--- fallbacks (same layout as the PNGs) ---------------------------------------
    def self.dog(bmp, cx, cy, s, dir)
      blob(bmp, cx, cy + 3 * s, 5 * s, T_WHITE)
      blob(bmp, cx, cy - 2 * s, 5 * s, T_WHITE)
      disc(bmp, cx - 5 * s, cy - 2 * s, 2 * s, T_BLACK)
      disc(bmp, cx + 5 * s, cy - 2 * s, 2 * s, T_BLACK)
      return if dir == :up
      bmp.fill_rect(cx - 4 * s, cy - 3 * s, 8 * s, 2 * s, color(T_BLACK))
      bmp.fill_rect(cx - s / 2, cy - 6 * s, [s, 1].max, 4 * s, color(T_WHITE))
      bmp.fill_rect(cx + 2 * s, cy - 3 * s, [s, 1].max * 2, [s, 1].max * 2, color(T_EYE))
      bmp.fill_rect(cx - s, cy, 2 * s, s, color(T_BLACK))
      tick = { down: [0, 1], left: [-1, 0], right: [1, 0] }[dir] || [0, 1]
      bmp.fill_rect(cx + tick[0] * 7 * s - s, cy + 6 * s + tick[1] * 2 * s, 2 * s, 2 * s, color(TONGUE))
    end

    def self.fallback_tuta_run
      bmp = Bitmap.new(*SIZES["tuta_run"])
      ROW.each { |dir, r| 4.times { |f| dog(bmp, f * 32 + 16, r * 32 + 15 + (f.odd? ? -1 : 0), 2, dir) } }
      bmp
    end

    def self.fallback_tuta_poses
      bmp = Bitmap.new(*SIZES["tuta_poses"])
      blob(bmp, 32, 50, 12, BERRY_RED)
      dog(bmp, 32, 26, 3, :down)
      dog(bmp, 96, 30, 4, :down)
      dog(bmp, 32, 94, 4, :down)
      bmp.fill_rect(24, 104, 16, 4, color(BERRY_DARK))
      dog(bmp, 96, 94, 4, :down)
      blob(bmp, 96, 116, 6, BERRY_RED)
      bmp
    end

    def self.person(bmp, cx, top, top_rgb, hair_rgb, skin_rgb, curls)
      bmp.fill_rect(cx - 6, top + 30, 5, 9, color(JEANS))
      bmp.fill_rect(cx + 1, top + 30, 5, 9, color(JEANS))
      bmp.fill_rect(cx - 8, top + 16, 16, 15, color(OUTLINE))
      bmp.fill_rect(cx - 7, top + 17, 14, 13, color(top_rgb))
      disc(bmp, cx, top + 8, curls ? 9 : 8, hair_rgb)
      blob(bmp, cx, top + 10, 6, skin_rgb)
    end

    def self.owner_fallback(top_rgb, hair_rgb, skin_rgb, curls)
      bmp = Bitmap.new(*SIZES["owner_man_run"])
      4.times { |r| 4.times { |f| person(bmp, f * 32 + 16, r * 40 + (f.odd? ? 0 : 1), top_rgb, hair_rgb, skin_rgb, curls) } }
      bmp
    end

    def self.fallback_owner_man_run = owner_fallback(MAN_SHIRT, MAN_HAIR, MAN_SKIN, false)
    def self.fallback_owner_woman_run = owner_fallback(WOMAN_TOP, WOMAN_HAIR, WOMAN_SKIN, true)

    def self.fallback_owner_poses
      bmp = Bitmap.new(*SIZES["owner_poses"])
      [[MAN_SHIRT, MAN_HAIR, MAN_SKIN, false], [WOMAN_TOP, WOMAN_HAIR, WOMAN_SKIN, true]].each_with_index do |look, r|
        3.times do |c|
          person(bmp, c * 32 + 16, r * 40 + 1, *look)
          heart(bmp, c * 32 + 10, r * 40 + 1, 2, HEART) if c > 0
        end
      end
      bmp
    end

    def self.fallback_berries
      bmp = Bitmap.new(*SIZES["berries"])
      [[BERRY_RED, 6], [BERRY_RED, 5], [GOLD, 6], [GOLD_LIGHT, 6]].each_with_index do |(rgb, r), i|
        blob(bmp, i * 16 + 8, 9, r, rgb)
        bmp.fill_rect(i * 16 + 5, 2, 6, 2, color(LEAF))
      end
      bmp
    end

    def self.card_fallback(top, bottom, win)
      bmp = Bitmap.new(*SIZES["tuta_win"])
      192.times { |y| bmp.fill_rect(0, y, 256, 1, color(mix(top, bottom, y / 191.0))) }
      if win
        12.times { |i| disc(bmp, 40 + (i * 37) % 180, 120 - (i % 4) * 12, 10, BERRY_RED) }
      else
        blob(bmp, 90, 80, 22, MAN_SKIN)
        blob(bmp, 170, 80, 22, WOMAN_SKIN)
      end
      dog(bmp, 128, 70, 4, :down)
      bmp
    end

    def self.fallback_tuta_win = card_fallback([58, 42, 74], [216, 138, 59], true)
    def self.fallback_tuta_lose = card_fallback([40, 30, 52], [122, 42, 58], false)

    #--- procedural ---------------------------------------------------------------
    def self.maze
      r = TutaMazeRules
      bmp = Bitmap.new(r::W * TILE, r::H * TILE)
      bmp.fill_rect(0, 0, bmp.width, bmp.height, color(FLOOR))
      r::H.times do |y|
        r::W.times do |x|
          ch = r::ROWS[y][x]
          px, py = x * TILE, y * TILE
          case ch
          when "#" then wall(bmp, x, y, px, py)
          when "H"
            bmp.fill_rect(px, py + 4, TILE, TILE - 6, color(SOFA_DARK))
            bmp.fill_rect(px + 1, py + 6, TILE - 2, TILE - 12, color(SOFA))
            bmp.fill_rect(px + TILE / 2, py + 8, 1, TILE - 16, color(SOFA_DARK))
          when "-" then bmp.fill_rect(px, py + TILE / 2 - 2, TILE, 4, color(DOOR))
          end
        end
      end
      bmp
    end

    def self.wall(bmp, x, y, px, py)
      r = TutaMazeRules
      bmp.fill_rect(px, py, TILE, TILE, color(WALL))
      floor = ->(dx, dy) { r.cell(x + dx, y + dy) != "#" }
      bmp.fill_rect(px, py, TILE, 2, color(WALL_EDGE)) if y > 0 && floor.(0, -1)
      bmp.fill_rect(px, py + TILE - 2, TILE, 2, color(WALL_EDGE)) if y < r::H - 1 && floor.(0, 1)
      bmp.fill_rect(px, py, 2, TILE, color(WALL_EDGE)) if x > 0 && floor.(-1, 0)
      bmp.fill_rect(px + TILE - 2, py, 2, TILE, color(WALL_EDGE)) if x < r::W - 1 && floor.(1, 0)
      bmp.fill_rect(px + 2, py + TILE - 4, TILE - 4, 2, color(WALL_SHADOW)) if y < r::H - 1 && floor.(0, 1)
    end

    def self.sparkle_frames
      bmp = Bitmap.new(64, 16)
      4.times do |f|
        len = [2, 5, 7, 4][f]
        bmp.fill_rect(f * 16 + 8 - len, 7, len * 2, 2, color(GOLD_LIGHT))
        bmp.fill_rect(f * 16 + 7, 8 - len, 2, len * 2, color(GOLD_LIGHT))
      end
      bmp
    end

    def self.aura
      bmp = Bitmap.new(40, 40)
      (4..19).step(3) { |rr| disc(bmp, 20, 20, 20 - rr / 2, mix(GOLD, [255, 255, 255], rr / 20.0)) }
      bmp
    end
  end
end
