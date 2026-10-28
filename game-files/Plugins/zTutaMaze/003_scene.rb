#===============================================================================
# Tuta maze - the modal screen: title card, READY/GO, the maze, pause, win/lose cards.
# Joystick steers, Yellow (USE) confirms, Blue (BACK) pauses/leaves. BGM is never touched.
# run returns {result: :won|:lost|:quit, time:}.
#===============================================================================

module TutaMaze
  class Scene
    R = TutaMazeRules
    A = Art
    INTRO_KEYS = %w[TUTA_INTRO_1 TUTA_INTRO_2 TUTA_INTRO_3].freeze   # shown in order, any count up to 4
    INTRO_STEP = 0.8
    CATCH_KEYS = 3
    CARD_LOCK = 0.6
    WORD_TIME = 0.7
    POP_TIME = 0.8
    SPARKLE_TIME = 0.24
    BERRY_SE = ["Voltorb Flip tile", 40].freeze
    SE = {
      golden: ["Voltorb Flip level up", 80], lick: ["Mining ping", 80], catch: ["Exclaim", 80],
      heart: ["Battle damage weak", 80], lost: ["Pkmn faint", 70], won: ["Mining found all", 90],
      ready: ["GUI sel cursor", 80], go: ["Vs flash", 80], ok: ["GUI sel decision", 80], cancel: ["GUI sel cancel", 80]
    }.freeze
    DIR4 = { 2 => :down, 4 => :left, 6 => :right, 8 => :up }.freeze
    PLATE = [96, 8, 320, 56].freeze

    attr_reader :phase, :game

    # diff: nil = from the saved state; seed: nil = random (tests pass one).
    def initialize(state, diff = nil, seed = nil)
      @state = state
      @diff = diff
      @seed = seed
    end

    def run
      create
      loop do
        Graphics.update
        Input.update
        result = update
        return result if result
      end
    ensure
      dispose
    end

    def update
      now = System.uptime
      dt = (now - @last).clamp(0.0, 0.1)
      @last = now
      @phase_t += dt
      paused = @phase == :pause
      @clock += dt unless paused          # pops, words, sparkle and run cycles freeze in the pause
      @anim += 1 unless paused
      yellow = Input.trigger?(Input::USE)
      blue = Input.trigger?(Input::BACK)
      result = case @phase
               when :title then update_title(yellow, blue)
               when :play then update_play(dt, blue)
               when :pause then update_pause(yellow, blue)
               when :card then update_card(yellow, blue)
               end
      update_fx(paused ? 0.0 : dt)
      result
    end

    def enter(phase)
      @phase = phase
      @phase_t = 0.0
    end

    def outcome(result)
      { result: result, time: @game ? (@game[:win_time] || @game[:time]) : 0.0 }
    end

    #--- phases --------------------------------------------------------------------
    def update_title(yellow, blue)
      shown = [(@phase_t / INTRO_STEP).floor + 1, INTRO_KEYS.length].min
      draw_title(shown) if shown != @intro_shown
      if blue
        se(:cancel)
        return outcome(:quit)
      end
      return nil unless yellow
      se(:ok)
      @title.visible = false
      start_game
      nil
    end

    def start_game
      diff = @diff.nil? ? R.diff(@state) : @diff
      eaten = TutaMaze.preset_eaten
      @preset = !eaten.empty?             # an F9 preset game never sets a best time
      @game = R.new_game(diff: diff, seed: @seed || rand(1 << 30), eaten: eaten)
      @pause_wanted = false
      @acc = 0.0
      @recorded = false
      @pop_born = [nil, nil]
      @word_t = nil
      @card.visible = false
      draw_berries
      draw_hud
      show_actors(true)
      enter(:play)
      on_ready
    end

    def update_play(dt, blue)
      @pause_wanted = true if blue        # held through the catch freeze and the win hop
      if @pause_wanted && [:ready, :play].include?(@game[:mode])
        @pause_wanted = false
        se(:cancel)
        draw_pause
        enter(:pause)
        return nil
      end
      dir = DIR4[Input.dir4]
      @acc += dt
      ticks = 0
      while @acc >= R::DT - 1e-9 && ticks < R::MAX_TICKS
        R.tick(@game, dir).each { |e| on_event(e) }
        @acc -= R::DT
        ticks += 1
      end
      @acc = 0.0 if ticks == R::MAX_TICKS && @acc >= R::DT
      nil
    end

    def update_pause(yellow, blue)
      if yellow
        se(:ok)
        return outcome(:quit)
      end
      return nil unless blue
      se(:cancel)
      @panel.visible = false
      @acc = 0.0
      @phase = :play
      nil
    end

    def update_card(yellow, blue)
      return nil if @phase_t < CARD_LOCK
      if blue
        se(:cancel)
        return outcome(@game[:mode])
      end
      return nil unless yellow
      se(:ok)
      start_game
      nil
    end

    #--- rules events ----------------------------------------------------------------
    def on_event(e)
      case e[0]
      when :go then se(:go); word("TUTA_GO")
      when :ready then se(:heart); on_ready
      when :eat then on_eat(e[1], e[2])
      when :golden
        se(:golden)
        @game[:owners].each_with_index { |o, i| pop("TUTA_GOLDEN_POP", i) if o[:melted] }
      when :lick
        se(:lick)
        pop("TUTA_LICK_POP", R::OWNERS.index(e[1]), true)
      when :catch
        se(:catch)
        bubble(e[1])
      when :lost then se(:heart); se(:lost); finish(:lost)
      when :won then finish(:won)
      end
    end

    def on_ready
      se(:ready)
      @bubble.visible = false
      draw_hud
      word("TUTA_READY", R::READY_TIME)
    end

    def on_eat(x, y)
      clear_berry(x, y)
      @berry_pitch = @berry_pitch == 100 ? 110 : 100
      pbSEPlay(BERRY_SE[0], BERRY_SE[1], @berry_pitch)
      @sparkle.x, @sparkle.y = A.screen_of(x, y)
      @sparkle_t = 0.0
      draw_hud
    end

    def finish(result)
      new_best = false
      @pause_wanted = false
      unless @recorded
        @recorded = true
        new_best = R.record!(@state, result, @preset ? nil : @game[:win_time])
      end
      se(:won) if result == :won
      draw_card(result, new_best)
      enter(:card)
    end

    #--- per-frame drawing -------------------------------------------------------------
    def update_fx(dt)
      if @game && @phase != :title
        place_tuta
        @game[:owners].each_with_index { |o, i| place_owner(o, @owner_sprites[i], i) }
        glint
      end
      @word.visible = !!(@word_t && @word_t < @word_len)
      @word_t += dt if @word_t
      @pops.each_with_index do |s, i|
        age = @pop_born[i] ? @clock - @pop_born[i] : POP_TIME
        s.visible = age < POP_TIME
        s.y -= 1 if s.visible && @anim.even? && dt > 0
      end
      @sparkle.visible = !!(@sparkle_t && @sparkle_t < SPARKLE_TIME)
      if @sparkle.visible
        @sparkle.src_rect.set([(@sparkle_t / SPARKLE_TIME * 4).floor, 3].min * 16, 0, 16, 16)
        @sparkle_t += dt
      end
    end

    def place_tuta
      t = @game[:tuta]
      x, y = A.screen_of(t[:x], t[:y])
      s = @tuta
      mode = @game[:mode]
      if [:caught, :hop, :won, :lost].include?(mode)
        cell = [:caught, :lost].include?(mode) ? 2 : 1
        s.bitmap = @tuta_poses
        s.src_rect.set((cell % 2) * A::POSE_CELL, (cell / 2) * A::POSE_CELL, A::POSE_CELL, A::POSE_CELL)
        s.zoom_x = s.zoom_y = 0.5
        s.ox, s.oy = A::POSE_CELL / 2, A::POSE_CELL
        hop = mode == :hop ? (Math.sin(@game[:mode_t] * Math::PI * 4).abs * 8).round : 0
        s.x, s.y = x, y + 16 - hop
      else
        s.bitmap = @tuta_run
        s.zoom_x = s.zoom_y = 1
        s.ox, s.oy = A::RUN_CELL[0] / 2, A::RUN_CELL[1]
        moving = t[:dir] && mode == :play
        frame = moving ? (@anim / 4) % 4 : 0
        s.src_rect.set(frame * 32, A::ROW[t[:face]] * 32, 32, 32)
        s.x, s.y = x, y + 16
      end
      s.z = 10 + s.y
      @aura.visible = @game[:melt_t] > 0
      @aura.x, @aura.y = x, y
    end

    # Run sheet when hunting; poses: 0 catch, 1 melted (blinks at the end), 2 licked/going home.
    def place_owner(o, s, i)
      x, y = A.screen_of(o[:x], o[:y])
      pose = nil
      pose = 0 if @game[:mode] == :caught && @game[:catcher] == o[:id]
      if o[:melted]
        flash = @game[:melt_t] < R::MELT_FLASH && (@anim / 6).even?
        pose = 1 unless flash
      end
      pose = 2 if [:returning, :entering, :sitting].include?(o[:state])
      if pose
        s.bitmap = @owner_poses
        s.src_rect.set(pose * 32, i * 40, 32, 40)
      else
        s.bitmap = @owner_runs[i]
        moving = o[:state] != :couch && @game[:mode] == :play
        frame = moving ? (@anim / 5) % 4 : 0
        s.src_rect.set(frame * 32, A::ROW[o[:dir] || :down] * 40, 32, 40)
      end
      s.ox, s.oy = 16, 40
      s.x, s.y = x, y + 16
      s.z = 10 + s.y
    end

    def glint
      return unless (@anim % 15).zero? && @phase != :pause
      @glint_on = !@glint_on
      R.goldens.each { |c| draw_berry(*c) unless @game[:eaten][c] }
    end

    def show_actors(on)
      ([@tuta, @aura] + @owner_sprites).each { |s| s.visible = on }
      @aura.visible = false
    end

    #--- setup -------------------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999   # same z as pbFadeOutIn's black layer, created later so drawn above it
      @owned = []
      @sprites = []
      @pop_born = [nil, nil]
      @anim = 0
      @clock = 0.0
      @last = System.uptime
      @tuta_run = own(A.sheet("tuta_run"))
      @tuta_poses = own(A.sheet("tuta_poses"))
      @owner_runs = [own(A.sheet("owner_man_run")), own(A.sheet("owner_woman_run"))]
      @owner_poses = own(A.sheet("owner_poses"))
      @berry_sheet = own(A.sheet("berries"))
      @cards = { won: own(A.sheet("tuta_win")), lost: own(A.sheet("tuta_lose")) }
      sprite(own(Bitmap.new(512, 384)), 0).bitmap.fill_rect(0, 0, 512, 384, A.color(A::INK))
      @maze = sprite(own(A.maze), 1, *A::ORIGIN)
      @berries = sprite(own(Bitmap.new(@maze.bitmap.width, @maze.bitmap.height)), 2, *A::ORIGIN)
      @aura = sprite(own(A.aura), 5)
      @aura.ox = @aura.oy = 20
      @aura.opacity = 110
      @tuta = sprite(@tuta_run, 10)
      @owner_sprites = [sprite(@owner_runs[0], 10), sprite(@owner_runs[1], 10)]
      show_actors(false)
      @sparkle = sprite(own(A.sparkle_frames), 900)
      @sparkle.ox = @sparkle.oy = 8
      @sparkle.visible = false
      @pops = [sprite(own(Bitmap.new(120, 40)), 940), sprite(own(Bitmap.new(120, 40)), 940)]
      @pops.each { |p| p.visible = false }
      @hud = sprite(own(Bitmap.new(512, 24)), 950)
      @word = sprite(own(Bitmap.new(512, 80)), 960, 0, 150)
      @word.visible = false
      @bubble = sprite(own(Bitmap.new(220, 44)), 970)
      @bubble.visible = false
      @panel = sprite(own(Bitmap.new(512, 384)), 980)
      @panel.visible = false
      @card = sprite(own(Bitmap.new(512, 384)), 990)
      @card.visible = false
      @title = sprite(own(Bitmap.new(512, 384)), 1000)
      ([@hud, @word, @bubble, @panel, @card, @title] + @pops).each { |s| pbSetSystemFont(s.bitmap) if defined?(pbSetSystemFont) }
      enter(:title)
      @intro_shown = nil
    end

    def own(bmp)
      @owned << bmp if bmp
      bmp
    end

    def sprite(bitmap, z, x = 0, y = 0)
      s = Sprite.new(@viewport)
      s.bitmap = bitmap
      s.z = z
      s.x, s.y = x, y
      @sprites << s
      s
    end

    def dispose
      (@sprites || []).each { |s| s.dispose unless s.disposed? }
      (@owned || []).each { |b| b.dispose unless b.disposed? }
      @viewport.dispose if @viewport && !@viewport.disposed?
    end

    def se(key)
      pbSEPlay(*SE[key])
    end

    #--- drawing -------------------------------------------------------------------------
    def col(rgb, alpha = 255)
      A.color(rgb, alpha)
    end

    def text(bmp, x, y, w, h, str, size, base = A::TEXT, align = 1)  # RGSS align: 1 = centre
      bmp.font.size = size
      pbDrawShadowText(bmp, x, y, w, h, str, col(base), col(A::INK), align)
    end

    # Big title: a 2 px ink outline drawn around the gold letters.
    def outlined(bmp, x, y, w, h, str, size, rgb)
      bmp.font.size = size
      [-2, 0, 2].product([-2, 0, 2]).each do |dx, dy|
        pbDrawShadowText(bmp, x + dx, y + dy, w, h, str, col(A::INK), nil, 1) unless dx.zero? && dy.zero?
      end
      pbDrawShadowText(bmp, x, y, w, h, str, col(rgb), nil, 1)
    end

    # Logical-order word wrap by measured width; each line then goes through the bidi draw.
    def wrap(bmp, str, w, size)
      bmp.font.size = size
      lines = []
      str.to_s.split("\n").each do |para|
        line = ""
        para.split(" ").each do |word|
          try = line.empty? ? word : "#{line} #{word}"
          if !line.empty? && bmp.text_size(try).width > w
            lines << line
            line = word
          else
            line = try
          end
        end
        lines << line
      end
      lines
    end

    def paragraph(bmp, x, y, w, str, size, rgb = A::TEXT, line_h = size + 2)
      wrap(bmp, str, w, size).each_with_index { |l, i| text(bmp, x, y + i * line_h, w, line_h, l, size, rgb) }
    end

    def draw_title(shown)
      @intro_shown = shown
      bmp = @title.bitmap
      bmp.clear
      384.times { |y| bmp.fill_rect(0, y, 512, 1, col(A.mix([58, 42, 74], [122, 42, 58], y / 383.0))) }
      x, y, w, h = PLATE
      bmp.fill_rect(x, y, w, h, col(A::GOLD_DARK))
      bmp.fill_rect(x + 3, y + 3, w - 6, h - 6, col(A::INK, 230))
      outlined(bmp, x, y + 4, w, h - 8, _INTL("TUTA_TITLE"), 44, A::GOLD)
      bmp.stretch_blt(Rect.new(8, 76, 192, 192), @tuta_poses, Rect.new(0, 0, A::POSE_CELL, A::POSE_CELL))
      ty = 80
      INTRO_KEYS.first(shown).each do |key|
        lines = wrap(bmp, _INTL(key), 288, 20)
        lines.each_with_index { |l, i| text(bmp, 212, ty + i * 22, 292, 22, l, 20) }
        ty += lines.length * 22 + 8
      end
      text(bmp, 8, 300, 496, 28, _INTL("TUTA_HOWTO"), 22, A::GOLD_LIGHT)
      text(bmp, 8, 336, 496, 30, _INTL("TUTA_START"), 24, A::GOLD)
      @title.visible = true
    end

    def draw_berries
      @berries.bitmap.clear
      R.berries.each { |c| draw_berry(*c) unless @game[:eaten][c] }
    end

    def berry_rect(x, y)
      [x * A::TILE + (A::TILE - A::BERRY) / 2, y * A::TILE + (A::TILE - A::BERRY) / 2]
    end

    def draw_berry(x, y)
      px, py = berry_rect(x, y)
      golden = R.golden_set[[x, y]]
      frame = golden ? (@glint_on ? 3 : 2) : 0
      @berries.bitmap.fill_rect(px, py, A::BERRY, A::BERRY, Color.new(0, 0, 0, 0))
      @berries.bitmap.blt(px, py, @berry_sheet, Rect.new(frame * A::BERRY, 0, A::BERRY, A::BERRY))
    end

    def clear_berry(x, y)
      px, py = berry_rect(x, y)
      @berries.bitmap.fill_rect(px, py, A::BERRY, A::BERRY, Color.new(0, 0, 0, 0))
    end

    def draw_hud
      bmp = @hud.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, 512, 24, col(A::INK))
      bmp.fill_rect(0, 23, 512, 1, col(A::WALL_EDGE))
      R::LIVES.times do |i|
        A.heart(bmp, 8 + i * 22, 4, 4, i < @game[:lives] ? A::HEART : [70, 50, 60])
      end
      text(bmp, 200, 0, 304, 24, _INTL("TUTA_COUNTER", R.eaten_count(@game), R::TOTAL), 20, A::TEXT, 2)
    end

    def word(key, len = WORD_TIME)
      bmp = @word.bitmap
      bmp.clear
      text(bmp, 0, 0, 512, 80, _INTL(key), 56, A::GOLD)
      @word_t = 0.0
      @word_len = len
    end

    # One pop sprite per owner (i = owner index), reused.
    def pop(key, i, heart = false)
      s = @pops[i]
      bmp = s.bitmap
      bmp.clear
      A.heart(bmp, 52, 0, 4, A::HEART) if heart
      text(bmp, 0, heart ? 10 : 4, 120, 30, _INTL(key), 22, A::GOLD_LIGHT)
      o = @game[:owners][i]
      x, y = A.screen_of(o[:x], o[:y])
      s.x, s.y = x - 60, y - 64
      @pop_born[i] = @clock
    end

    def bubble(id)
      o = R.owner(@game, id)
      key = "TUTA_CATCH_#{id == :man ? 'MAN' : 'WOMAN'}_#{rand(CATCH_KEYS) + 1}"
      bmp = @bubble.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, bmp.width, bmp.height - 8, col(A::INK))
      bmp.fill_rect(2, 2, bmp.width - 4, bmp.height - 12, col(A::TEXT))
      bmp.fill_rect(bmp.width / 2 - 4, bmp.height - 8, 8, 8, col(A::INK))
      text(bmp, 4, 2, bmp.width - 8, bmp.height - 12, _INTL(key), 20, A::INK)
      x, y = A.screen_of(o[:x], o[:y])
      @bubble.x = (x - bmp.width / 2).clamp(0, 512 - bmp.width)
      @bubble.y = (y - 40 - bmp.height).clamp(24, 384 - bmp.height)
      @bubble.visible = true
    end

    def draw_pause
      bmp = @panel.bitmap
      bmp.clear
      bmp.fill_rect(96, 128, 320, 128, col(A::GOLD_DARK))
      bmp.fill_rect(99, 131, 314, 122, col(A::INK, 240))
      text(bmp, 96, 150, 320, 40, _INTL("TUTA_PAUSE"), 32, A::GOLD)
      text(bmp, 96, 200, 320, 32, _INTL("TUTA_PAUSE_HINT"), 20)
      @panel.visible = true
    end

    def draw_card(result, new_best)
      bmp = @card.bitmap
      bmp.clear
      art = @cards[result]
      bmp.stretch_blt(Rect.new(0, 0, 512, 384), art, Rect.new(0, 0, art.width, art.height))
      bmp.fill_rect(0, 256, 512, 128, col(A::INK, 200))
      won = result == :won
      text(bmp, 0, 258, 512, 40, _INTL(won ? "TUTA_WIN_TITLE" : "TUTA_LOSE_TITLE"), 36, won ? A::GOLD : A::HEART)
      paragraph(bmp, 16, 298, 480, _INTL(won ? "TUTA_WIN_LINE" : "TUTA_LOSE_LINE"), 20, A::TEXT, 22)
      if won
        best = @state[:best_time]
        line = new_best ? _INTL("TUTA_NEW_BEST") : _INTL("TUTA_BEST", R.clock(best || @game[:win_time]))
        text(bmp, 0, 4, 256, 28, _INTL("TUTA_TIME", R.clock(@game[:win_time])), 22, A::GOLD_LIGHT)
        text(bmp, 256, 4, 256, 28, line, 22, A::GOLD_LIGHT)
      end
      text(bmp, 0, 350, 512, 30, _INTL("TUTA_AGAIN"), 22, A::GOLD)
      @bubble.visible = false
      @card.visible = true
    end
  end
end
