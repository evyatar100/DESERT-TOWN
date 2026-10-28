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
end
