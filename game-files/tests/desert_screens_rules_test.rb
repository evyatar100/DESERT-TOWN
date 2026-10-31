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
check(DesertScreens.cabinet_platform? == !!(RUBY_PLATFORM.to_s =~ DesertScreens::CABINET_PLATFORM),
      "screens: cabinet_platform? with no argument uses RUBY_PLATFORM")
check(DesertScreens::PI_HOST == "10.0.0.10", "screens: the cabinet is 10.0.0.10")
check(DesertScreens.hide_quit?("armv7l-linux-eabihf") && !DesertScreens.hide_quit?("x64-mingw-ucrt"),
      "screens: the load screen hides Quit Game on the cabinet only")

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
check(!DesertScreens.hide_pause_quit(h, "armv7l-linux-eabihf") && h.removed.nil?, "screens: the pause menu keeps Quit Game on the cabinet")
h2 = DSHandlers.new
check(!DesertScreens.hide_pause_quit(h2, "x64-mingw-ucrt") && h2.removed.nil?, "screens: the pause menu keeps Quit Game on the laptop")
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
check(oh.removed.map(&:last) == [:battle_animations, :battle_style, :send_to_boxes, :give_nicknames, :speech_frame, :menu_frame,
                                   :text_input_style, :screen_size] &&
      oh.removed.all? { |m, _| m == :options_menu }, "screens: Options keeps 4 rows (volumes, text speed, movement)")
check(!DesertScreens::HIDDEN_OPTION_IDS.include?(:bgm_volume) && !DesertScreens::HIDDEN_OPTION_IDS.include?(:text_speed),
      "screens: Options keeps the volume and text speed rows")
crows = DesertScreens.card_rows("Dor", "5m", "1.2.2026", 3)
check(crows.map(&:first).select { |t| t.is_a?(String) } == ["Name", "Dor", "Time", "5m", "Started", "1.2.2026", "Depth", "3"],
      "screens: the card shows name, play time, started and depth in order")
check(crows.map(&:first).none? { |t| t =~ /ID No|Money|Pok|Badge|TRAINER/i }, "screens: the card has no ID, money, Pokedex or badge row")
check(DesertScreens.started_text(Time.new(2026, 3, 9)) == "9.3.2026", "screens: the start date is day.month.year")
check(PokemonTrainerCard_Scene.ancestors.first == DesertScreens::TrainerCardRows, "screens: the card scene uses the Desert Town rows")

# TG57 Batch 4: the circus fight gets a plain wipe, War, DT Victory and the circus arena; nothing else changes.
module RPG; class AudioFile; attr_reader :name; def initialize(name, *_a) = (@name = name); end; end unless defined?(RPG::AudioFile)
class DSGlobal; attr_accessor :nextBattleBGM, :nextBattleVictoryBGM; end
$PokemonGlobal = DSGlobal.new
module MomDadBattle
  @ds_active = false
  def self.active? = @ds_active
  def self.active=(v)
    @ds_active = v
  end
end
module SpecialBattleIntroAnimations
  @@ds = []
  def self.register(name, priority, cond, anim) = @@ds.push([name, priority, cond, anim])
  def self.registered = @@ds
end
$ds_rules = []
$ds_seen = []
def setBattleRule(*args) = $ds_rules.push(args)
def pbBattleAnimationCore(anim, _vp, _loc) = ($ds_wipe = anim)
def pbMomDadBattleIntro(_event) = $ds_seen.push([:intro, $PokemonGlobal.nextBattleBGM&.name])
def pbMomDadBattleStart
  $ds_seen.push([:start, $PokemonGlobal.nextBattleBGM&.name, $PokemonGlobal.nextBattleVictoryBGM&.name])
  return 1
end
load File.join(ds_dir, "005_circus_battle.rb")

reg = SpecialBattleIntroAnimations.registered.find { |n, *| n == "desert_circus_intro" }
check(reg && reg[1] > 40 && reg[1] > 60, "screens: the circus wipe outranks the Rocket (40) and vs-trainer (60) intros")
check(!reg[2].call(1, [], 1), "screens: other trainer fights keep their own intro")
MomDadBattle.active = true
check(reg[2].call(1, [], 1), "screens: the circus fight uses the circus wipe")
reg[3].call(nil, 1, [], 1)
check($ds_wipe == "SnakeSquares", "screens: the circus wipe is the stock SnakeSquares, no balls and no Rocket R")
pbMomDadBattleIntro(nil)
check($ds_seen.last == [:intro, "War"], "screens: War plays from the pan before the fight")
check(pbMomDadBattleStart == 1 && $ds_seen.last == [:start, "War", "DT Victory"], "screens: the circus fight plays War and wins into DT Victory")
check($ds_rules.include?(["backdrop", "circus"]), "screens: the circus battleback rule is set")
check($PokemonGlobal.nextBattleBGM.nil? && $PokemonGlobal.nextBattleVictoryBGM.nil?, "screens: the circus music is cleared after the fight")
check(File.exist?(File.join(ROOT, "Audio/BGM/DT Victory.ogg")) && File.exist?(File.join(ROOT, "Audio/BGM/War.ogg")), "screens: War and DT Victory exist on disk")
%w[bg base0 base1 message].each { |n| check(File.exist?(File.join(ROOT, "Graphics/Battlebacks/circus_#{n}.png")), "screens: circus_#{n}.png exists") }

# TG67: the load screen keeps one command; New Game joins the pause menu behind a default-No confirm.
$ds_menu = []
module MenuHandlers; def self.add(menu, id, hash) = $ds_menu.push([menu, id, hash]); end
class Scene_DesertNewGameStub; end
$ds_pb = []
def pbMessage(text, cmds = nil, cancel = 0, skin = nil, default = 0) = ($ds_pb.push([text, cmds, cancel, default]); $ds_answer)
load File.join(ds_dir, "006_menus.rb")

check(DesertScreens.primary_load_command(["Continue", "Mystery Gift", "New Game", "Options", "Quit Game"]) == ["Continue"],
      "screens: with a save the load screen lists only Continue")
check(DesertScreens.primary_load_command(["New Game", "Options", "Quit Game"]) == ["New Game"],
      "screens: with no save the load screen lists only New Game")
cl = ["New Game"]
check(DesertScreens.primary_load_command(cl).equal?(cl) && cl == ["New Game"], "screens: a single row stays and the list is trimmed in place")
ls2 = PokemonLoad_Scene.new
full = ["Continue", "New Game", "Options", "Quit Game"]
ls2.pbStartScene(full)
check(ls2.started == ["Continue"] && full == ["Continue"], "screens: the load scene trims the caller's own list before it builds panels")
check(PokemonLoad_Scene.ancestors.first == DesertScreens::LoadSceneOneCommand, "screens: the load scene uses the one-command list")

load File.join(ds_dir, "007_pause_menu.rb")
check($ds_menu.none? { |_m, id, _h| id == :new_game }, "screens: the old pause-menu New Game is gone")

class DSPauseHandlers
  attr_reader :removed, :rows
  def initialize(seed)
    @rows = {}
    seed.each { |id, order| @rows[id] = { "name" => id.to_s, "order" => order } }
    @removed = []
  end
  def remove(menu, id)
    @removed << [menu, id]
    @rows.delete(id)
  end
  def add(_menu, id, hash) = (@rows[id] = hash)
  def each(_menu) = @rows.each { |id, hash| yield id, hash }
end
seed = DSPauseHandlers.new({
  pokedex: 10, party: 20, bag: 30, pokegear: 40, town_map: 40,
  trainer_card: 50, save: 60, new_game: 65, options: 70, debug: 80, quit_game: 90
})
DesertScreens.install_pause_menu(seed)
check(seed.removed.map(&:last).sort == DesertScreens::HIDDEN_PAUSE_IDS.sort,
      "screens: the pause menu drops the Pokemon rows, Options, Debug and the old New Game")
shown = seed.rows.sort_by { |_id, hash| hash["order"] }.map(&:first)
check(shown == DesertScreens::PAUSE_ORDER.keys,
      "screens: pause order is close, name, bag, save, game in a game, quit, restart pi, start over")
check(seed.rows[:dt_close]["order"] < seed.rows[:trainer_card]["order"],
      "screens: Close Menu is the first pause row")
check(seed.rows[:dt_close]["name"] == "MSG_PAUSE_CLOSE", "screens: the first row is Close Menu")
check(seed.rows[:dt_new_game]["name"] == "Game in a Game", "screens: nested New Game is labeled Game in a Game")
check(seed.rows[:dt_restart_rpi]["name"] == "MSG_PAUSE_RESTART_PI", "screens: Restart Pi has its own label")
check(seed.rows[:dt_wipe_game]["name"] == "Start Over", "screens: full wipe is labeled Start Over")
check(seed.rows.values.none? { |h| h["condition"] }, "screens: every pause row shows on the laptop and the Pi")

class DSMenu
  attr_reader :log
  def initialize = (@log = [])
  def pbHideMenu = @log.push(:hide)
  def pbShowMenu = @log.push(:show)
  def pbRefresh = @log.push(:refresh)
  def pbEndScene = @log.push(:end)
end

$ds_answer = 1
m = DSMenu.new
check(seed.rows[:dt_close]["effect"].call(m) == true && m.log == [:end],
      "screens: Close Menu closes the pause menu")

def pbConfirmMessage(text)
  $ds_pb.push([text])
  return $ds_confirm
end
$ds_old_temp = $game_temp
unless defined?(Game_Temp) && Game_Temp.method_defined?(:desert_town_restart_pending=)
  class Game_Temp
    attr_accessor :desert_town_restart_pending
  end
end
$game_temp = Game_Temp.new
$ds_confirm = false
m = DSMenu.new
check(DesertScreens.pause_nested(m) == false && m.log == [:hide, :refresh, :show],
      "screens: No on nested New Game keeps the pause menu open")
$ds_confirm = true
m = DSMenu.new
check(DesertScreens.pause_nested(m) == true && m.log == [:hide] && $game_temp.desert_town_restart_pending,
      "screens: Yes on nested New Game starts a game inside this one")

$scene = :playing
$ds_answer = 1
m = DSMenu.new
check(DesertScreens.pause_quit(m) == false && m.log == [:hide, :refresh, :show] && $scene == :playing,
      "screens: No on Quit stays in the game")
check($ds_pb.last[3] == 1 && $ds_pb.last[1] == ["Yes", "No"], "screens: Quit highlights No")
$ds_answer = 0
m = DSMenu.new
check(DesertScreens.pause_quit(m) == true && m.log == [:hide, :end] && $scene.nil?,
      "screens: Yes on Quit closes the game")

$ds_reboots = 0
class << DesertScreens
  def reboot_pi
    $ds_reboots += 1
    return true
  end
end
$ds_answer = 0
m = DSMenu.new
check(DesertScreens.pause_restart(m, false) == false && m.log == [:hide, :refresh, :show] && $ds_reboots == 0,
      "screens: Restart Pi on a laptop only says it does not work here")
check($ds_pb.last[0] == "MSG_PAUSE_RESTART_PI_LAPTOP", "screens: the laptop message is the restart-pi line")
$ds_answer = 1
m = DSMenu.new
check(DesertScreens.pause_restart(m, true) == false && m.log == [:hide, :refresh, :show] && $ds_reboots == 0,
      "screens: No on Restart Pi does not reboot")
$ds_answer = 0
m = DSMenu.new
check(DesertScreens.pause_restart(m, true) == true && $ds_reboots == 1,
      "screens: Yes on Restart Pi reboots the cabinet")
check(File.read(File.join(ds_dir, "007_pause_menu.rb"), encoding: "utf-8").include?('system("sudo reboot")'),
      "screens: the cabinet reboot is sudo reboot")

module SaveData
  class << self
    attr_accessor :ds_file
    def exists? = !!@ds_file
    def delete_file
      raise "no save" unless @ds_file
      @ds_file = nil
      return true
    end
  end
end
SaveData.ds_file = "Game.rxdata"
prev_depth = DesertTownArcade.state.depth
DesertTownArcade.state.depth = 4
$ds_answer = 1
m = DSMenu.new
check(DesertScreens.pause_wipe(m) == false && m.log == [:hide, :refresh, :show] &&
      DesertTownArcade.state.depth == 4 && SaveData.ds_file,
      "screens: No on full New Game keeps the save and the depth")
check($ds_pb.last[0] == "MSG_PAUSE_WIPE_CONFIRM" && $ds_pb.last[3] == 1,
      "screens: full New Game asks, with No highlighted")
$ds_answer = 0
m = DSMenu.new
check(DesertScreens.pause_wipe(m) == true && m.log == [:hide, :end] &&
      DesertTownArcade.state.depth == 0 && SaveData.ds_file.nil? && $scene.is_a?(Scene_DesertNewGame),
      "screens: Yes on full New Game deletes the save, clears depth and starts over")
DesertTownArcade.state.depth = prev_depth
$game_temp = $ds_old_temp

tr67 = File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8")
check(tr67.include?("סגור תפריט") && tr67.include?("אתחול פיי") && tr67.include?("משחק חדש לגמרי") &&
      tr67.include?("זה לא עובד כאן.") && tr67.include?("למחוק את כל הנתונים, כולל עומק המשחק?") &&
      tr67.include?("לאתחל את הפיי?"),
      "screens: the pause rows have their Hebrew lines")
