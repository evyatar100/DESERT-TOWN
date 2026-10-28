#===============================================================================
# __NAME__ - the modal screen: title, play, pause, end card. Yellow (USE) confirms,
# Blue (BACK) pauses or leaves. The BGM is never touched.
#===============================================================================

module __NAME__
  class Scene
    A = Art
    R = __NAME__Rules
    MAX_STEPS = 3   # fixed steps per frame at most, so a hitch never fast-forwards the game

    attr_reader :phase, :game

    # record: false for F9 games, which never write the saved state.
    def initialize(state, record: true)
      @state = state
      @record = record
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
      @anim += 1 unless @phase == :pause   # animations freeze in the pause
      yellow = Input.trigger?(Input::USE)
      blue = Input.trigger?(Input::BACK)
      case @phase
      when :title then update_title(yellow, blue)
      when :play then update_play(dt, yellow, blue)
      when :pause then update_pause(yellow, blue)
      when :card then update_card(yellow, blue)
      end
    end

    def enter(phase)
      @phase = phase
      draw_panel
      nil
    end

    def update_title(yellow, blue)
      return outcome(nil) if blue
      start_game if yellow
      nil
    end

    def start_game
      @game = R.new_game
      @acc = 0.0
      @press = false
      @result = nil
      enter(:play)
    end

    # A press is buffered until the next fixed step; Blue pauses.
    def update_play(dt, yellow, blue)
      return enter(:pause) if blue
      @press ||= yellow
      @acc += dt
      steps = 0
      while @acc >= R::DT && steps < MAX_STEPS && !@game[:over]
        @acc -= R::DT
        steps += 1
        R.tick(@game, @press).each { |e| on_event(e) }
        @press = false
      end
      @acc = 0.0 if steps == MAX_STEPS
      draw_hud
      nil
    end

    def update_pause(yellow, blue)
      return outcome(nil) if blue      # quitting records nothing
      enter(:play) if yellow
      nil
    end

    def update_card(yellow, blue)
      return outcome(@result) if blue
      start_game if yellow
      nil
    end

    def on_event(e)
      case e
      when :won, :lost then finish(e)
      end
    end

    def finish(result)
      @result = result
      R.record!(@state, result, @game[:time]) if @record
      enter(:card)
    end

    def outcome(result)
      { result: result, time: @game ? @game[:time] : 0.0 }
    end

    #--- setup -------------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999   # same z as pbFadeOutIn's black layer, created later so drawn above it
      @owned = []
      @sprites = []
      @anim = 0
      @last = System.uptime
      @cards = { won: own(A.sheet("card_win")), lost: own(A.sheet("card_lose")) }
      bg = sprite(own(Bitmap.new(Graphics.width, Graphics.height)), 0)
      bg.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, A.color(A::INK))
      @title = sprite(own(A.sheet("title")), 10, (Graphics.width - 256) / 2, 40)
      @hud = sprite(own(Bitmap.new(Graphics.width, 32)), 900)
      @panel = sprite(own(Bitmap.new(Graphics.width, Graphics.height)), 950)
      [@hud, @panel].each { |s| pbSetSystemFont(s.bitmap) if defined?(pbSetSystemFont) }
      enter(:title)
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

    #--- drawing -----------------------------------------------------------------
    def text(bmp, y, str, size = 24)
      bmp.font.size = size
      pbDrawShadowText(bmp, 0, y, bmp.width, size + 8, str, A.color(A::TEXT), A.color(A::INK), 1)
    end

    def draw_hud
      @hud.bitmap.clear
      text(@hud.bitmap, 0, _INTL("__PREFIX___HUD", @game[:taps], R::TARGET), 20)
    end

    def draw_panel
      bmp = @panel.bitmap
      bmp.clear
      @title.visible = @phase == :title
      case @phase
      when :title then text(bmp, 200, _INTL("__PREFIX___HELP"))
      when :pause then text(bmp, 170, _INTL("__PREFIX___PAUSE"))
      when :card
        bmp.blt((bmp.width - 256) / 2, 60, @cards[@result], @cards[@result].rect)
        text(bmp, 270, _INTL(@result == :won ? "__PREFIX___WIN" : "__PREFIX___LOSE"))
      end
    end
  end
end
