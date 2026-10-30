#===============================================================================
# Desert Town color buttons.
#
# One map from cabinet color to keyboard key. Raspberry Pi GPIO wiring is not
# done here: point each physical button at the key in docs/controls.md.
#
# C, X, and Z are not rebound; the colors mirror them (see MIRROR_INPUT).
#   Yellow follows C (and Enter, Space): Use / talk / confirm.
#   Blue follows X (and Esc): Back, cancel, and hold to run.
#   Pink follows Z (and Shift): Action, the pause menu.
# White ten times, then green once, then white again also opens the pause
# menu. Each of those presses still counts while it closes a slide. Another
# color, or a second green, cancels the sequence.
# B stays the existing raw key that opens the Bag (001_bag_button.rb).
#
# A, S, and D were the proposed keys. They are already Essentials inputs
# (Jump Up, Jump Down, and the Ready menu), so the color buttons use free
# letters instead. See TAKEN_KEYS.
#===============================================================================

module DesertTownControls
  COLORS = {
    yellow: { key: :H, role: :action },
    blue:   { key: :J, role: :run },
    orange: { key: :K, role: :bag },
    white:  { key: :F, role: :help },
    green:  { key: :G, role: :world_map },
    pink:   { key: :N, role: :menu }
  }.freeze

  # Same input the stock key already produces. Yellow follows C everywhere C
  # works. Blue follows X, including hold-to-run (Game_Player#can_run?).
  # Pink follows Z (the pause menu).
  MIRROR_INPUT = {
    yellow: :USE,
    blue: :BACK,
    pink: :ACTION
  }.freeze

  # Default RGSS1 bindings (mkxp keybindings.cpp) plus raw keys this game
  # already reads. A color button must not use one of these.
  TAKEN_KEYS = {
    A: "Jump Up (page up); map-connection editor",
    S: "Jump Down (page down); map-connection editor",
    D: "Special / Ready menu; map-connection editor",
    C: "Use / talk / confirm",
    X: "Back / run / cancel",
    Z: "Action / pause menu",
    Q: "Aux 1",
    W: "Aux 2",
    B: "existing arcade Bag key",
    E: "animation editor (rotate left)",
    L: "animation editor (lock)",
    R: "animation editor (rotate right)",
    P: "animation editor (properties)"
  }.freeze

  SLIDE_CLOSE_INPUTS = [
    :UP, :DOWN, :LEFT, :RIGHT,
    :USE, :BACK, :ACTION,
    :JUMPUP, :JUMPDOWN, :SPECIAL,
    :AUX1, :AUX2
  ].freeze

  # Any of these raw keys closes a slide, including the key that opened it.
  SLIDE_CLOSE_KEYS = [
    :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :K, :L, :M,
    :N, :O, :P, :Q, :R, :S, :T, :U, :V, :W, :X, :Y, :Z,
    :SPACE, :RETURN, :ESCAPE, :BACKSPACE,
    :LSHIFT, :RSHIFT, :LCTRL, :RCTRL, :LALT, :RALT,
    :UP, :DOWN, :LEFT, :RIGHT,
    :NUMBER_0, :NUMBER_1, :NUMBER_2, :NUMBER_3, :NUMBER_4,
    :NUMBER_5, :NUMBER_6, :NUMBER_7, :NUMBER_8, :NUMBER_9
  ].freeze

  HELP_BITMAP = "Graphics/Pictures/DesertTownHelp.png"
  WORLD_BITMAP = "Graphics/Pictures/DesertTownWorldMap.png"
  MENU_CODE_WHITES = 10

  @bag_screen_open = false
  @bag_close = false

  def self.key(color)
    COLORS.fetch(color)[:key]
  end

  def self.role(color)
    COLORS.fetch(color)[:role]
  end

  def self.color_keys
    COLORS.values.map { |spec| spec[:key] }
  end

  # :open, :close, or :none. One edge of the orange key toggles the Bag.
  def self.bag_toggle(bag_open, pressed)
    return :none unless pressed
    return :close if bag_open
    :open
  end

  # True when a slide should go away. inputs are logical names (:USE, :UP, ...).
  # raw_keys are keyboard symbols (:C, :F, :LEFT, ...).
  def self.slide_should_close?(inputs, raw_keys)
    inputs = Array(inputs)
    raw_keys = Array(raw_keys)
    return true if inputs.any? { |name| SLIDE_CLOSE_INPUTS.include?(name) }
    return true if raw_keys.any? { |key| SLIDE_CLOSE_KEYS.include?(key) }
    false
  end

  def self.begin_bag_screen
    @bag_screen_open = true
    @bag_close = false
  end

  def self.end_bag_screen
    @bag_screen_open = false
    @bag_close = false
  end

  def self.bag_screen_open?
    @bag_screen_open
  end

  def self.bag_close?
    @bag_close
  end

  def self.note_bag_orange
    return unless bag_screen_open?
    return unless raw_triggered?(key(:orange))
    @bag_close = true
  end

  def self.force_back?(button)
    return false unless bag_close?
    return false unless defined?(Input) && Input.const_defined?(:BACK)
    button == Input::BACK
  end

  def self.raw_triggered?(key)
    return false unless defined?(Input) && Input.respond_to?(:triggerex?)
    Input.triggerex?(key)
  end

  def self.mirrored?(button, kind)
    return false unless defined?(Input)
    reader = { trigger: :triggerex?, press: :pressex?, repeat: :repeatex?, release: :releaseex? }[kind]
    return false unless reader && Input.respond_to?(reader)
    MIRROR_INPUT.each do |color, input_name|
      next unless Input.const_defined?(input_name)
      next unless button == Input.const_get(input_name)
      return true if Input.send(reader, key(color))
    end
    false
  end

  def self.reset_menu_code
    @menu_whites = 0
    @menu_armed = false
  end

  # :help, :map, :pause, or nil. Ten whites, one green, then white is :pause.
  # Whites past ten stay ready for green. Another color, or a second green, clears it.
  def self.menu_code_press(color)
    @menu_whites = 0 if @menu_whites.nil?
    @menu_armed = false if @menu_armed.nil?
    case color
    when :white
      if @menu_armed
        reset_menu_code
        return :pause
      end
      @menu_whites += 1
      @menu_whites = MENU_CODE_WHITES if @menu_whites > MENU_CODE_WHITES
      :help
    when :green
      if @menu_armed || @menu_whites < MENU_CODE_WHITES
        reset_menu_code
      else
        @menu_armed = true
      end
      :map
    else
      reset_menu_code
      nil
    end
  end

  # Same gates as the stock Z / pink menu. Sets the flag Scene_Map#update opens.
  def self.open_pause_menu?
    return false unless defined?($game_temp) && $game_temp
    return false unless defined?($game_system) && $game_system
    return false if $game_system.menu_disabled
    return false unless defined?($game_player) && $game_player
    return false if $game_player.moving?
    if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:forced_movement?)
      return false if $PokemonGlobal.forced_movement?
    end
    $game_temp.menu_calling = true
    $game_temp.menu_beep = true
    true
  end

  # Field gate for the slides. Dialogue, battles, and events keep the screen.
  def self.slide_allowed?
    return false unless defined?($game_temp) && $game_temp
    return false if $game_temp.in_battle
    return false if $game_temp.message_window_showing
    return false if $game_temp.in_menu
    return false if $game_temp.player_transferring
    return false if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
    true
  end

  # Shows a slide and returns true when one was opened. The caller skips the
  # rest of this frame's map update so the key that closed the slide is not
  # also treated as talk / menu / movement. The next frame's Input.update
  # (Scene_Map#main, before update) clears that edge.
  #
  # This method never starts, stops, fades, or pauses BGM. Playback stays on
  # the audio device while Graphics.update runs.
  def self.show_slide_if_requested?
    unless slide_allowed?
      reset_menu_code
      return false
    end
    if raw_triggered?(key(:white))
      if menu_code_press(:white) == :pause && open_pause_menu?
        return false
      end
      return show_slide(HELP_BITMAP)
    end
    if raw_triggered?(key(:green))
      menu_code_press(:green)
      return show_slide(WORLD_BITMAP)
    end
    %i[yellow blue orange pink].each do |color|
      if raw_triggered?(key(color))
        menu_code_press(:other)
        break
      end
    end
    false
  end

  def self.show_slide(bitmap_path)
    return false unless defined?(Sprite) && defined?(Bitmap) && defined?(Graphics) && defined?(Viewport)
    return false unless defined?(FileTest) && FileTest.exist?(bitmap_path)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 999_999
    sprite = Sprite.new(viewport)
    reason = nil
    begin
      sprite.bitmap = Bitmap.new(bitmap_path)
      sprite.x = (Graphics.width - sprite.bitmap.width) / 2
      sprite.y = (Graphics.height - sprite.bitmap.height) / 2
      loop do
        Graphics.update
        Input.update
        reason = slide_close_reason
        break if reason
      end
    ensure
      sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
      sprite.dispose
      viewport.dispose
    end
    open_pause_menu? if reason && menu_code_press(reason) == :pause
    true
  end

  # :white, :green, :other, or nil. White and green stay part of the pause code
  # when they are the press that closes the slide.
  def self.slide_close_reason
    return nil unless defined?(Input)
    return :white if raw_triggered?(key(:white))
    return :green if raw_triggered?(key(:green))
    %i[yellow blue orange pink].each do |color|
      return :other if raw_triggered?(key(color))
    end
    SLIDE_CLOSE_INPUTS.each do |name|
      next unless Input.const_defined?(name)
      return :other if Input.trigger?(Input.const_get(name))
    end
    return nil unless Input.respond_to?(:triggerex?)
    SLIDE_CLOSE_KEYS.each do |key_name|
      return :other if Input.triggerex?(key_name)
    end
    nil
  end

  def self.slide_closed_now?
    !slide_close_reason.nil?
  end
end

if defined?(Input)
  module Input
    class << self
      alias desert_town_controls_trigger? trigger?
      def trigger?(button)
        return true if DesertTownControls.force_back?(button)
        return true if desert_town_controls_trigger?(button)
        DesertTownControls.mirrored?(button, :trigger)
      end

      alias desert_town_controls_press? press?
      def press?(button)
        return true if desert_town_controls_press?(button)
        DesertTownControls.mirrored?(button, :press)
      end

      alias desert_town_controls_repeat? repeat?
      def repeat?(button)
        return true if desert_town_controls_repeat?(button)
        DesertTownControls.mirrored?(button, :repeat)
      end

      if method_defined?(:release?)
        alias desert_town_controls_release? release?
        def release?(button)
          return true if desert_town_controls_release?(button)
          DesertTownControls.mirrored?(button, :release)
        end
      end

      alias desert_town_controls_update update
      def update(*args)
        desert_town_controls_update(*args)
        DesertTownControls.note_bag_orange
      end
    end
  end
end

if defined?(PokemonBagScreen) && PokemonBagScreen.method_defined?(:pbStartScreen)
  class PokemonBagScreen
    alias desert_town_controls_pbStartScreen pbStartScreen
    def pbStartScreen(*args)
      DesertTownControls.begin_bag_screen
      begin
        desert_town_controls_pbStartScreen(*args)
      ensure
        DesertTownControls.end_bag_screen
      end
    end
  end
end

if defined?(PokemonBag_Scene)
  class PokemonBag_Scene
    if method_defined?(:pbStartScene)
      alias desert_town_controls_pbStartScene pbStartScene
      def pbStartScene(*args)
        DesertTownControls.begin_bag_screen
        desert_town_controls_pbStartScene(*args)
      end
    end

    if method_defined?(:pbEndScene)
      alias desert_town_controls_pbEndScene pbEndScene
      def pbEndScene(*args)
        DesertTownControls.end_bag_screen
        desert_town_controls_pbEndScene(*args)
      end
    end

    if method_defined?(:dispose)
      alias desert_town_controls_dispose dispose
      def dispose(*args)
        DesertTownControls.end_bag_screen
        desert_town_controls_dispose(*args)
      end
    end
  end
end

if defined?(Scene_Map)
  class Scene_Map
    alias desert_town_controls_update update
    def update
      return if DesertTownControls.show_slide_if_requested?
      desert_town_controls_update
    end
  end
end
