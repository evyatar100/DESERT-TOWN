#===============================================================================
# Toaster - the Eviction at the casino altar: stamp the Rotom squatter 5 times on
# a 3x3 grid of vault appliances in 60 s. Modal like 006_desk.rb.
#===============================================================================

module Toaster
  class EvictScene
    R = ToasterEvictRules
    GRID_X = 104
    GRID_Y = 72
    CELL_W = 96
    CELL_H = 80
    CELL_GAP = 8
    ROTOM_H = 72
    TEXT = [248, 240, 224].freeze
    SHADOW = [24, 18, 28].freeze
    FELT = [28, 52, 40].freeze
    PANEL = [44, 40, 52].freeze
    CURSOR = [250, 214, 72].freeze
    STAMP = [208, 52, 48].freeze
    WASTE = [236, 120, 96].freeze

    # losses: retry easing; start_h: head-start stamps; seed: one Random per attempt.
    def initialize(losses, start_h, seed)
      @losses = losses
      @h = start_h
      @rng = Random.new(seed)
      @cursor = R::CENTRE
      @prev = nil
      @lock_until = 0.0
      @waste = nil
      @flash = 0
    end

    # {won:, hits:}; Blue quits at once as a fail.
    def run
      create
      @start = now
      @phase = :play
      to_gap(R::GAP)
      refresh_hud
      loop do
        Graphics.update
        Input.update
        result = update
        return result if result
      end
    ensure
      dispose
    end

    def now
      System.uptime
    end

    def update
      animate_flash
      case @phase
      when :play
        return finish(false) if Input.trigger?(Input::BACK)
        update_play
      when :zip then update_zip
      when :card then return finish(@won) if now - @at >= R::CARD_TIME
      end
      nil
    end

    def finish(won)
      { won: won, hits: @h }
    end

    def update_play
      left = R::TIME - (now - @start)
      @timebar.src_rect.width = (@timebar.bitmap.width * [left / R::TIME, 0.0].max).round
      return start_card(false) if left <= 0
      move_cursor
      update_rotom
      stamp if Input.trigger?(Input::USE) && now >= @lock_until
      if @waste && now >= @waste[1]
        @waste = nil
        refresh_hud
      end
    end

    def move_cursor
      [[Input::DOWN, 2], [Input::LEFT, 4], [Input::RIGHT, 6], [Input::UP, 8]].each do |button, dir|
        next unless Input.repeat?(button)
        @cursor = R.move(@cursor, dir)
        @cursor_sprite.x, @cursor_sprite.y = cell_xy(@cursor)
      end
    end

    #--- Rotom: :gap -> (:flicker) -> :up -> :gap ------------------------------
    def to_gap(seconds)
      @r_phase = :gap
      @r_until = now + seconds
      @rotom.visible = false
    end

    def update_rotom
      case @r_phase
      when :gap
        return if now < @r_until
        return show_flicker if R.flicker?(@rng, @h)
        show_real(nil)
      when :flicker then show_real(@r_cell) if now >= @r_until
      when :hit then to_gap(R::HIT_GAP) if @flash == 0
      when :up
        pop = [(now - @r_since) / R::POP_TIME, 1.0].min
        @rotom.zoom_y = @zoom * pop
        return if now < @r_until
        @prev = @r_cell
        to_gap(R::GAP)
      end
    end

    def show_flicker
      @r_cell = R.spawn(@rng, @prev, @cursor)
      @r_phase = :flicker
      @r_until = now + R::FLICKER_TIME
      place_rotom(@r_cell, Tone.new(-160, -160, -160, 255))
    end

    # The real spawn is never the last cell, the cursor cell or the flicker cell.
    def show_real(flicker_cell)
      @r_cell = R.spawn(@rng, @prev, @cursor, flicker_cell)
      @r_phase = :up
      @r_since = now
      @r_until = now + R.window(@h, @losses)
      place_rotom(@r_cell, Tone.new(0, 0, 0, 0))
      @rotom.zoom_y = 0
    end

    def place_rotom(cell, tone)
      x, y = cell_xy(cell)
      @rotom.x = x + CELL_W / 2
      @rotom.y = y + CELL_H - 4
      @rotom.zoom_y = @zoom
      @rotom.tone = tone
      @rotom.visible = true
    end

    def stamp
      return hit if @r_phase == :up && @r_cell == @cursor
      pbSEPlay("GUI sel buzzer")
      @waste = [@cursor, now + R::WASTE_SHOW]
      @lock_until = now + R::WASTE_LOCK
      refresh_hud
    end

    # Rotom stays up, white, for the 4 flash frames, then the post-hit gap.
    def hit
      @h += 1
      @flash = 4
      @rotom.color = Color.new(255, 255, 255, 220)
      @lock_until = now + R::HIT_LOCK
      play_cry
      refresh_hud
      return start_zip if @h >= R::STAMPS
      @prev = @r_cell
      @r_phase = :hit
    end

    def play_cry
      GameData::Species.play_cry_from_species(:ROTOM, 1)
    rescue StandardError
      nil
    end

    # hit applies the white at once; this counts the shown frames down, then clears.
    def animate_flash
      return unless @flash > 0
      @flash -= 1
      @rotom.color = Color.new(0, 0, 0, 0) if @flash == 0
    end

    #--- endings ---------------------------------------------------------------
    def start_zip
      @phase = :zip
      @at = now
      @zip_from = @rotom.x
      @rotom.zoom_y = @zoom
    end

    def update_zip
      f = [(now - @at) / R::ZIP_TIME, 1.0].min
      @rotom.x = (@zip_from + (Graphics.width + 80 - @zip_from) * f).round
      return if f < 1.0
      pbSEPlay("Slots coin")
      start_card(true)
    end

    def start_card(won)
      @won = won
      @phase = :card
      @at = now
      @rotom.visible = false unless won
      refresh_hud
    end

    #--- drawing ---------------------------------------------------------------
    def cell_xy(cell)
      row, col = cell.divmod(R::COLS)
      [GRID_X + col * (CELL_W + CELL_GAP), GRID_Y + row * (CELL_H + CELL_GAP)]
    end

    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      # Same z as pbFadeOutIn's black layer but created later, so drawn above it.
      @viewport.z = 99_999
      @sprites = []
      sprite(draw_board, 0)
      yunik_sprite
      bar = Bitmap.new(480, 6)
      bar.fill_rect(0, 0, 480, 6, col(CURSOR))
      @timebar = sprite(bar, 5, 16, 58)
      @cursor_sprite = sprite(draw_cursor, 30, *cell_xy(@cursor))
      @rotom = rotom_sprite
      @hud = sprite(Bitmap.new(Graphics.width, Graphics.height), 40)
      pbSetSystemFont(@hud.bitmap) if defined?(pbSetSystemFont)
    end

    def sprite(bitmap, z, x = 0, y = 0)
      s = Sprite.new(@viewport)
      s.bitmap = bitmap
      s.z = z
      s.x, s.y = x, y
      @sprites << s
      s
    end

    def col(rgb, alpha = 255)
      Color.new(rgb[0], rgb[1], rgb[2], alpha)
    end

    # Shrinks the font until the line fits its box (long Hebrew labels).
    def fit_font(bmp, str, size, w)
      bmp.font.size = size
      bmp.font.size -= 1 while bmp.font.size > 12 && bmp.text_size(str).width > w - 4
    end

    def text(bmp, x, y, w, h, str, size, base = TEXT, align = 1)  # 1 = centre
      fit_font(bmp, str, size, w)
      pbDrawShadowText(bmp, x, y, w, h, str, col(base), col(SHADOW), align)
    end

    def bitmap_at(path)
      file = pbResolveBitmap(path)
      file ? Bitmap.new(file) : nil
    end

    # The 9 appliance panels; the centre one carries the toaster icon.
    def draw_board
      bmp = Bitmap.new(Graphics.width, Graphics.height)
      pbSetSystemFont(bmp) if defined?(pbSetSystemFont)
      bmp.fill_rect(0, 0, bmp.width, bmp.height, col(FELT))
      bmp.fill_rect(0, 0, bmp.width, 56, col(SHADOW, 230))
      icon = bitmap_at("Graphics/Items/TOASTER")
      R::CELLS.times do |c|
        x, y = cell_xy(c)
        bmp.fill_rect(x + 2, y, CELL_W - 4, CELL_H, col(PANEL))
        bmp.fill_rect(x, y + 2, CELL_W, CELL_H - 4, col(PANEL))
        word_y = y + CELL_H - 30
        if c == R::CENTRE && icon
          bmp.blt(x + (CELL_W - icon.width) / 2, y + 4, icon, icon.rect)
        else
          word_y = y + (CELL_H - 26) / 2
        end
        text(bmp, x, word_y, CELL_W, 26, _INTL("TOAST_VAULT_APPL_#{c + 1}"), 18)
      end
      icon&.dispose
      bmp.fill_rect(0, 350, bmp.width, 34, col(SHADOW, 210))
      text(bmp, 0, 352, bmp.width, 30, _INTL("TOAST_VAULT_HINT"), 20)
      bmp
    end

    def draw_cursor
      bmp = Bitmap.new(CELL_W, CELL_H)
      c = col(CURSOR)
      bmp.fill_rect(0, 0, CELL_W, 4, c)
      bmp.fill_rect(0, CELL_H - 4, CELL_W, 4, c)
      bmp.fill_rect(0, 0, 4, CELL_H, c)
      bmp.fill_rect(CELL_W - 4, 0, 4, CELL_H, c)
      bmp
    end

    def yunik_sprite
      bmp = bitmap_at("Graphics/Characters/dt_326f5ab5")
      return unless bmp
      s = sprite(bmp, 10, 12, 4)
      s.src_rect.set(0, 0, bmp.width / 4, bmp.height / 4)
    end

    # Bottom-anchored so it pops up from the cell floor; scaled to 72 px high.
    def rotom_sprite
      bmp = bitmap_at("Graphics/Pokemon/Front/ROTOM_1") || Bitmap.new(64, 64)
      s = sprite(bmp, 20)
      side = [bmp.width, bmp.height].min
      s.src_rect.set(0, 0, side, side)
      s.ox = side / 2
      s.oy = side
      @zoom = ROTOM_H.to_f / side
      s.zoom_x = s.zoom_y = @zoom
      s.visible = false
      s
    end

    def refresh_hud
      bmp = @hud.bitmap
      bmp.clear
      text(bmp, 52, 2, 360, 28, _INTL("TOAST_VAULT_NOTICE", @h), 22)
      R::STAMPS.times do |i|
        x = 168 + i * 26
        bmp.fill_rect(x, 32, 18, 18, col(SHADOW))
        bmp.fill_rect(x + 2, 34, 14, 14, i < @h ? col(STAMP) : col(TEXT, 50))
      end
      if @waste
        x, y = cell_xy(@waste[0])
        text(bmp, x - 20, y - 6, CELL_W + 40, 26, _INTL("TOAST_VAULT_WASTE"), 20, WASTE)
      end
      draw_card(bmp) if @phase == :card
    end

    def draw_card(bmp)
      bmp.fill_rect(116, 142, 280, 100, col(TEXT))
      bmp.fill_rect(119, 145, 274, 94, col(SHADOW, 240))
      text(bmp, 116, 160, 280, 56, _INTL(@won ? "TOAST_VAULT_WIN" : "TOAST_VAULT_FAIL"), 40,
           @won ? [96, 200, 110] : [224, 80, 72])
    end

    def dispose
      (@sprites || []).each do |s|
        next if s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      @viewport.dispose if @viewport && !@viewport.disposed?
    end
  end
end
