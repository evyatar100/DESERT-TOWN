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

# TG57 Batch 2 (the _INTL stub above echoes "text|args"): one short splash, Hebrew area labels, Load/Save rows without Badges or Pokedex.
class IntroEventScene
  SPLASH_IMAGES = ["splash1", "splash2"] unless const_defined?(:SPLASH_IMAGES)
  SECONDS_PER_SPLASH = 2 unless const_defined?(:SECONDS_PER_SPLASH)
end
class PokemonLoadPanel; end
class PokemonSave_Scene; end
load File.join(ds_dir, "001a_splash.rb")
load File.join(ds_dir, "002a_area_names.rb")
load File.join(ds_dir, "002_load_save.rb")

check(IntroEventScene::SPLASH_IMAGES == ["splash1"], "screens: the boot shows one splash, not two")
check(IntroEventScene::SECONDS_PER_SPLASH == 0.2, "screens: the splash holds 0.2 s")
check((DesertScreens.splash_total_seconds - 1.0).abs < 1e-9, "screens: splash + fades total about one second")
check(File.exist?(File.join(ROOT, "Graphics/Titles/splash1.png")), "screens: the splash image exists")

check(DesertScreens.area_name(98) == "הפלאיה", "screens: the Playa map shows its approved Hebrew label")
check(DesertScreens.area_name(87) == "בתוך החללית", "screens: a map named like a label takes it")
check(DesertScreens.area_name(101) == "דיפ פלאיה" && DesertScreens.area_name(33) == "דיפ פלאיה", "screens: deep-playa maps share one label")
check(DesertScreens.area_name(92) == "מחנה הקרח", "screens: an unlabelled child takes its parent's label")
check(DesertScreens.area_name(111).nil? && DesertScreens.area_name(0).nil?, "screens: a map with no label keeps the stock name")
check(DesertScreens::AREA_NAMES.values.uniq.length == 24, "screens: all 24 approved area labels are reachable")

rows = DesertScreens.continue_rows("Continue", "Dor", "הפלאיה", 3725)
texts = rows.map(&:first)
check(texts == ["Continue", "Dor", "הפלאיה", "Time:", "{1}h {2}m|1,2"], "screens: Continue shows title, name, area and play time only")
check(texts.none? { |t| t =~ /Badges|Pokédex/ }, "screens: Continue has no Badges or Pokedex rows")
check(DesertScreens.play_time_text(300) == "{1}m|5", "screens: play time under an hour shows minutes only")
st = DesertScreens.save_text("הפלאיה", "Dor", 90, "<L>", "<T>")
check(st.include?("Player") && st.include?("Time") && st.include?("הפלאיה"), "screens: Save shows area, player and time")
check(st !~ /Badges|Pokédex/, "screens: Save has no Badges or Pokedex rows")
check(PokemonLoadPanel.ancestors.first == DesertScreens::LoadPanelRows, "screens: the Load panel uses the Desert Town rows")
check(PokemonSave_Scene.ancestors.first == DesertScreens::SaveSceneRows, "screens: the Save window uses the Desert Town rows")

# TG57 Batch 3: Options loses six Pokemon-only rows; the card shows name, time, started, depth.
class DSOptHandlers
  attr_reader :removed
  def initialize = (@removed = [])
  def remove(menu, id) = @removed.push([menu, id])
end
class PokemonTrainerCard_Scene; end
module MenuHandlers; def self.remove(*) = nil; end
load File.join(ds_dir, "003_options.rb")
module DesertTownArcade; def self.depth = 2; end
load File.join(ds_dir, "004_card.rb")
oh = DSOptHandlers.new
DesertScreens.hide_option_rows(oh)
check(oh.removed.map(&:last) == [:battle_animations, :battle_style, :send_to_boxes, :give_nicknames, :speech_frame, :menu_frame] &&
      oh.removed.all? { |m, _| m == :options_menu }, "screens: Options drops the six Pokemon-only rows")
check(!DesertScreens::HIDDEN_OPTION_IDS.include?(:bgm_volume) && !DesertScreens::HIDDEN_OPTION_IDS.include?(:text_speed),
      "screens: Options keeps the volume and text speed rows")
crows = DesertScreens.card_rows("Dor", "5m", "1.2.2026", 3)
check(crows.map(&:first).select { |t| t.is_a?(String) } == ["Name", "Dor", "Time", "5m", "Started", "1.2.2026", "Depth", "3"],
      "screens: the card shows name, play time, started and depth in order")
check(crows.map(&:first).none? { |t| t =~ /ID No|Money|Pok|Badge|TRAINER/i }, "screens: the card has no ID, money, Pokedex or badge row")
check(DesertScreens.started_text(Time.new(2026, 3, 9)) == "9.3.2026", "screens: the start date is day.month.year")
check(PokemonTrainerCard_Scene.ancestors.first == DesertScreens::TrainerCardRows, "screens: the card scene uses the Desert Town rows")
