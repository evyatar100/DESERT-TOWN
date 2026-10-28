#===============================================================================
# DJ Rush Hour - art. Adi's PNGs are used only at their exact size (SIZES); otherwise a
# drawn fallback of the same layout. Pieces are composited from party charsets (D6).
#===============================================================================

module DJRush
  module Art
    PICTURES = "Graphics/Pictures/DJRush/"
    SIZES = { "dj_poses" => [128, 192], "car_piece" => [96, 48] }.freeze
    CAR_SHEET = "Graphics/Characters/djrush_car"
    CAR_SIZE = [384, 384].freeze
    CAR_FRAME = 96
    MAP_GRAPHIC = "djrush_car"
    MAP_FALLBACK = "dt_fc898478"
    CHARSETS = "Graphics/Characters/dt_"
    CHARSET_SIZE = [128, 192].freeze
    FW = 32
    FH = 48
    CELL = 48
    POSE = [64, 96].freeze
    ROW = { down: 0, left: 1, right: 2, up: 3 }.freeze
    OUTLINE = [20, 20, 20].freeze      # #141414
    NIGHT = [26, 20, 32].freeze        # #1A1420
    FLOOR = [40, 30, 48].freeze
    GRID = [52, 40, 62].freeze
    WOOD = [122, 82, 48].freeze
    WOOD_DARK = [84, 54, 30].freeze
    COUPLE = [224, 122, 138].freeze   # #E07A8A
    CONGA = [232, 150, 74].freeze     # #E8964A
    QUEUE = [79, 114, 184].freeze     # #4F72B8
    SLEEP_BAGS = [[95, 154, 108], [154, 98, 176], [64, 160, 168], [196, 150, 64]].freeze
    HEART = [224, 64, 96].freeze
    ROPE = [200, 170, 90].freeze
    YELLOW = [248, 216, 104].freeze
    WHITE = [242, 240, 232].freeze
    INK = [24, 18, 28].freeze
    TEXT = [248, 240, 224].freeze
    WOOL = [242, 236, 220].freeze
    WOOL_DARK = [200, 192, 176].freeze
    FACE = [42, 42, 42].freeze
    SPEAKER = [28, 28, 28].freeze
    RIM = [122, 122, 128].freeze
    LIGHTS = [[224, 64, 112], [64, 160, 240], [96, 224, 112], [248, 216, 104]].freeze
    LIGHT_OFF = [60, 60, 60].freeze
    JERSEY = [47, 79, 168].freeze
    JERSEY_Y = [242, 194, 48].freeze
    HAIR = [90, 58, 34].freeze
    SKIN = [217, 162, 122].freeze
    BOOTS = [62, 90, 52].freeze
    BEAMS = [[224, 64, 112], [64, 160, 240], [96, 224, 112]].freeze

    def self.color(rgb, alpha = 255) = Color.new(rgb[0], rgb[1], rgb[2], alpha)

    def self.load_exact(path, size, tag)
      found = defined?(pbResolveBitmap) ? pbResolveBitmap(path) : nil
      return nil unless found
      bmp = Bitmap.new(found)
      return bmp if [bmp.width, bmp.height] == size
      echoln("[DJRush] #{tag} is #{bmp.width}x#{bmp.height}, want #{size.join('x')}: fallback") if defined?(echoln)
      bmp.dispose
      nil
    end

    # The PNG when it exists at its exact canvas size; nil otherwise (the caller falls back).
    def self.picture(name) = load_exact(PICTURES + name, SIZES[name], name)

    # Always a bitmap of the SIZES layout: the PNG, or the drawn fallback.
    def self.sheet(name) = picture(name) || send("fallback_#{name}")

    def self.car_sheet = load_exact(CAR_SHEET, CAR_SIZE, "djrush_car") || fallback_car_sheet

    # The map event graphic: the art car when its sheet is exactly 384x384, else the DJ's charset.
    def self.map_graphic
      return @map_graphic if @map_graphic
      bmp = load_exact(CAR_SHEET, CAR_SIZE, "djrush_car")
      @map_graphic = bmp ? MAP_GRAPHIC : MAP_FALLBACK
      bmp&.dispose
      @map_graphic
    end

    def self.reset_cache = (@map_graphic = nil)

    def self.charset(id) = load_exact(CHARSETS + id, CHARSET_SIZE, "dt_#{id}")

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

    def self.box(bmp, x, y, w, h, rgb, edge = OUTLINE, t = 2)
      bmp.fill_rect(x, y, w, h, color(edge))
      bmp.fill_rect(x + t, y + t, w - 2 * t, h - 2 * t, color(rgb))
    end

    def self.frame_rect(bmp, x, y, w, h, rgb, t = 2)
      [[x, y, w, t], [x, y + h - t, w, t], [x, y, t, h], [x + w - t, y, t, h]].each { |r| bmp.fill_rect(*r, color(rgb)) }
    end

    def self.heart(bmp, x, y, s, rgb)
      disc(bmp, x + s, y + s, s, rgb)
      disc(bmp, x + 3 * s, y + s, s, rgb)
      (0..2 * s).each { |i| bmp.fill_rect(x + i, y + s + i, [4 * s + 1 - 2 * i, 1].max, 1, color(rgb)) }
    end

    # A charset frame (32x48) or a capsule when the charset is missing.
    def self.face(bmp, x, y, cs, dir, frame = 0, top = FH)
      if cs
        bmp.blt(x, y, cs, Rect.new(frame * FW, ROW[dir] * FH, FW, top))
      else
        blob(bmp, x + 16, y + 14, 8, SKIN)
        bmp.fill_rect(x + 8, y + 24, 16, [top - 26, 0].max, color(JERSEY)) if top > 26
      end
    end

    #--- pieces (D6) --------------------------------------------------------------
    # piece: rules hash; faces: charset bitmaps (nil = capsule); car: the car_piece bitmap.
    def self.piece(p, faces, car, frame = 0, tint = 0)
      w = p[:horiz] ? p[:len] * CELL : CELL
      h = p[:horiz] ? CELL : p[:len] * CELL
      bmp = Bitmap.new(w, h)
      case p[:kind]
      when :car
        bmp.blt(0, 0, car, Rect.new(0, 0, car.width, car.height))
      when :couple
        box(bmp, 1, 1, w - 2, h - 2, COUPLE)
        face(bmp, 10, 0, faces[0], :right, frame)
        face(bmp, 54, 0, faces[1], :left, frame)
        heart(bmp, 44, 8, 2, HEART)
      when :sleeper
        box(bmp, 1, 1, w - 2, h - 2, FLOOR)
        box(bmp, 4, 4, 40, 88, SLEEP_BAGS[tint % SLEEP_BAGS.length])
        bmp.fill_rect(8, 30, 32, 2, color(OUTLINE))
        face(bmp, 8, 6, faces[0], :down, 0, 20)
        zee(bmp, 30, 40)
      when :conga
        box(bmp, 1, 1, w - 2, h - 2, CONGA)
        3.times { |i| face(bmp, 8 + i * 48, 0, faces[i], :right, (frame + i) % 4) }
      when :queue
        box(bmp, 1, 1, w - 2, h - 2, QUEUE)
        bmp.fill_rect(3, 4, 2, h - 8, color(ROPE))
        bmp.fill_rect(w - 5, 4, 2, h - 8, color(ROPE))
        3.times { |i| face(bmp, 8, i * 48, faces[i], :up, frame) }
      end
      bmp
    end

    def self.zee(bmp, x, y)
      bmp.fill_rect(x, y, 8, 2, color(WHITE))
      4.times { |i| bmp.fill_rect(x + 6 - i * 2, y + 2 + i * 2, 2, 2, color(WHITE)) }
      bmp.fill_rect(x, y + 10, 8, 2, color(WHITE))
    end

    #--- fallbacks (same layout as the PNGs) -----------------------------------------
    def self.car_body(bmp, ox, oy, s, lights)
      blob(bmp, ox + 48 * s, oy + 40 * s, 30 * s, WOOL)
      blob(bmp, ox + 30 * s, oy + 36 * s, 14 * s, WOOL_DARK)
      bmp.fill_rect(ox + 74 * s, oy + 26 * s, 18 * s, 22 * s, color(FACE))
      blob(bmp, ox + 28 * s, oy + 50 * s, 7 * s, SPEAKER)
      blob(bmp, ox + 60 * s, oy + 50 * s, 7 * s, SPEAKER)
      4.times { |i| bmp.fill_rect(ox + (18 + i * 6) * s + i * 14 * s, oy + 58 * s, 4 * s, 6 * s, color(FACE)) }
      lights.each_with_index { |rgb, i| disc(bmp, ox + (24 + i * 16) * s, oy + 16 * s, 2 * s, rgb) }
    end

    def self.dj(bmp, cx, top, s = 1, arms = :none)
      bmp.fill_rect(cx - 6 * s, top + 36 * s, 5 * s, 10 * s, color(BOOTS))
      bmp.fill_rect(cx + s, top + 36 * s, 5 * s, 10 * s, color(BOOTS))
      box(bmp, cx - 8 * s, top + 18 * s, 16 * s, 19 * s, JERSEY, OUTLINE, s)
      bmp.fill_rect(cx - 7 * s, top + 24 * s, 14 * s, 3 * s, color(JERSEY_Y))
      blob(bmp, cx, top + 10 * s, 7 * s, SKIN)
      bmp.fill_rect(cx - 7 * s, top + 3 * s, 14 * s, 4 * s, color(HAIR))
      bmp.fill_rect(cx - 6 * s, top + 9 * s, 12 * s, 2 * s, color(YELLOW))
      bmp.fill_rect(cx - 12 * s, top + 4 * s, 3 * s, 16 * s, color(JERSEY)) if arms == :up
      bmp.fill_rect(cx + 9 * s, top + 4 * s, 3 * s, 16 * s, color(JERSEY)) if arms == :up
    end

    def self.fallback_car_sheet
      bmp = Bitmap.new(*CAR_SIZE)
      4.times do |r|
        4.times do |f|
          lights = r == 1 ? [LIGHT_OFF] * 4 : LIGHTS.rotate(f)
          car_body(bmp, f * CAR_FRAME, r * CAR_FRAME + 32, 1, lights)
          dj(bmp, f * CAR_FRAME + 48, r * CAR_FRAME + 4 - (r != 1 && f.odd? ? 1 : 0), 1, r == 1 && f.odd? ? :up : :none)
          bmp.fill_rect(f * CAR_FRAME + 28, r * CAR_FRAME + 36, 40, 10, color(SPEAKER))
        end
      end
      bmp
    end

    def self.fallback_dj_poses
      bmp = Bitmap.new(*SIZES["dj_poses"])
      4.times do |c|
        x, y = (c % 2) * 64, (c / 2) * 96
        dj(bmp, x + 32, y + 2, 2, c == 1 ? :up : :none)
        bmp.fill_rect(x + 22, y + 52, 20, 18, color(SPEAKER)) if c.zero?
        bmp.fill_rect(x + 30, y + 24, 4, 10, color(SKIN)) if c == 2
      end
      bmp
    end

    def self.fallback_car_piece
      bmp = Bitmap.new(*SIZES["car_piece"])
      box(bmp, 1, 1, 94, 46, FLOOR)
      blob(bmp, 40, 24, 18, WOOL)
      bmp.fill_rect(70, 12, 18, 22, color(FACE))
      blob(bmp, 22, 32, 5, SPEAKER)
      blob(bmp, 56, 32, 5, SPEAKER)
      bmp
    end

    #--- procedural UI -----------------------------------------------------------------
    BOARD_AT = [24, 56].freeze
    RAIL_AT = [16, 48].freeze

    # Rail, floor and grid, 304x304 drawn at RAIL_AT; the exit gap opens the right rail on EXIT_ROW.
    def self.board
      bmp = Bitmap.new(304, 304)
      box(bmp, 0, 0, 304, 304, WOOD, WOOD_DARK, 2)
      bmp.fill_rect(8, 8, 288, 288, color(FLOOR))
      (1...6).each do |i|
        bmp.fill_rect(8 + i * CELL, 8, 1, 288, color(GRID))
        bmp.fill_rect(8, 8 + i * CELL, 288, 1, color(GRID))
      end
      bmp.fill_rect(296, 8 + DJRushRules::EXIT_ROW * CELL, 8, CELL, color(FLOOR))
      bmp
    end

    def self.cursor
      bmp = Bitmap.new(CELL, CELL)
      frame_rect(bmp, 0, 0, CELL, CELL, OUTLINE, 5)
      frame_rect(bmp, 1, 1, CELL - 2, CELL - 2, YELLOW, 3)
      bmp
    end

    def self.arrow(bmp, x, y, dir, rgb)
      6.times do |i|
        case dir
        when :right then bmp.fill_rect(x + i, y + i, 2, 12 - 2 * i, color(rgb))
        when :left then bmp.fill_rect(x + 10 - i, y + i, 2, 12 - 2 * i, color(rgb))
        when :down then bmp.fill_rect(x + i, y + i, 12 - 2 * i, 2, color(rgb))
        when :up then bmp.fill_rect(x + i, y + 10 - i, 12 - 2 * i, 2, color(rgb))
        end
      end
    end

    # The restart ring: 16 dots, the first `frac` of them lit.
    def self.ring(bmp, cx, cy, frac)
      16.times do |i|
        a = Math::PI * 2 * i / 16 - Math::PI / 2
        lit = i < (frac * 16).round
        disc(bmp, cx + (Math.cos(a) * 12).round, cy + (Math.sin(a) * 12).round, 2, lit ? YELLOW : GRID)
      end
    end

    def self.beam(rgb)
      bmp = Bitmap.new(48, 460)
      6.times { |i| bmp.fill_rect(i * 4, 0, 48 - i * 8, 460, color(rgb, 14)) }
      bmp
    end

    def self.confetti(bmp, seed)
      rng = Random.new(seed)
      60.times { bmp.fill_rect(rng.rand(512), rng.rand(384), 4, 6, color(LIGHTS[rng.rand(4)])) }
    end
  end
end
