#===============================================================================
# DJ Rush Hour - the modal puzzle screen: title, boards, solved/freed cards, pause.
# Joystick moves, Yellow (USE) grabs/releases, Blue (BACK) releases, taps to pause,
# holds to restart. BGM is never touched. run returns {result:, level:, moves:}.
#===============================================================================

module DJRush
  class Scene
    R = DJRushRules
    A = Art
    HOWTO = %w[DJRUSH_HOWTO_1 DJRUSH_HOWTO_2 DJRUSH_HOWTO_3].freeze
    PAUSE_ROWS = %w[DJRUSH_PAUSE_RESUME DJRUSH_PAUSE_HINT DJRUSH_PAUSE_RESTART DJRUSH_PAUSE_LEAVE].freeze
    REPEAT_FIRST = 0.30
    REPEAT_NEXT = 0.10
    HOLD_SHOW = 0.25
    HOLD_RESTART = 1.0
    WIN_TIME = 0.8
    DRIVE_TIME = 0.6
    CARD_LOCK = 0.5
    BUBBLE_TIME = 1.4
    BUMP_GAP = 2.0
    HINT_TIME = 2.0
    WOBBLE_TIME = 0.2
    SE = {
      cursor: "Tile Game cursor", grab: "GUI storage pick up", drop: "GUI storage put down", bump: "Player bump",
      restart: "Mining collapse", win: "Voltorb Flip level up", ok: "GUI sel decision", cancel: "GUI sel cancel",
      buzzer: "GUI sel buzzer"
    }.freeze
    DIR4 = { 2 => :down, 4 => :left, 6 => :right, 8 => :up }.freeze

    attr_reader :phase, :board, :cursor

    # levels: board indices to play in order; replay: a single board that records best only.
    # record: false for the F9 test board (nothing saved).
    def initialize(state, levels, replay: false, record: true, seed: nil)
      @state = state
      @levels = levels
      @replay = replay
      @record = record
      @rng = Random.new(seed || rand(1 << 30))
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
      @t += dt
      @phase_t += dt
      yellow = Input.trigger?(Input::USE)
      blue = Input.trigger?(Input::BACK)
      held = Input.press?(Input::BACK)
      step = repeat(DIR4[Input.dir4], dt)
      result = case @phase
               when :title then update_title(yellow, blue)
               when :play then update_play(dt, yellow, blue, held, step)
               when :pause then update_pause(yellow, blue, step)
               when :win then update_win
               when :card, :freed then update_card(yellow)
               end
      update_fx(dt)
      result
    end

    def enter(phase)
      @phase = phase
      @phase_t = 0.0
    end

    def outcome(result)
      { result: result, level: @board ? @board[:level] : @levels.first, moves: @board ? @board[:moves] : 0 }
    end

    # Joystick step now, then after 0.30 s, then every 0.10 s while held.
    def repeat(dir, dt)
      if dir.nil?
        @rep_dir = nil
        return nil
      end
      if dir != @rep_dir
        @rep_dir = dir
        @rep_t = REPEAT_FIRST
        return dir
      end
      @rep_t -= dt
      return nil if @rep_t > 0
      @rep_t += REPEAT_NEXT
      dir
    end

    #--- phases ----------------------------------------------------------------------
    def update_title(yellow, blue)
      if blue
        se(:cancel)
        return outcome(:quit)
      end
      return nil unless yellow
      se(:ok)
      @title.visible = false
      start_board(@levels.first)
      nil
    end

    def update_play(dt, yellow, blue, held, step)
      return play_grabbed(yellow, blue, step) if @board[:grab]
      if blue
        @hold_t = 0.0                       # only a fresh press starts the hold
      elsif @hold_t
        if held
          @hold_t += dt
          if @hold_t >= HOLD_RESTART
            @hold_t = nil
            restart_board
          end
        else
          @hold_t = nil
          open_pause
        end
      end
      draw_ring
      return nil if @hold_t
      @cursor = R.cursor(@cursor, step) if step
      se(:cursor) if step
      return nil unless yellow
      id = R.piece_at(@board, *@cursor)
      unless id
        se(:buzzer)
        return nil
      end
      R.grab(@board, id)
      se(:grab)
      nil
    end

    def play_grabbed(yellow, blue, step)
      return release_piece if yellow || blue
      return nil unless step
      id = @board[:grab]
      case R.slide(@board, id, step)
      when :moved
        se(:cursor)
        @cursor = R.cursor(@cursor, step)
        @walk_t = 0.4 if @board[:pieces][id][:kind] == :conga
        win if R.solved?(@board)
      when :cross then @wobble = [id, 0.0]
      else bump(id)
      end
      nil
    end

    def release_piece
      id = @board[:grab]
      counted = R.release(@board)
      se(:drop)
      react(id) if counted
      draw_hud
      nil
    end

    def update_pause(yellow, blue, step)
      if blue
        se(:cancel)
        return close_pause
      end
      if step == :up || step == :down
        @pause_i = (@pause_i + (step == :up ? -1 : 1)) % PAUSE_ROWS.length
        se(:cursor)
        draw_pause
      end
      return nil unless yellow
      se(:ok)
      case @pause_i
      when 1 then show_hint
      when 2 then restart_board
      when 3 then return outcome(:quit)
      end
      close_pause
    end

    def update_win
      return nil if @phase_t < WIN_TIME
      draw_card
      enter(:card)
      nil
    end

    def update_card(yellow)
      return nil if @phase_t < CARD_LOCK || !yellow
      se(:ok)
      return outcome(:freed) if @phase == :freed
      i = @levels.index(@board[:level])
      if i && @levels[i + 1]
        start_board(@levels[i + 1])
        return nil
      end
      return outcome(:solved) if @replay || !R.freed?(@state)
      draw_freed
      enter(:freed)
      nil
    end

    #--- board events --------------------------------------------------------------------
    def win
      R.release(@board)
      se(:win)
      if @record
        R.clear_level!(@state, @board[:level], @board[:moves])
        R.free!(@state) unless @replay
      end
      @hint = nil
      @bubble.visible = false
      draw_hud
      enter(:win)
    end

    def bump(id)
      se(:bump)
      return if @bump_at && @t - @bump_at < BUMP_GAP
      @bump_at = @t
      key = R.reaction_key(:bump, true, @last_bump, @rng.rand)
      @last_bump = key
      bubble(key, id)
    end

    def react(id)
      kind = @board[:pieces][id][:kind]
      key = R.reaction_key(kind, !@kinds_moved[kind], @last_reaction, @rng.rand)
      @kinds_moved[kind] = true
      return unless key
      @last_reaction = key
      bubble(key, id)
    end

    def show_hint
      h = R.hint(@board)
      @hint = h && [h[0], h[1] < 0 ? -1 : 1, HINT_TIME]
    end

    def open_pause
      se(:cancel)
      @pause_i = 0
      draw_pause
      enter(:pause)
    end

    def close_pause
      @panel.visible = false
      @phase = :play
      nil
    end

    def restart_board
      R.restart(@board)
      se(:restart)
      @kinds_moved = {}
      @hint = nil
      @bubble.visible = false
      draw_hud
    end

    def start_board(level)
      @board = R.new_board(level)
      @cursor = [0, R::EXIT_ROW]
      @kinds_moved = {}
      @hint = @wobble = @hold_t = @bump_at = nil
      @walk_t = 0.0
      @card.visible = false
      build_pieces
      draw_hud
      enter(:play)
      true
    end

    #--- per-frame drawing ---------------------------------------------------------------
    def update_fx(dt)
      @beams.each_with_index { |b, i| b.angle = 18 * Math.sin(@t * 0.5 + i * 2.1) }
      @exit_arrow.x = 322 + (Math.sin(@t * 6) * 3).round
      @car_anim.src_rect.set(((@t * 6).floor % 4) * A::CAR_FRAME, 0, A::CAR_FRAME, A::CAR_FRAME)
      @bubble.visible = false if @bubble_t && @t - @bubble_t > BUBBLE_TIME
      return unless @board && [:play, :pause, :win, :card].include?(@phase)
      @walk_t = [@walk_t - dt, 0.0].max
      @wobble[1] += dt if @wobble
      @wobble = nil if @wobble && @wobble[1] > WOBBLE_TIME
      @hint[2] -= dt if @hint && @phase == :play
      @hint = nil if @hint && @hint[2] <= 0
      place_pieces
      draw_overlay
      @cursor_sprite.visible = @phase == :play
      @cursor_sprite.x = A::BOARD_AT[0] + @cursor[0] * A::CELL
      @cursor_sprite.y = A::BOARD_AT[1] + @cursor[1] * A::CELL
      @cursor_sprite.opacity = 170 + (Math.sin(@t * 8) * 80).round
    end

    def place_pieces
      grab = @board[:grab]
      @board[:pieces].each do |id, p|
        s = @pieces[id]
        frames = @piece_bmps[id]
        s.bitmap = frames[@walk_t > 0 && id == grab ? ((@t * 8).floor % frames.length) : 0]
        x = A::BOARD_AT[0] + p[:x] * A::CELL
        y = A::BOARD_AT[1] + p[:y] * A::CELL
        if @phase == :win
          if p[:kind] == :car
            x += (144 * [@phase_t / DRIVE_TIME, 1.0].min).round
          else
            y -= (Math.sin(Math::PI * @phase_t / (WIN_TIME / 2)).abs * 6).round
          end
        end
        x += (Math.sin(@wobble[1] * 60) * 4).round if @wobble && @wobble[0] == id
        y -= 2 if id == grab
        s.x, s.y = x, y
      end
      shadow_on = !!grab && @phase == :play
      @shadow.visible = shadow_on
      return unless shadow_on
      p = @board[:pieces][grab]
      @shadow.src_rect.set(0, 0, p[:horiz] ? p[:len] * A::CELL : A::CELL, p[:horiz] ? A::CELL : p[:len] * A::CELL)
      @shadow.x = A::BOARD_AT[0] + p[:x] * A::CELL + 2
      @shadow.y = A::BOARD_AT[1] + p[:y] * A::CELL + 2
    end

    def piece_rect(p)
      [p[:x] * A::CELL, p[:y] * A::CELL, p[:horiz] ? p[:len] * A::CELL : A::CELL, p[:horiz] ? A::CELL : p[:len] * A::CELL]
    end

    # Hover outline, the grabbed piece's open-end arrows and the blinking hint.
    def draw_overlay
      bmp = @overlay.bitmap
      bmp.clear
      return unless @phase == :play || @phase == :pause
      if (id = @board[:grab])
        p = @board[:pieces][id]
        R.open_dirs(@board, id).each { |d| end_arrow(bmp, p, d, A::YELLOW) }
      elsif (id = R.piece_at(@board, *@cursor))
        A.frame_rect(bmp, *piece_rect(@board[:pieces][id]), A::WHITE, 2)
      end
      return unless @hint && ((@hint[2] * 4).floor.even?)
      p = @board[:pieces][@hint[0]]
      A.frame_rect(bmp, *piece_rect(p), A::YELLOW, 3)
      dir = p[:horiz] ? (@hint[1] < 0 ? :left : :right) : (@hint[1] < 0 ? :up : :down)
      end_arrow(bmp, p, dir, A::YELLOW)
    end

    def end_arrow(bmp, p, dir, rgb)
      x, y, w, h = piece_rect(p)
      case dir
      when :left then A.arrow(bmp, x + 2, y + h / 2 - 6, :left, rgb)
      when :right then A.arrow(bmp, x + w - 14, y + h / 2 - 6, :right, rgb)
      when :up then A.arrow(bmp, x + w / 2 - 6, y + 2, :up, rgb)
      when :down then A.arrow(bmp, x + w / 2 - 6, y + h - 14, :down, rgb)
      end
    end

    def draw_ring
      frac = @hold_t && @hold_t >= HOLD_SHOW ? ((@hold_t - HOLD_SHOW) / (HOLD_RESTART - HOLD_SHOW)).clamp(0.0, 1.0) : 0.0
      return if frac == @ring_frac
      @ring_frac = frac
      bmp = @ring.bitmap
      bmp.clear
      A.ring(bmp, 20, 20, frac)
      @ring_label.visible = frac > 0
    end

    #--- setup -------------------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999   # same z as pbFadeOutIn's black layer, created later so drawn above it
      @owned = []
      @sprites = []
      @charsets = {}
      @t = 0.0
      @last = System.uptime
      @poses = own(A.sheet("dj_poses"))
      @car_piece = own(A.sheet("car_piece"))
      @car_sheet = own(A.car_sheet)
      sprite(own(Bitmap.new(512, 384)), 0).bitmap.fill_rect(0, 0, 512, 384, A.color(A::NIGHT))
      @beams = A::BEAMS.each_with_index.map do |rgb, i|
        b = sprite(own(A.beam(rgb)), 1, 90 + i * 170, -20)
        b.ox = 24
        b
      end
      sprite(own(A.board), 2, *A::RAIL_AT)
      @shadow = sprite(own(Bitmap.new(144, 144)), 9)
      @shadow.bitmap.fill_rect(0, 0, 144, 144, A.color(A::OUTLINE, 140))
      @shadow.visible = false
      @pieces = {}
      @piece_bmps = {}
      @overlay = sprite(own(Bitmap.new(288, 288)), 20, *A::BOARD_AT)
      @cursor_sprite = sprite(own(A.cursor), 30)
      @cursor_sprite.visible = false
      arrow = own(Bitmap.new(24, 48))
      A.arrow(arrow, 6, 18, :right, A::YELLOW)
      @exit_arrow = sprite(arrow, 5, 322, 152)
      @dj_bust = sprite(@poses, 6, 408, 48)
      @dj_bust.src_rect.set(A::POSE[0], A::POSE[1], *A::POSE)
      @car_anim = sprite(@car_sheet, 6, 346, 80)
      @car_anim.zoom_x = @car_anim.zoom_y = 0.5
      @hud = sprite(own(Bitmap.new(512, 384)), 40)
      @ring = sprite(own(Bitmap.new(40, 40)), 41, 452, 230)   # below the MIN row (y 204-228)
      @ring_label = sprite(own(Bitmap.new(160, 24)), 41, 344, 272)
      @ring_label.visible = false
      @bubble = sprite(own(Bitmap.new(184, 40)), 50)
      @bubble.visible = false
      @panel = sprite(own(Bitmap.new(512, 384)), 60)
      @panel.visible = false
      @card = sprite(own(Bitmap.new(512, 384)), 70)
      @card.visible = false
      @title = sprite(own(Bitmap.new(512, 384)), 80)
      [@hud, @ring_label, @bubble, @panel, @card, @title].each { |s| pbSetSystemFont(s.bitmap) if defined?(pbSetSystemFont) }
      text(@ring_label.bitmap, 0, 0, 160, 24, _INTL("DJRUSH_HOLD_RESTART"), 18, A::YELLOW)
      @ring_frac = nil
      draw_ring
      draw_title
      enter(:title)
    end

    def charset(id)
      @charsets[id] = own(A.charset(id)) unless @charsets.key?(id)
      @charsets[id]
    end

    # Piece bitmaps for the board's level; a conga gets 4 walk frames.
    def build_pieces
      (@piece_owned || []).each { |b| b.dispose unless b.disposed? }
      @piece_owned = []
      faces = R.crowd_ids(@board[:level])
      sleepers = 0
      @board[:pieces].each do |id, p|
        cs = faces[id].map { |f| charset(f) }
        tint = p[:kind] == :sleeper ? (sleepers += 1) : 0
        n = p[:kind] == :conga ? 4 : 1
        @piece_bmps[id] = Array.new(n) { |f| A.piece(p, cs, @car_piece, f, tint).tap { |b| @piece_owned << b } }
        @pieces[id] ||= sprite(nil, 10)
        @pieces[id].z = p[:kind] == :car ? 11 : 10
        @pieces[id].visible = true
      end
      @pieces.each { |id, s| s.visible = @board[:pieces].key?(id) }
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
      ((@owned || []) + (@piece_owned || [])).each { |b| b.dispose unless b.disposed? }
      @viewport.dispose if @viewport && !@viewport.disposed?
    end

    def se(key)
      pbSEPlay(SE[key], 80)
      true
    end

    #--- text ----------------------------------------------------------------------------
    def col(rgb, alpha = 255) = A.color(rgb, alpha)

    # align: 0 left, 1 centre, 2 right. Hebrew left-align draws in a box exactly its width.
    def text(bmp, x, y, w, h, str, size, base = A::TEXT, align = 1)
      bmp.font.size = size
      if align.zero?
        w = [bmp.text_size(str).width + 4, w].min
        align = 1
      end
      pbDrawShadowText(bmp, x, y, w, h, str, col(base), col(A::INK), align)
    end

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

    def draw_title
      bmp = @title.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, 512, 384, col(A::NIGHT))
      A.box(bmp, 96, 10, 320, 52, A::INK, A::YELLOW, 3)
      text(bmp, 96, 14, 320, 44, _INTL("DJRUSH_TITLE"), 36, A::YELLOW)
      bmp.stretch_blt(Rect.new(12, 90, 128, 192), @poses, Rect.new(A::POSE[0], A::POSE[1], *A::POSE))
      y = 80
      HOWTO.each do |key|
        lines = wrap(bmp, _INTL(key), 340, 20)
        lines.each_with_index { |l, i| text(bmp, 156, y + i * 22, 344, 22, l, 20) }
        y += lines.length * 22 + 10
      end
      text(bmp, 8, 300, 496, 26, DJRush.level_label(@levels.first), 22, A::YELLOW)
      text(bmp, 8, 340, 496, 28, _INTL("DJRUSH_NEXT"), 22, A::YELLOW)
      @title.visible = true
    end

    def draw_hud
      bmp = @hud.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, 512, 40, col(A::INK, 220))
      bmp.fill_rect(0, 39, 512, 1, col(A::YELLOW))
      text(bmp, 256, 6, 248, 28, _INTL("DJRUSH_TITLE"), 24, A::YELLOW, 2)
      text(bmp, 8, 6, 248, 28, DJRush.level_label(@board[:level]), 22, A::TEXT, 0)
      i = @board[:level]
      text(bmp, 344, 156, 160, 24, _INTL("DJRUSH_MOVES", @board[:moves]), 20, A::TEXT, 2)
      text(bmp, 344, 180, 160, 24, _INTL("DJRUSH_BEST", @state[:best][i] || "-"), 20, A::TEXT, 2)
      text(bmp, 344, 204, 160, 24, _INTL("DJRUSH_MIN", R::MIN_MOVES[i]), 20, A::TEXT, 2)
      text(bmp, 312, 200, 40, 20, _INTL("DJRUSH_EXIT"), 16, A::YELLOW)
      bmp.fill_rect(0, 356, 512, 24, col(A::INK, 220))
      text(bmp, 0, 356, 512, 24, _INTL("DJRUSH_HOWTO_BAR"), 18)
    end

    def bubble(key, id)
      bmp = @bubble.bitmap
      bmp.clear
      A.box(bmp, 0, 0, bmp.width, bmp.height - 6, A::WHITE, A::INK, 2)
      bmp.fill_rect(bmp.width / 2 - 4, bmp.height - 8, 8, 8, col(A::INK))
      text(bmp, 4, 2, bmp.width - 8, bmp.height - 10, _INTL(key), 18, A::INK)
      x, y, w, = piece_rect(@board[:pieces][id])
      @bubble.x = (A::BOARD_AT[0] + x + w / 2 - bmp.width / 2).clamp(0, 512 - bmp.width)
      @bubble.y = (A::BOARD_AT[1] + y - bmp.height).clamp(40, 356 - bmp.height)
      @bubble.visible = true
      @bubble_t = @t
    end

    def draw_pause
      bmp = @panel.bitmap
      bmp.clear
      A.box(bmp, 136, 100, 240, 184, A::INK, A::YELLOW, 3)
      PAUSE_ROWS.each_with_index do |key, i|
        on = i == @pause_i
        bmp.fill_rect(148, 116 + i * 40, 216, 34, col(A::FLOOR)) if on
        text(bmp, 148, 118 + i * 40, 216, 30, _INTL(key), 22, on ? A::YELLOW : A::TEXT)
      end
      @panel.visible = true
    end

    def draw_card
      bmp = @card.bitmap
      bmp.clear
      i = @board[:level]
      moves = @board[:moves]
      A.box(bmp, 76, 88, 360, 216, A::INK, A::YELLOW, 3)
      text(bmp, 76, 96, 360, 40, _INTL("DJRUSH_SOLVED"), 30, A::YELLOW)
      text(bmp, 76, 140, 360, 26, _INTL("DJRUSH_MOVES", moves), 22)
      text(bmp, 76, 166, 360, 26, _INTL("DJRUSH_MIN", R::MIN_MOVES[i]), 22)
      text(bmp, 76, 192, 360, 26, _INTL("DJRUSH_BEST", @state[:best][i] || moves), 22)
      text(bmp, 76, 224, 360, 26, _INTL("DJRUSH_SOLVED_PERFECT"), 22, A::YELLOW) if moves == R::MIN_MOVES[i]
      text(bmp, 76, 264, 360, 28, _INTL("DJRUSH_NEXT"), 22, A::YELLOW)
      @card.visible = true
    end

    def draw_freed
      pbMEPlay("Slots big win") if defined?(pbMEPlay)
      bmp = @card.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, 512, 384, col(A::NIGHT))
      A.confetti(bmp, 7)
      bmp.stretch_blt(Rect.new(0, 8, 288, 288), @car_sheet, Rect.new(0, 0, A::CAR_FRAME, A::CAR_FRAME))
      bmp.stretch_blt(Rect.new(320, 60, 128, 192), @poses, Rect.new(A::POSE[0], 0, *A::POSE))
      bmp.fill_rect(0, 300, 512, 84, col(A::INK, 220))
      wrap(bmp, _INTL("DJRUSH_FREED"), 480, 24).each_with_index { |l, k| text(bmp, 16, 304 + k * 26, 480, 26, l, 24, A::YELLOW) }
      text(bmp, 0, 354, 512, 28, _INTL("DJRUSH_NEXT"), 20)
      @card.visible = true
    end
  end
end
