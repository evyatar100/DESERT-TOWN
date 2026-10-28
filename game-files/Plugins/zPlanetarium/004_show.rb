#===============================================================================
# Planetarium - the modal show. Runs inside Eyal's event (no walking, menu or save).
# The recording plays straight through, silent minute included; the visuals follow
# the audio position. Back asks to leave. Everything is torn down in ensure, and the
# map's music comes back in a nested ensure even if the teardown raises.
#===============================================================================

module Planet
  class Show
    R = PlanetRules
    AUDIO = "planetarium"
    AUDIO_PATH = "Audio/BGM/planetarium"
    TIMING_FILE = "Data/planetarium_timing.json"
    FADE_IN = 1.0
    END_FADE = 2.0
    LEAVE_FADE = 1.0
    REFADE_FRAMES = 16   # the map fading back in

    @running = false

    def self.running?
      @running
    end

    # [timing or nil, audio present?]; one echoln per missing or broken part.
    def self.sources
      [load_timing, FileTest.audio_exist?(AUDIO_PATH)]
    end

    def self.load_timing
      unless File.exist?(TIMING_FILE)
        echoln("[Planetarium] #{TIMING_FILE} missing: stars only, no text")
        return nil
      end
      doc = SimpleJSONParser.parse(File.read(TIMING_FILE, encoding: "utf-8"))
      timing, err = R.parse_timing(doc)
      echoln("[Planetarium] #{TIMING_FILE} invalid (#{err}): stars only, no text") unless timing
      timing
    rescue StandardError => e
      echoln("[Planetarium] #{TIMING_FILE} unreadable (#{e.message}): stars only, no text")
      nil
    end

    # Nil when neither the timing nor the audio is there (Eyal says BROKEN, state untouched).
    def self.prepare(from: 0.0)
      timing, audio = sources
      echoln("[Planetarium] #{AUDIO_PATH}.ogg missing: silent, frame clock") if timing && !audio
      return nil if !timing && !audio
      new(timing, audio, from)
    end

    def initialize(timing, audio, from)
      @timing = timing
      @audio = audio
      @from = from.to_f
      @duration = timing ? timing[:duration] : R::AUDIO_DURATION
      @segs = R.scene_segments(timing, @duration)
    end

    # :done (reached the audio's end), :left (Back -> yes, or an error), false (already running).
    def play
      return false if self.class.running?
      begin
        self.class.instance_variable_set(:@running, true)
        run
      ensure
        self.class.instance_variable_set(:@running, false)
      end
    end

    private

    def run
      DesertTalk.clear_speaker if defined?(DesertTalk)
      result = :left
      begin
        create
        start_audio
        result = loop_frames
        fade_out(result)
        Graphics.freeze
        @frozen = true
      ensure
        begin
          dispose
        ensure
          restore_audio
          if @frozen
            @frozen = false
            Graphics.transition(REFADE_FRAMES)
          end
        end
      end
      result
    rescue StandardError => e
      echoln("[Planetarium] show error: #{e.class}: #{e.message}")
      :left
    end

    def fps
      Graphics.frame_rate
    end

    def frame
      Graphics.update
      Input.update
    end

    # The map music fades while the screen goes black; then the recording starts.
    def start_audio
      @bgm = $game_system.playing_bgm&.clone
      @bgs = $game_system.playing_bgs&.clone
      @restore = true
      pbBGMFade(FADE_IN) if @bgm
      pbBGSFade(FADE_IN) if @bgs
      steps = (FADE_IN * fps).ceil
      steps.times do |i|
        @black.opacity = 255 * (i + 1) / steps
        frame
      end
      pbBGSStop
      pbBGMStop
      @black.opacity = 0
      @back.opacity = 255
      @clock = R.new_clock(@audio && play_recording, @from)
    end

    # True when the recording is playing (audio clock); false runs silent on frames.
    def play_recording
      return pbBGMPlay(AUDIO, 100, 100) || true if @from <= 0
      Audio.bgm_play(AUDIO_PATH, 100, 100, @from)
      true
    rescue StandardError => e
      echoln("[Planetarium] seek failed (#{e.message}): silent frame clock")
      false
    end

    # Read on the frame clock too, so a late-moving position re-anchors the show.
    def audio_pos
      return nil unless @clock[:audio]
      Audio.bgm_pos
    rescue StandardError
      nil
    end

    def loop_frames
      loop do
        frame
        case R.clock_tick(@clock, audio_pos, fps)
        when :frames then echoln("[Planetarium] audio position stuck: frame clock")
        when :audio then echoln("[Planetarium] audio position moving: audio clock again")
        end
        t = @clock[:t]
        return :done if R.clock_done?(@clock, @duration)
        @sky.update(t)
        @crawl&.update(t)
        return :left if Input.trigger?(Input::BACK) && !R.leave_locked?(t, @segs) && leave?
      end
    end

    # The audio keeps playing behind the question.
    def leave?
      DesertTalk.clear_speaker if defined?(DesertTalk)
      pbMessage(_INTL("PLANET_SKIP_ASK"), [_INTL("PLANET_CHOICE_YES"), _INTL("PLANET_CHOICE_NO")], 2) == 0
    end

    def fade_out(result)
      seconds = result == :done ? END_FADE : LEAVE_FADE
      stop_recording(seconds) if @clock && @clock[:audio]
      steps = [(seconds * fps).ceil, 1].max
      steps.times do |i|
        @black.opacity = 255 * (i + 1) / steps
        frame
      end
    end

    # The recording never plays past its end (mkxp-z would loop it back to P01): at the
    # end, after a loop, or with less than a fade left it stops at once, else it fades.
    def stop_recording(seconds)
      if @clock[:looped] || @clock[:t] + seconds >= @duration
        pbBGMStop
      else
        pbBGMFade(seconds)
      end
    end

    #--- setup / teardown ------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      # Same z as pbFadeOutIn's black layer but created later, so drawn above it.
      @viewport.z = 99_999
      @back = full_black(0)
      @back.opacity = 0
      begin
        sky = Sky.new(@viewport, @segs)
        crawl = @timing ? Crawl.new(@viewport, @timing) : nil
      rescue StandardError
        sky&.dispose
        raise
      end
      @sky = sky
      @crawl = crawl
      @black = full_black(500)
      @black.opacity = 0
    end

    def full_black(z)
      s = Sprite.new(@viewport)
      s.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      s.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
      s.z = z
      s
    end

    def dispose
      @crawl&.dispose
      @sky&.dispose
      [@black, @back].each do |s|
        next if !s || s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      @viewport.dispose if @viewport && !@viewport.disposed?
    end

    # Each memorized track (BGM, BGS) back on its own; the map's autoplay only when
    # neither was playing.
    def restore_audio
      return unless @restore
      @restore = false
      pbBGMStop
      $game_system.bgm_play(@bgm) if @bgm
      $game_system.bgs_play(@bgs) if @bgs
      $game_map.autoplay if !@bgm && !@bgs && $game_map
    end
  end
end
