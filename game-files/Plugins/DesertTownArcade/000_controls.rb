#===============================================================================
# Desert Town color buttons.
#
# One map from cabinet color to keyboard key. Raspberry Pi GPIO wiring is not
# done here: point each physical button at the key in docs/controls.md.
#
# C, X, and Z are not in this map and are not rebound.
#   C (and Enter, Space) stays Use / talk / confirm.
#   X (and Esc) stays Back: cancel, and hold to run.
#   Z (and Shift) stays Action: the pause menu.
# B stays the existing raw key that opens the Bag (001_bag_button.rb).
#
# A, S, and D were the proposed keys. They are already Essentials inputs
# (Jump Up, Jump Down, and the Ready menu), so the color buttons use free
# letters instead. See TAKEN_KEYS.
#===============================================================================

module DesertTownControls
  COLORS = {
    red:    { key: :H, role: :action },
    blue:   { key: :J, role: :run },
    orange: { key: :K, role: :bag },
    white:  { key: :F, role: :help },
    green:  { key: :G, role: :world_map }
  }.freeze

  # Same input the stock key already produces. Red follows C everywhere C
  # works. Blue follows X, including hold-to-run (Game_Player#can_run?).
  MIRROR_INPUT = {
    red: :USE,
    blue: :BACK
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
    return false unless slide_allowed?
    if raw_triggered?(key(:white))
      return show_slide(HELP_BITMAP)
    end
    if raw_triggered?(key(:green))
      return show_slide(WORLD_BITMAP)
    end
    false
  end

  def self.show_slide(bitmap_path)
    return false unless defined?(Sprite) && defined?(Bitmap) && defined?(Graphics) && defined?(Viewport)
    return false unless defined?(FileTest) && FileTest.exist?(bitmap_path)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 999_999
    sprite = Sprite.new(viewport)
    begin
      sprite.bitmap = Bitmap.new(bitmap_path)
      sprite.x = (Graphics.width - sprite.bitmap.width) / 2
      sprite.y = (Graphics.height - sprite.bitmap.height) / 2
      loop do
        Graphics.update
        Input.update
        break if slide_closed_now?
      end
    ensure
      sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
      sprite.dispose
      viewport.dispose
    end
    true
  end

  def self.slide_closed_now?
    return false unless defined?(Input)
    SLIDE_CLOSE_INPUTS.each do |name|
      next unless Input.const_defined?(name)
      return true if Input.trigger?(Input.const_get(name))
    end
    return false unless Input.respond_to?(:triggerex?)
    SLIDE_CLOSE_KEYS.each do |key|
      return true if Input.triggerex?(key)
    end
    false
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
