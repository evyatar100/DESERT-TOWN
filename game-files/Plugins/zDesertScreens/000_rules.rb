#===============================================================================
# DesertScreens (TG57) - pure rules: track names and the cabinet check.
# No engine calls here, so the frozen-engine test can load this file alone.
#===============================================================================

module DesertScreens
  TITLE_BGM = "Deep Playa Psychedelic 2"
  # The Pi runs a 32-bit or 64-bit ARM Linux Ruby; the laptop is Windows (x64-mingw).
  CABINET_PLATFORM = /\A(arm|aarch64)\S*-linux/i

  def self.cabinet_platform?(ruby_platform)
    return !!(ruby_platform.to_s =~ CABINET_PLATFORM)
  end

  # Quit Game closes the game for good, which strands the arcade: hide it there only.
  def self.hide_quit?(ruby_platform = RUBY_PLATFORM)
    return cabinet_platform?(ruby_platform)
  end

  # One short Desert Town splash (it carries the engine credit) replaces the two stock ones.
  SPLASH_IMAGES = ["splash1"].freeze
  SPLASH_HOLD_SECONDS = 0.2

  # Fade in + hold + fade out per splash; the stock scene fades 8 ticks at 20 ticks a second.
  def self.splash_total_seconds(fade_ticks = 8, ticks_per_second = 20)
    fade = fade_ticks.to_f / ticks_per_second
    return SPLASH_IMAGES.length * (fade * 2 + SPLASH_HOLD_SECONDS)
  end

  # Founder-approved Hebrew area label for a map id (002a_area_names.rb); nil keeps the stock name.
  def self.area_name(map_id)
    return nil if !defined?(AREA_NAMES)
    return AREA_NAMES[map_id.to_i]
  end

  # Options rows that only mean something for Pokemon battles, boxes and frame choice (003_options.rb).
  HIDDEN_OPTION_IDS = [:battle_animations, :battle_style, :send_to_boxes, :give_nicknames,
                       :speech_frame, :menu_frame, :text_input_style, :screen_size].freeze
end
