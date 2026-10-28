# TG57 Batch 1: cabinet check, title music and Quit Game hiding (shares check/$failures).
ds_dir = File.join(ROOT, "Plugins/zDesertScreens")
load File.join(ds_dir, "000_rules.rb")

check(DesertScreens.cabinet_platform?("armv7l-linux-eabihf"), "screens: the Pi 32-bit Ruby is the cabinet")
check(DesertScreens.cabinet_platform?("arm-linux-gnueabihf"), "screens: the Pi system Ruby is the cabinet")
check(DesertScreens.cabinet_platform?("aarch64-linux"), "screens: a 64-bit Pi is the cabinet")
check(!DesertScreens.cabinet_platform?("x64-mingw-ucrt"), "screens: the Windows laptop is not the cabinet")
check(!DesertScreens.cabinet_platform?("x86_64-linux"), "screens: an x86 Linux laptop is not the cabinet")
check(!DesertScreens.cabinet_platform?("arm64-darwin23"), "screens: an Apple laptop is not the cabinet")
check(!DesertScreens.cabinet_platform?(nil), "screens: no platform string is not the cabinet")
check(DesertScreens.hide_quit?("armv7l-linux-eabihf") && !DesertScreens.hide_quit?("x64-mingw-ucrt"),
      "screens: Quit Game is hidden on the cabinet only")

class IntroEventScene
  attr_reader :opened
  def open_title_screen(_scene, *_args) = (@opened = true)
end
class DSAudio
  attr_accessor :name
  def initialize = (@name = "Title")
end
DSSystem = Struct.new(:title_bgm)
class PokemonLoad_Scene
  attr_reader :started
  def pbStartScene(commands, *_args) = (@started = commands.dup)
end
module MenuHandlers; end unless defined?(MenuHandlers)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
$data_system = DSSystem.new(DSAudio.new)
load File.join(ds_dir, "001_title_music.rb")
load File.join(ds_dir, "002_cabinet_quit.rb")

scene = IntroEventScene.new
scene.open_title_screen(nil)
check($data_system.title_bgm.name == "Deep Playa Psychedelic 2" && scene.opened, "screens: the title plays Deep Playa Psychedelic 2")
check(File.exist?(File.join(ROOT, "Audio/BGM/Deep Playa Psychedelic 2.ogg")), "screens: the title track exists on disk")
check(!DesertScreens.apply_title_bgm(nil), "screens: no system data leaves the title alone")

class DSHandlers
  attr_reader :removed
  def remove(menu, option) = (@removed = [menu, option])
end
h = DSHandlers.new
check(DesertScreens.hide_pause_quit(h, "armv7l-linux-eabihf") && h.removed == [:pause_menu, :quit_game], "screens: the cabinet loses the pause-menu Quit Game")
h2 = DSHandlers.new
check(!DesertScreens.hide_pause_quit(h2, "x64-mingw-ucrt") && h2.removed.nil?, "screens: the laptop keeps the pause-menu Quit Game")
cmds = ["Continue", "New Game", "Options", "Quit Game"]
check(DesertScreens.strip_quit(cmds.dup) == %w[Continue New\ Game Options], "screens: the load list drops a last Quit Game")
check(DesertScreens.strip_quit(["Continue", "Options"]) == %w[Continue Options], "screens: a list without Quit Game is untouched")
ls = PokemonLoad_Scene.new
ls.pbStartScene(cmds.dup)
check(ls.started == cmds, "screens: the laptop load screen still lists Quit Game")
