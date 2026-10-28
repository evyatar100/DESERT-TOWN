# Frozen-engine checks for the decision methods in the Desert Town plugins.
# Stubs stand in for RPG Maker and Pokemon Essentials.

ROOT = File.expand_path("..", __dir__)
$failures = []

def check(condition, message)
  if condition
    puts "  PASS: #{message}"
  else
    puts "  FAIL: #{message}"
    $failures << message
  end
end

# Loaded before the engine stubs so its engine hooks stay off; only HebrewText is tested.
load File.join(ROOT, "Plugins/HebrewSupport/hebrew_support.rb")
BIDI_CASES = {
  "ב-1980" => "1980-ב",
  "בשנת 1977 היא" => "איה 1977 תנשב",
  "השיר 9 to 5 של דולי" => "ילוד לש 9 to 5 רישה",
  "20 שקל" => "לקש 20",
  "25,000 ניסיונות" => "תונויסינ 25,000",
  "מה?" => "?המ",
  "50% הנחה" => "החנה 50%",
  "בשנת 1980." => ".1980 תנשב",
  "ראיתי 9 to 5!" => "!9 to 5 יתיאר",
  "12:30 בבוקר" => "רקובב 12:30",
}
BIDI_CASES.each do |logical, visual|
  got = HebrewText.visual_reverse(logical)
  check(got == visual, "bidi menu: #{logical} draws as #{visual} (got #{got})")
end
check(HebrewText.visual_reverse("Hello 9 to 5!") == "Hello 9 to 5!", "bidi menu: pure English is unchanged")
require "json"
reward_he = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]["TEMPLE_REWARD_1"]["he"]
check(reward_he.include?("8:00 & א") && HebrewText.visual_reverse(reward_he).include?(".א & 8:00 העש"),
      "bidi reward: the Hebrew address draws as 'שעה 8:00 & א' right to left")
check(HebrewText.visual_reverse("שלום\n20 שקל") == "םולש\nלקש 20", "bidi menu: each line is reordered on its own")

# Equal-width synthetic fmtchars: [text, x, y, width, height, graphic].
def bidi_fmt_visual(tokens)
  line = tokens.each_with_index.map do |t, i|
    t.is_a?(Array) ? [t[0], i * 10, 0, 10, 32, true] : [t, i * 10, 0, 10, 32, false]
  end
  HebrewText.mirror_fmtchars_line(line)
  line.sort_by { |c| c[1] }.map { |c| c[5] ? "[#{c[0]}]" : c[0] }.join
end
BIDI_CASES.each do |logical, visual|
  got = bidi_fmt_visual(logical.chars)
  check(got == visual, "bidi message: #{logical} lays out as #{visual} (got #{got})")
end
xs = [["ב", 0, 0, 10, 32, false], ["-", 10, 0, 10, 32, false], ["1", 20, 0, 10, 32, false]]
HebrewText.mirror_fmtchars_line(xs)
check(xs.map { |c| c[1] } == [20, 10, 0], "bidi message: ב-1 keeps the line's box and puts ב on the right")
icon = bidi_fmt_visual(["ש", "ל", " ", ["bagPocket8"], " ", "x", "2"])
check(icon == "[bagPocket8] x2 לש", "bidi message: an icon joins the LTR run next to it (got #{icon})")

# Niqqud: letters 10 px, marks 0 px (or 2 px); each mark must sit centred on its own letter.
def niqqud_line(word, mark_w)
  x = 0
  word.chars.map do |ch|
    w = ch.match?(HebrewText::MARK_ONLY) ? mark_w : 10
    c = [ch, x, 0, w, 32, false]
    x += w
    c
  end
end
SAKIT = "שַׂקִּית"
[0, 2].each do |mark_w|
  word = SAKIT
  line = niqqud_line(word, mark_w)
  bases = {}
  line.each_with_index { |c, i| bases[i] = (c[0].match?(HebrewText::MARK_ONLY) ? bases[i - 1] : c) }
  HebrewText.mirror_fmtchars_line(line)
  on_own = line.each_with_index.all? do |c, i|
    b = bases[i]
    b.equal?(c) || (c[1] * 2 + c[3] == b[1] * 2 + b[3])
  end
  letters = line.reject { |c| c[0].match?(HebrewText::MARK_ONLY) }.sort_by { |c| c[1] }.map { |c| c[0] }.join
  check(on_own && letters == "תיקש" && line.map { |c| c[1] }.min == 0,
        "bidi niqqud (mark #{mark_w}px): each mark is centred on its own letter in #{word}")
end
check(HebrewText.visual_reverse(SAKIT) == "תיקִּשַׂ", "bidi niqqud: menus keep each mark after its letter")
check(HebrewText.visual_reverse("בית־ספר") == "רפס־תיב", "bidi niqqud: maqaf is a character of its own, not a mark")

class PokemonBag
  def reset_last_selections; end
  def last_viewed_pocket; 0; end
end

class PokemonBag_Scene
  def pbStartScene(*); end
  def pbRefresh; end
end

class Window_DrawableCommand
  def drawItem(*); end
end

class Window_PokemonBag < Window_DrawableCommand
end

class PokemonBagScreen
end

$game_calls = []
module Game
  class << self
    def start_new
      $game_calls << :start_new
    end
    def load(_data); end
    def save(*); true; end
  end
end

$event_handlers = {}
module EventHandlers
  def self.add(_event, name, handler = nil, &block)
    $event_handlers[name] = handler || block
  end
end

module SaveData
  def self.register(*); end

  def self.mark_values_as_unloaded
    $game_calls << :mark_values_as_unloaded
  end
end

class Game_Temp
end

class Scene_Map
  def update; end
  def call_menu; end
end

load File.join(ROOT, "Plugins/BurningManBag/burning_man_bag.rb")
load File.join(ROOT, "Plugins/HebrewSupport/ice_in_timer.rb")
load File.join(ROOT, "Plugins/HebrewSupport/ice_seller.rb")

# Stub the real Input module so 000_controls.rb can alias it. C/X/Z are the
# original trigger/press path. Color keys arrive through triggerex?/pressex?.
module Input
  USE = :USE
  BACK = :BACK
  ACTION = :ACTION
  UP = :UP
  DOWN = :DOWN
  LEFT = :LEFT
  RIGHT = :RIGHT
  JUMPUP = :JUMPUP
  JUMPDOWN = :JUMPDOWN
  SPECIAL = :SPECIAL
  AUX1 = :AUX1
  AUX2 = :AUX2

  def self.trigger?(button)
    $dt_trigger == button
  end

  def self.press?(button)
    $dt_press == button
  end

  def self.repeat?(_button)
    false
  end

  def self.triggerex?(key)
    $dt_raw_trigger == key
  end

  def self.pressex?(key)
    $dt_raw_press == key
  end

  def self.repeatex?(_key)
    false
  end

  def self.update; end
end

$dt_trigger = nil
$dt_press = nil
$dt_raw_trigger = nil
$dt_raw_press = nil

load File.join(ROOT, "Plugins/DesertTownArcade/000_controls.rb")
load File.join(ROOT, "Plugins/DesertTownArcade/001_bag_button.rb")
load File.join(ROOT, "Plugins/DesertTownArcade/003_autosave.rb")
load File.join(ROOT, "Plugins/DesertTownArcade/004_arcade_new_game.rb")

class QuantityBag
  attr_reader :items

  def initialize(items)
    @items = Hash.new(0)
    items.each { |key, value| @items[key] = value }
  end

  def quantity(item_id)
    @items[item_id] || 0
  end

  def remove(item_id, amount = 1)
    @items[item_id] = quantity(item_id) - amount
  end

  def add(item_id, amount = 1)
    @items[item_id] = quantity(item_id) + amount
  end
end

def _INTL(message, *_args)
  message
end

$messages = []
def pbMessage(message)
  $messages << message
end

$received = []
def pbReceiveItem(item)
  $received << item
end

$scripted_choices = []
def pbShowCommands(_window, _commands, _cancel_index)
  raise "pbIceSeller asked for a choice but the test queued none" if $scripted_choices.empty?
  $scripted_choices.shift
end

def run_seller(bills, choices)
  $bag = QuantityBag.new({ TWENTYSHECKELBILL: bills })
  $messages = []
  $received = []
  $scripted_choices = choices.dup
  pbIceSeller
  $bag
end

# --- ice seller decisions ---
check(IceSellerRules.decide(0, 5) == :purchase, "5 bills purchases an ice bag")
check(IceSellerRules.decide(0, 4) == :not_enough, "4 bills is not enough")
check(IceSellerRules.decide(1, 0) == :line, "choice 1 explains the line")
check(IceSellerRules.decide(4, 9) == :exit, "exit choice leaves")
check(IceSellerRules.decide(5, 9) == :exit, "cancel leaves")

bag = run_seller(5, [0])
check(bag.quantity(:TWENTYSHECKELBILL) == 0, "purchase removes 5 bills")
check($received == [:ICEBAG], "purchase gives ICEBAG")
check($messages.include?("POPCORN_RESPONSE_THANKS"), "purchase thanks the player")

bag = run_seller(3, [0, 4])
check(bag.quantity(:TWENTYSHECKELBILL) == 3, "not enough keeps the bills")
check($received.empty?, "not enough does not give ICEBAG")
check($messages.include?("POPCORN_RESPONSE_NOT_ENOUGH"), "not enough explains the price")

bag = run_seller(5, [5])
check(bag.quantity(:TWENTYSHECKELBILL) == 5, "cancel keeps the bills")
check($received.empty?, "cancel does not give ICEBAG")

bag = run_seller(5, [4])
check(bag.quantity(:TWENTYSHECKELBILL) == 5, "exit choice keeps the bills")
check($received.empty?, "exit choice does not give ICEBAG")

# --- ice timer ---
stats = Object.new
class << stats
  attr_accessor :play_time
end
stats.play_time = 1_000
$stats = stats

game_map = Object.new
class << game_map
  attr_accessor :map_id
end
game_map.map_id = IceInTimer::ICE_IN_MAP_ID
$game_map = game_map

check(IceInTimer.seconds_remaining(1_000, 1_000, 420) == 420, "timer starts at 7 minutes")
check(IceInTimer.seconds_remaining(1_419, 1_000, 420) == 1, "419 seconds still has time left")
check(IceInTimer.seconds_remaining(1_420, 1_000, 420) == 0, "420 seconds is the timeout")

IceInTimer.stop
IceInTimer.start
check(!IceInTimer.expired?, "a fresh timer is not expired")
stats.play_time = 1_000 + 419
check(!IceInTimer.expired?, "419 seconds on the ice map is not expired")
stats.play_time = 1_000 + 420
check(IceInTimer.expired?, "420 seconds on the ice map expires")

$transfers = []
def pbTransferPlayer(map_id, x, y, direction = 2)
  $transfers << [map_id, x, y, direction]
end

$messages = []
IceInTimer.trigger_rescue
dest = IceInTimer.rescue_destination
check($transfers == [dest], "rescue requests a transfer to map 91 at (41, 35)")
check(dest == [91, 41, 35, 2], "rescue destination is Ice Camp (41, 35)")
check($messages.include?("MSG_ICE_IN_TIMEOUT"), "rescue shows the timeout message")

$transfers = []
IceInTimer.instance_variable_set(:@rescuing, true)
IceInTimer.trigger_rescue
check($transfers.empty?, "a second rescue does not start while one is running")

# --- DesertTalk speaker ---
load File.join(ROOT, "Plugins/DesertTalk/characters.rb")
load File.join(ROOT, "Plugins/DesertTalk/desert_talk.rb")

$game_temp = Object.new
class << $game_temp
  attr_accessor :message_window_showing, :in_battle, :begun_new_game
end
$game_temp.message_window_showing = false
$game_temp.in_battle = false

$map_interpreter_running = true
def pbMapInterpreterRunning?
  $map_interpreter_running
end

$messages = []
pbDesertSpeaker("11eaf4fa")
check(DesertTalk.name_key == "NAME_11EAF4FA", "pbDesertSpeaker sets the speaker name")
pbMessage(_INTL("MSG_11EAF4FA_LINE"))
check(DesertTalk.name_key == "NAME_11EAF4FA", "speaker survives the first message")
pbMessage(_INTL("MSG_11EAF4FA_LINE"))
check(DesertTalk.name_key == "NAME_11EAF4FA", "speaker survives the second message")

clear_speaker = $event_handlers[:desert_talk_clear_speaker]
check(!clear_speaker.nil?, "DesertTalk registers an event-end speaker clear")
clear_speaker.call
check(DesertTalk.name_key == "NAME_11EAF4FA", "speaker stays while the event interpreter runs")
$map_interpreter_running = false
clear_speaker.call
check(DesertTalk.name_key.nil?, "speaker clears when the event interpreter stops")

$messages = []
pbDesertSpeaker("11eaf4fa")
pbDesertTalk("11eaf4fa")
check($messages == ["MSG_11EAF4FA_LINE"], "pbDesertTalk speaks the default line")
check(DesertTalk.name_key == "NAME_11EAF4FA", "pbDesertTalk leaves the speaker set")

DesertTalk.clear_name
$messages = []
pbDesertTalk("11eaf4fa")
check($messages == ["MSG_11EAF4FA_LINE"], "standalone pbDesertTalk speaks the default line")
check(DesertTalk.name_key.nil?, "standalone pbDesertTalk does not set a speaker")

begin
  pbDesertSpeaker("deadbeef")
  check(false, "unknown speaker id raises")
rescue RuntimeError
  check(true, "unknown speaker id raises")
end

begin
  pbDesertTalk("deadbeef")
  check(false, "unknown talk id raises")
rescue RuntimeError
  check(true, "unknown talk id raises")
end

# --- starter items ---
[0, 1, 4].each do |amount|
  pocket = QuantityBag.new({ WHITEWATERBOTTLE: amount })
  BurningManBag.normalize_starter_quantity(pocket, :WHITEWATERBOTTLE)
  check(pocket.quantity(:WHITEWATERBOTTLE) == 1, "starter quantity #{amount} becomes 1")
end

module GameData
  module Item
    def self.exists?(_item_id)
      true
    end
  end
end

pocket = QuantityBag.new({ WHITEWATERBOTTLE: 3, USBDISK: 0 })
BurningManBag.ensure_single_starter_items(pocket)
check(pocket.quantity(:WHITEWATERBOTTLE) == 1, "three bottles collapse to one")
check(pocket.quantity(:USBDISK) == 1, "a missing disk is added once")
check(pocket.quantity(:EVENTPROGRAM) == 1, "a missing event program is added once")

# --- arcade autosave ---
interval = DesertTownAutosave::INTERVAL
check(interval == 1_200, "autosave interval is 20 minutes")
check(DesertTownAutosave.due?(5_000, nil), "no previous save is due")
check(!DesertTownAutosave.due?(1_000 + 1_199, 1_000), "1199 seconds after a save is not due")
check(DesertTownAutosave.due?(1_000 + 1_200, 1_000), "1200 seconds after a save is due")
check(DesertTownAutosave.due?(1_000 + 5_000, 1_000), "well past the interval is due")
check(!DesertTownAutosave.due?(nil, 1_000), "no clock is never due")

check(DesertTownAutosave.inside_to_outside?(false, true), "indoor to outdoor saves")
check(!DesertTownAutosave.inside_to_outside?(true, false), "outdoor to indoor does not save")
check(!DesertTownAutosave.inside_to_outside?(true, true), "outdoor to outdoor does not save")
check(!DesertTownAutosave.inside_to_outside?(false, false), "indoor to indoor does not save")
check(DesertTownAutosave.inside_to_outside?(nil, true), "unknown old map counts as indoor")
check(!DesertTownAutosave.inside_to_outside?(false, nil), "unknown new map counts as indoor")

# --- arcade bag button ---
check(DesertTownArcade.bag_button_allowed?(false, false, false, false, false), "idle map accepts the bag button")
check(!DesertTownArcade.bag_button_allowed?(true, false, false, false, false), "running event blocks the bag button")
check(!DesertTownArcade.bag_button_allowed?(false, true, false, false, false), "open message blocks the bag button")
check(!DesertTownArcade.bag_button_allowed?(false, false, true, false, false), "moving player blocks the bag button")
check(!DesertTownArcade.bag_button_allowed?(false, false, false, true, false), "menu_disabled blocks the bag button")
check(!DesertTownArcade.bag_button_allowed?(false, false, false, false, true), "forced movement blocks the bag button")

# --- arcade depth ---
check(DesertTownArcadeState.next_depth(nil) == 1, "first new game is depth 1")
check(DesertTownArcadeState.next_depth(0) == 1, "depth 0 becomes 1")
check(DesertTownArcadeState.next_depth(7) == 8, "depth 7 becomes 8")
check(DesertTownArcadeState.new.depth == 0, "a fresh cabinet state starts at depth 0")

# --- arcade restart bridge ---
# Game.start_new only resets save values that are unloaded. Mid-game they are
# all loaded, so the bridge must unload them first or the nested game keeps the
# old player and Map001's intro self switch, skipping pbDesertCharSelect.
$game_system = Object.new
class << $game_system
  attr_accessor :save_disabled, :menu_disabled
end
$game_system.save_disabled = true
$game_system.menu_disabled = true
$player = Object.new
$game_calls = []
Scene_DesertTownRestart.new.main
check($game_calls == [:mark_values_as_unloaded, :start_new],
      "restart bridge unloads save values before Game.start_new")
check($game_system.save_disabled == false, "restart bridge re-enables saving")
check($game_system.menu_disabled == false, "restart bridge re-enables the menu")

# --- color buttons ---
check(DesertTownControls.color_keys == [:H, :J, :K, :F, :G, :N], "color keys are H J K F G N")
check(!DesertTownControls::COLORS.key?(:red), "there is no red button")
check(DesertTownControls::COLORS.keys.sort == %i[blue green orange pink white yellow],
      "the panel has exactly yellow, blue, orange, white, green, pink")
taken = DesertTownControls::TAKEN_KEYS.keys
DesertTownControls.color_keys.each do |key|
  check(!taken.include?(key), "color key #{key} is free")
end
check(DesertTownControls::MIRROR_INPUT[:yellow] == :USE, "yellow mirrors Use, the C input")
check(DesertTownControls::MIRROR_INPUT[:blue] == :BACK, "blue mirrors Back, the X input")
check(DesertTownControls::MIRROR_INPUT.select { |_color, input| input == :ACTION }.keys == [:pink],
      "only pink mirrors the Z menu")
check(DesertTownArcade::BAG_KEY == :B, "B is still the existing bag key")

check(DesertTownControls.bag_toggle(false, false) == :none, "no orange press leaves the bag alone")
check(DesertTownControls.bag_toggle(false, true) == :open, "orange on the map opens the bag")
check(DesertTownControls.bag_toggle(true, true) == :close, "orange in the bag closes it")
check(DesertTownControls.bag_toggle(true, false) == :none, "an open bag stays open without a new press")

%i[USE BACK ACTION UP DOWN LEFT RIGHT JUMPUP JUMPDOWN SPECIAL AUX1 AUX2].each do |input|
  check(DesertTownControls.slide_should_close?([input], []), "#{input} closes a slide")
end
%i[A S D C X Z F G H J K N SPACE RETURN ESCAPE].each do |key|
  check(DesertTownControls.slide_should_close?([], [key]), "#{key} closes a slide")
end
check(!DesertTownControls.slide_should_close?([], []), "a slide stays up until a button")

$dt_trigger = Input::USE
$dt_raw_trigger = nil
check(Input.trigger?(Input::USE), "C still confirms")
check(!Input.trigger?(Input::ACTION), "C does not open the menu")

$dt_trigger = nil
$dt_raw_trigger = :H
check(Input.trigger?(Input::USE), "yellow confirms like C")
check(!Input.trigger?(Input::BACK), "yellow does not cancel")
check(!Input.trigger?(Input::ACTION), "yellow does not open the menu")

$dt_trigger = Input::ACTION
$dt_raw_trigger = nil
check(Input.trigger?(Input::ACTION), "Z still opens the menu")
check(!Input.trigger?(Input::USE), "Z does not confirm")

$dt_trigger = nil
$dt_press = Input::BACK
$dt_raw_press = nil
check(Input.press?(Input::BACK), "holding X still runs")
check(!Input.press?(Input::ACTION), "holding X does not open the menu")

$dt_press = nil
$dt_raw_press = :J
check(Input.press?(Input::BACK), "holding blue runs like X")
check(!Input.press?(Input::USE), "holding blue does not confirm")
check(!Input.press?(Input::ACTION), "holding blue does not open the menu")

$dt_press = nil
$dt_raw_press = nil
$dt_trigger = nil
$dt_raw_trigger = :N
check(Input.trigger?(Input::ACTION), "pink opens the menu like Z")
check(!Input.trigger?(Input::USE), "pink does not confirm")
check(!Input.trigger?(Input::BACK), "pink does not cancel")
check(!DesertTownArcade.bag_key_pressed?, "pink does not request the bag")

$dt_trigger = nil
$dt_press = nil
$dt_raw_trigger = nil
$dt_raw_press = nil
$dt_raw_trigger = :B
check(DesertTownArcade.bag_key_pressed?, "B still requests the bag")
$dt_raw_trigger = :K
check(DesertTownArcade.bag_key_pressed?, "orange requests the bag")
$dt_raw_trigger = :H
check(!DesertTownArcade.bag_key_pressed?, "yellow does not request the bag")

DesertTownControls.begin_bag_screen
$dt_raw_trigger = :K
Input.update
check(DesertTownControls.bag_close?, "orange inside the bag latches a close")
check(Input.trigger?(Input::BACK), "the latch is seen as cancel")
check(!Input.trigger?(Input::USE), "the latch does not confirm")
DesertTownControls.end_bag_screen
$dt_raw_trigger = nil
check(!Input.trigger?(Input::BACK), "leaving the bag clears the forced cancel")
check(!DesertTownControls.bag_screen_open?, "the bag screen flag is cleared")

slide_src = File.read(File.join(ROOT, "Plugins/DesertTownArcade/000_controls.rb"))
show = slide_src.split("def self.show_slide_if_requested?", 2).last
show = show.split("def self.slide_closed_now?", 2).first
%w[Audio. pbBGM bgm_play bgm_stop bgm_fade bgm_pause bgm_resume].each do |token|
  check(!show.include?(token), "slide code does not call #{token}")
end

load File.join(ROOT, "Plugins/zFlamingoBand/000_rules.rb")
load File.join(ROOT, "Plugins/MomDadBattle/000_rules.rb")
band = FlamingoBandRules.new_state
check(FlamingoBandRules.claim(band, "c626f0d6", 77).nil?, "band: nothing before the intro")
band[:intro_done] = true
check(FlamingoBandRules.claim(band, "9923f1c4", 77).nil?, "band: the host never counts")
check(FlamingoBandRules.claim(band, "c626f0d6", 112).nil?, "band: wrong map gives nil")
check(FlamingoBandRules.claim(band, "468de6d4", 77).nil?, "band: a non-band character gives nil")
check(FlamingoBandRules.claim(band, "1988218f", 99) == 1, "band: first eligible talk is stage 1")
check(FlamingoBandRules.claim(band, "1988218f", 99).nil?, "band: a repeat talk is not counted")
check(FlamingoBandRules.claim(band, "708d6c34", 77) == 2, "band: second NPC is stage 2")
check(FlamingoBandRules.claim(band, "5990bffc", 99) == 3, "band: third NPC is stage 3")
check(FlamingoBandRules.claim(band, "754ba04a", 77) == 4, "band: fourth NPC is stage 4")
check(FlamingoBandRules.claim(band, "671405a6", 77).nil?, "band: nothing after stage 4")
check(band[:consumed] == %w[1988218f 708d6c34 5990bffc 754ba04a], "band: consumed in talk order")
check(FlamingoBandRules.stage_line(4) == "MSG_FLAMINGO_BAND_4", "band: stage 4 line key")
check(FlamingoBandRules.music_for(band, 77) == "Flamingo Band stage_4", "band: stage track on map 77")
check(FlamingoBandRules.music_for(band, 50) == :original, "band: other maps keep their music")
check(FlamingoBandRules.music_for(FlamingoBandRules.new_state.merge(intro_done: true), 99) == :silence,
      "band: silence after the intro")
check(FlamingoBandRules.start_procession?(band, 99, 77), "band: procession starts leaving the tent")
check(!FlamingoBandRules.start_procession?(band, 76, 77), "band: not from another map")
band[:procession] = true
check(FlamingoBandRules.music_for(band, 50) == "Flamingo Band stage_4", "band: procession plays stage 4 anywhere")
calls = 0
rng = lambda { calls += 1; 0.1 }
check(FlamingoBandRules.roll(100, 200, rng) == [200, false] && calls == 0, "band: no roll before due")
interval = FlamingoBandRules::ROLL_INTERVAL
check(interval == 90, "band: interruption roll every 90 s")
check(FlamingoBandRules.roll(200, 200, rng) == [200 + interval, true] && calls == 1, "band: one roll when due")
check(FlamingoBandRules.roll(900, 200, lambda { FlamingoBandRules::ROLL_CHANCE }) == [900 + interval, false], "band: ROLL_CHANCE is not a hit")
check(FlamingoBandRules.roll(900, 200, lambda { FlamingoBandRules::ROLL_CHANCE - 0.0001 })[1], "band: below ROLL_CHANCE is a hit")
check(FlamingoBandRules.roll(50, nil, rng) == [50 + interval, false] && calls == 1, "band: first schedule does not roll")
check(!FlamingoBandRules.skip_step?(true, 1, 0.0, true), "band: never two misses in a row")
check(!FlamingoBandRules.skip_step?(false, 2, 0.0, true), "band: never skip when 2 tiles behind")
check(!FlamingoBandRules.skip_step?(false, 1, 0.0, false), "band: never skip on a corner")
check(FlamingoBandRules.skip_step?(false, 1, 0.19, true), "band: skip below 20%")
check(!FlamingoBandRules.skip_step?(false, 1, 0.2, true), "band: 20% is not a skip")
check(FlamingoBandRules.straight_step?(1, 0, 6), "band: step along the leader's facing is straight")
check(!FlamingoBandRules.straight_step?(1, 0, 2), "band: leader turned, so it is a corner")
check(!FlamingoBandRules.straight_step?(0, 0, 6), "band: no step is not straight")
check(FlamingoBandRules.spawn_offsets.all? { |dx, dy| (dx.abs + dy.abs).between?(4, 6) }, "band: spawn 4-6 tiles away")
check(FlamingoBandRules.in_intro_zone?(77, 12, 26) && !FlamingoBandRules.in_intro_zone?(77, 20, 26),
      "band: intro zone bounds")

escape = FlamingoBandRules.new_state
check(FlamingoBandRules.escape_action(escape) == :none, "band escape: nothing before the intro")
escape[:intro_done] = true
check(FlamingoBandRules.escape_action(escape) == :catch, "band escape: first attempt is caught")
escape[:escape_attempts] = 1
check(FlamingoBandRules.escape_action(escape) == :release, "band escape: second attempt is released")
escape[:stage] = 4
check(FlamingoBandRules.escape_action(escape) == :none, "band escape: stage 4 leaves normally")
escape[:stage] = 2
escape[:procession] = true
check(FlamingoBandRules.escape_action(escape) == :none, "band escape: never during the procession")
old_save = FlamingoBandRules.new_state.reject { |k, _| k == :escape_attempts }.merge(intro_done: true)
check(FlamingoBandRules.escape_action(old_save) == :catch, "band escape: old saves without the key are caught once")
check(FlamingoBandRules.new_state[:escape_attempts] == 0, "band escape: new state starts at zero")

fresh = FlamingoBandRules.new_state
check(!fresh.key?(:finished), "band end: no permanent finished flag")
old_finished = { intro_done: true, stage: 4, consumed: %w[c626f0d6], procession: false, next_roll_at: nil,
                 escape_attempts: 0, finished: true }
check(FlamingoBandRules.normalize(old_finished) == fresh, "band end: old save with finished: true loads as a fresh quest")
check(FlamingoBandRules.normalize(nil) == fresh, "band end: missing state is a fresh quest")
running = fresh.merge(intro_done: true, stage: 2, consumed: %w[c626f0d6 671405a6])
check(FlamingoBandRules.normalize(running).equal?(running), "band end: a running quest is kept as is")
check(FlamingoBandRules.rolling?(fresh.merge(procession: true)) && !FlamingoBandRules.rolling?(fresh),
      "band: only the procession rolls")
start_now, held = FlamingoBandRules.intro_gate(fresh, true, true)
check(!start_now && held, "band end: no intro while still standing in the zone")
start_now, held = FlamingoBandRules.intro_gate(fresh, held, false)
check(!start_now && !held, "band end: leaving the zone clears the hold")
start_now, held = FlamingoBandRules.intro_gate(fresh, held, true)
check(start_now && !held, "band end: re-entering the zone makes the intro due again")
check(!FlamingoBandRules.intro_gate(running, false, true)[0], "band: no intro once it has played")
check(FlamingoBandRules.claim(fresh.merge(intro_done: true), "c626f0d6", 77) == 1, "band end: all flamingos eligible again")

# Temple sticker boards: pure units only (scenes need the engine).
require "tmpdir"
temple_dir = File.join(ROOT, "Plugins/TempleStickers")
%w[000_data 001_key_buffer 002_staff 003_run 004_wall_store 006_art 009_signs 010_reward].each { |f| load File.join(temple_dir, "#{f}.rb") }
TS = TempleStickers
temple_ids = %w[KUSAMA_DOT KUSAMA_MIRROR KUSAMA_PUMPKIN YONATH_CRYSTAL YONATH_BEAR YONATH_KEY
                CURRY_TOAST CURRY_BUBBLE CURRY_TICKET PARTON_BOOK PARTON_NAILS PARTON_SONG]
check(TS::STICKERS.keys.sort == temple_ids.sort, "temple: the 12 stickers are Michal's final list")
check(TS::HONOREES.all? { |h| TS.stickers_for(h).length == 3 }, "temple: 3 stickers per honoree")
check(TS::STICKERS.select { |_, s| s[:map] == 113 }.keys.sort == %w[CURRY_TOAST KUSAMA_DOT PARTON_BOOK YONATH_CRYSTAL],
      "temple: the 4 pedestal stickers are dot, crystal, toast, book")
check(TS::STICKERS["CURRY_TICKET"].values_at(:map, :x, :y) == [96, 17, 43], "temple: the ticket moved to town (17,43)")
check(TS.depth == DesertTownArcade.depth, "temple: tabs follow the arcade Inception depth")

FOUR = %w[KUSAMA_DOT YONATH_KEY CURRY_TOAST PARTON_BOOK].freeze   # one per honoree
check(!TS.respond_to?(:deal), "temple run: no random dealt hand")
run = TS.new_run(Random.new(7))
check(run[:run_id].match?(/\A\h{16}\z/) && run[:collected].empty? && run[:placed].empty? && !run.key?(:hand),
      "temple run: fresh run shape, no hand")
check(TS.normalize_run(nil)[:collected].empty?, "temple run: an old save without the key gets a fresh run")
check(TS.normalize_run({ run_id: "" })[:run_id] != "", "temple run: a broken run is replaced")
check(TS.normalize_run(run) == run, "temple run: a valid run loads unchanged")
check(TS.placeable(run).empty?, "temple run: nothing placeable before collecting")
check(!TS.record_placement(run, "KUSAMA_DOT", "kusama"), "temple run: cannot place an uncollected sticker")
check(TS.collect(run, "KUSAMA_DOT") && !TS.collect(run, "KUSAMA_DOT"), "temple run: collect once only")
check(!TS.collect(run, "NOPE") && run[:collected] == ["KUSAMA_DOT"], "temple run: an unknown sticker is not collected")
all_run = TS.new_run(Random.new(8))
check(TS::STICKERS.keys.all? { |s| TS.collect(all_run, s) } && TS.placeable(all_run) == TS::STICKERS.keys,
      "temple run: all 12 stickers can be held at once")
check(TS::HONOREES.all? { |b| TS.placeable_on(all_run, b).length == 3 }, "temple tray: at most 3 stickers fit a board's 4 slots")
check(TS.set_name(run, "  עידו ") == "עידו" && TS.set_name(run, " ").nil? && run[:name].nil?, "temple run: set_name trims and clears")

WS = TS::WallStore
ok_save = ->(_w) { true }
Dir.mktmpdir("temple") do |dir|
  wall = WS.load(dir)
  check(WS.last_status == :missing && wall == WS.empty_wall, "temple wall: no file gives an empty wall")
  a = WS.add_item(wall, "kusama", 3, "runA", "KUSAMA_DOT", 3, "עידו", 100)
  check(a && WS.pages(wall, "kusama")[0].values_at("depth", "sheet") == [3, 0], "temple tab: first sticker makes the depth-3 tab")
  check(WS.add_item(wall, "kusama", 3, "runB", "YONATH_KEY", 3).nil?, "temple tab: a taken cell is refused")
  check(WS.add_item(wall, "kusama", 3, "runB", "YONATH_KEY", 4), "temple tab: another run at the same depth shares the tab")
  check(WS.add_item(wall, "yonath", 3, "runA", "KUSAMA_DOT", 0).nil?, "temple tab: a run cannot place a sticker twice")
  check(WS.add_item(wall, "kusama", 3, "runC", "CURRY_TOAST", 99).nil?, "temple tab: a cell off the page is refused")
  WS.add_item(wall, "kusama", 1, "runD", "CURRY_TOAST", 0)
  WS.add_item(wall, "kusama", 5, "runE", "CURRY_TOAST", 0)
  check(WS.pages(wall, "kusama").map { |p| p["depth"] } == [1, 3, 5], "temple tab: tabs are ordered by depth")
  check(WS.target(wall, "kusama", 3).equal?(WS.pages(wall, "kusama")[1]), "temple tab: depth 3 writes on its own tab")
  full = WS.empty_wall
  28.times { |c| WS.add_item(full, "parton", 2, "run#{c}", "PARTON_BOOK", c) }
  check(WS.target(full, "parton", 2).values_at("sheet", "items") == [1, []], "temple tab: a full tab grows a new sheet")
  check(WS.add_item(full, "parton", 2, "late", "PARTON_BOOK", 0) && WS.pages(full, "parton").length == 2, "temple tab: the new sheet is stored on use")

  check(WS.save(dir, wall) && !File.exist?(WS.path(dir) + ".tmp"), "temple wall: save leaves no tmp file")
  first_bytes = File.binread(WS.path(dir))
  check(WS.load(dir) == wall && WS.last_status == :ok, "temple wall: round trip keeps depths, names and Hebrew")
  WS.add_item(wall, "curry", 3, "runB", "CURRY_TICKET", 0)
  WS.save(dir, wall)
  check(File.binread(WS.path(dir) + ".bak") == first_bytes, "temple wall: .bak holds the previous file")

  # QA sequence: corrupt main, load, load again, place.
  File.binwrite(WS.path(dir), "not a marshal file")
  first = WS.load(dir)
  check(WS.last_status == :restored_bak && Dir.glob(File.join(dir, "temple_wall.bad-*.dat")).length == 1, "temple wall: corrupt main is quarantined, .bak used")
  check(File.binread(WS.path(dir)) == first_bytes, "temple wall: the .bak is written back as the main file")
  second = WS.load(dir)
  check(WS.last_status == :ok && second == first, "temple wall: the second load reads the restored main file")
  qa_run = TS.new_run(Random.new(11))
  TS.collect(qa_run, "YONATH_KEY")
  outcome, _ = TS.place(second, qa_run, "yonath", 3, "YONATH_KEY", 5, ->(w) { WS.save(dir, w) })
  check(outcome == :ok && WS.load(dir)["boards"]["kusama"].length == 3, "temple wall: placing after recovery keeps the old pages")
  File.delete(WS.path(dir))
  check(WS.load(dir)["boards"]["yonath"].empty? && WS.last_status == :restored_bak, "temple wall: missing main falls back to .bak")
  check(File.exist?(WS.path(dir)), "temple wall: and restores it as main")
  File.delete(WS.path(dir) + ".bak")
  File.binwrite(WS.path(dir), Marshal.dump([1, 2, 3]))
  check(WS.load(dir) == WS.empty_wall && WS.last_status == :quarantined, "temple wall: wrong shape, no .bak: empty wall")

  v1 = { "v" => 1, "boards" => { "kusama" => [{ "run" => "old", "name" => "דנה", "t" => 5,
                                               "items" => [{ "s" => "KUSAMA_DOT", "c" => 2, "text" => "שלום" }, { "s" => "RICE", "c" => 1 }] }, 5] } }
  migrated = WS.sanitize(v1)["boards"]["kusama"]
  check(migrated.length == 1 && migrated[0].values_at("depth", "sheet") == [0, 0], "temple wall: a v1 page migrates to depth 0")
  check(migrated[0]["items"] == [{ "s" => "KUSAMA_DOT", "p" => 4, "run" => "old", "name" => "דנה", "text" => "שלום" }],
        "temple wall: v1 names move onto items; unknown stickers dropped; cell 2 becomes spot 4")
  over = WS.empty_wall
  over["boards"]["curry"] = (0..304).map { |d| { "depth" => d, "sheet" => 0, "t" => 0, "items" => [] } }
  trimmed = WS.sanitize(over)["boards"]["curry"]
  check(trimmed.length == 300 && trimmed[0]["depth"] == 5, "temple wall: load trims to the cap, lowest depths first")
  big = WS.empty_wall
  301.times { |d| WS.add_item(big, "parton", d, "run#{d}", "PARTON_BOOK", 0) }
  check(WS.pages(big, "parton").length == 300 && WS.pages(big, "parton")[0]["depth"] == 1, "temple wall: cap 300 drops the lowest depth")
  low = WS.add_item(big, "parton", 0, "again", "PARTON_BOOK", 0)
  check(low && WS.pages(big, "parton")[0]["depth"] == 0, "temple wall: the cap never drops the page just written")

  WS.delete_text(wall, "kusama", 1, 3)
  check(WS.find_item(WS.pages(wall, "kusama")[1], 3)["text"].nil?, "temple staff: delete sentence keeps the sticker")
  WS.delete_item(wall, "kusama", 1, 3)
  check(WS.find_item(WS.pages(wall, "kusama")[1], 3).nil?, "temple staff: delete sticker")
  check(WS.delete_page(wall, "kusama", 0) && WS.pages(wall, "kusama").length == 2, "temple staff: delete page")
  WS.wipe_all(dir, wall)
  check(wall == WS.empty_wall && Dir.glob(File.join(dir, "temple_wall.wiped-*.dat")).length == 1, "temple staff: wipe keeps a copy")
end

place_run = TS.new_run(Random.new(5))
FOUR.each { |s| TS.collect(place_run, s) }
pwall = WS.empty_wall
outcome, = TS.place(pwall, place_run, "kusama", 2, "KUSAMA_DOT", 0, ->(_w) { false })
check(outcome == :save_failed && TS.placeable(place_run).length == 4, "temple place: a failed save keeps the sticker in the hand")
check(pwall == WS.empty_wall, "temple place: a failed save leaves the wall unchanged")
outcome, item = TS.place(pwall, place_run, "kusama", 2, "KUSAMA_DOT", 0, ok_save)
check(outcome == :ok && item["run"] == place_run[:run_id] && TS.placeable(place_run).length == 3, "temple place: ok records the placement")
check(TS.place(pwall, place_run, "kusama", 2, "KUSAMA_DOT", 1, ok_save)[0] == :refused, "temple place: a placement is final")
crash_run = Marshal.load(Marshal.dump(place_run))
crash_run[:placed].clear   # the wall was saved, Game.rxdata was not
outcome, again = TS.place(pwall, crash_run, "kusama", 2, "KUSAMA_DOT", 5, ok_save)
check(outcome == :recovered && again.equal?(item) && TS.placeable(crash_run).length == 3,
      "temple place: a sticker already on the wall is marked placed and keeps its stored item")
check(WS.pages(pwall, "kusama").sum { |p| p["items"].length } == 1, "temple place: recovery adds no second copy")
cross_wall = WS.empty_wall
WS.add_item(cross_wall, "parton", 0, "xr", "KUSAMA_MIRROR", 0)   # an old cross-board item
cross_run = TS.new_run(Random.new(6)).merge(run_id: "xr")
TS.collect(cross_run, "KUSAMA_MIRROR")
outcome, = TS.place(cross_wall, cross_run, "kusama", 0, "KUSAMA_MIRROR", 3, ok_save)
check(outcome == :recovered && cross_run[:placed] == [%w[KUSAMA_MIRROR parton]],
      "temple place: recovery records the board the stored item is on")

ST = TS::Staff
Dir.mktmpdir("temple") do |dir|
  code = Array.new(8) { ("a".."z").to_a.sample }.join
  check(ST.read(dir).nil? && !ST.matches?(code, ST.read(dir)), "temple staff: no cfg means no staff mode")
  File.binwrite(ST.path(dir), "﻿# staff\r\ncode=#{code}\r\n")
  cfg = ST.read(dir)
  check(ST.matches?(code, cfg) && ST.matches?(" #{code} ", cfg), "temple staff: the cfg code matches (BOM, CRLF)")
  check(!ST.matches?(code.upcase, cfg) && !ST.matches?(code[0..-2], cfg), "temple staff: anything else does not")
  check(!ST.matches?("", { "code" => "" }), "temple staff: an empty code never matches")
  check(ST.code_problem(cfg).nil?, "temple staff: a letters-only code is typeable")
  check(ST.reward_on?(cfg) && ST.reward_on?(nil), "temple staff: Ido visit on by default")
  check(ST.write_reward(dir, false) && !ST.reward_on?(ST.read(dir)), "temple staff: reward=off is written")
  check(ST.matches?(code, ST.read(dir)), "temple staff: the code line survives the toggle")
  check(ST.write_reward(dir, true) && ST.reward_on?(ST.read(dir)), "temple staff: and back on")
  check(File.binread(ST.path(dir)).scan("reward=").length == 1, "temple staff: one reward line")
end
bad_code = "zq" + rand(10..99).to_s
logged = []
Object.send(:define_method, :echoln) { |msg| logged << msg }
check(ST.warn_if_untypeable({ "code" => bad_code }) == :untypeable, "temple staff: a code with digits is untypeable")
check(logged.length == 1 && !logged[0].include?(bad_code), "temple staff: the warning never shows the code")
check(ST.code_problem({ "code" => "a" * 13 }) == :too_long && ST.code_problem({}) == :missing, "temple staff: too long / missing")
logged.clear
check(ST.warn_if_untypeable({ "code" => "abc" }).nil? && logged.empty?, "temple staff: a good code logs nothing")
Object.send(:remove_method, :echoln)
ST.activate
TS.start_new_run
check(!ST.active?, "temple staff: a new run ends staff mode")
board_src = File.read(File.join(temple_dir, "008_board_scene.rb"), encoding: "utf-8")
sign_src = board_src.split("def sign(item)", 2)[1].split("\n    end\n", 2)[0]
check(!sign_src.include?("Staff"), "temple staff: the name flow never checks the staff code")
check(board_src.include?("mask: true"), "temple staff: the code keyboard masks what is typed")

KB = TS::Keyboard
all_keys = KB::TABS.flat_map { |t| KB.rows(t).flatten.select { |c| c.is_a?(String) } }
check(all_keys.none? { |c| c.match?(/[0-9@]/) }, "temple keyboard: no digits or @ on any tab")
check(KB::TABS.all? { |t| KB::PUNCT.all? { |c| KB.rows(t).flatten.include?(c) } }, "temple keyboard: every tab has the punctuation and geresh")
check(KB.rows(:he).flatten.count { |c| c.is_a?(String) && c.match?(/[א-ת]/) } == 27, "temple keyboard: 22 letters + 5 finals")
name = TS::TextBuffer.new(TS::NAME_MAX)
check("12@".chars.map { |c| name.type(c) } == [:rejected] * 3 && name.text.empty?, "temple keyboard: digits and @ are rejected")
13.times { name.type("א") }
check(name.text.length == 12, "temple keyboard: name caps at 12")
sentence = TS::TextBuffer.new(TS::SENTENCE_MAX)
45.times { sentence.type("a") }
check(sentence.text.length == 40, "temple keyboard: sentence caps at 40")
check(TS::TextBuffer.new(12, "Ido 2024@").text == "Ido ", "temple keyboard: a prefill drops untypeable chars")
blank = TS::TextBuffer.new(12)
blank.type(" ")
check(!blank.done? && blank.backspace == :deleted && blank.backspace == :cancel, "temple keyboard: spaces are not a name; Blue on empty cancels")
rows = KB.rows(:he)
check(KB.move(rows, 1, 0, :left) == [1, rows[1].length - 1], "temple keyboard: left edge wraps")
check(KB.move(rows, 0, 0, :up)[0] == rows.length - 1, "temple keyboard: up from the tabs wraps to done row")
check(rows[1].last[0] == "א", "temple keyboard: alef is on the right")

# --- temple phase 2: signs, home boards, Ido's visit ---
load File.join(ROOT, "Plugins/DesertCharSelect/000_playable.rb")
sign_run = TS.new_run(Random.new(3))
check(TS::STICKERS.keys.all? { |s| TS.read_sign(sign_run, s) == :sticker } && sign_run[:collected] == TS::STICKERS.keys,
      "temple sign: every sign gives its own sticker the first time")
check(TS::STICKERS.keys.all? { |s| TS.read_sign(sign_run, s) == :fact } && sign_run[:collected].length == 12,
      "temple sign: re-reading gives nothing more")
sign_run = TS.new_run(Random.new(4))
# Minimal display stubs: the got-sticker line shows the sticker art, then disposes it.
$temple_sprites = []
module Graphics
  def self.width = 512
  def self.height = 384
end unless defined?(Graphics)
class Viewport
  attr_accessor :z
  def initialize(*) = (@disposed = false)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end unless defined?(Viewport)
class Sprite
  attr_accessor :bitmap, :x, :y
  def initialize(_vp) = ($temple_sprites << self; @disposed = false)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end unless defined?(Sprite)
TS::Art.define_singleton_method(:bitmap) { |id| "art:#{id}" }
$temple_stickers = sign_run
$messages = []
pbTempleSign(:yonath_bear)
key = TS.sign_key("YONATH_BEAR", 1)
check($messages == [key, key.sub(/_1\z/, "_2"), "TEMPLE_GOT_STICKER"], "temple sign: two boxes, then the got-sticker line")
check($temple_sprites.length == 1 && $temple_sprites[0].bitmap == "art:YONATH_BEAR" && $temple_sprites[0].disposed?,
      "temple sign: the got-sticker line shows the sticker art, then disposes it")
$messages = []
check(pbTempleSign("NOPE") == false && $messages.empty?, "temple sign: an unknown sign id is logged, not raised")
$messages = []
pbTempleSign("YONATH_BEAR")
check($messages.length == 2, "temple sign: second read shows the two boxes only")
check(TS.sign_key("CURRY_TOAST", 2) == "TEMPLE_SIGN_CURRY_HEEL_2", "temple sign: the toast keeps the pedestal's sign copy")
sign_tr = File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8")
sign_keys = TS::STICKERS.keys.flat_map { |s| [TS.sign_key(s, 1), TS.sign_key(s, 2)] }
check(sign_keys.all? { |k| sign_tr.include?("\"#{k}\": {") }, "temple sign: all 24 sign keys are in translations.json")
old_save = TS.normalize_run({ run_id: "old", hand: %w[KUSAMA_DOT YONATH_KEY CURRY_HEEL PARTON_BOOK],
                              collected: %w[CURRY_HEEL YONATH_KEY], placed: [%w[CURRY_HEEL curry]] })
check(old_save[:placed] == [%w[CURRY_TOAST curry]], "temple run: a saved CURRY_HEEL loads as CURRY_TOAST")
check(old_save[:run_id] == "old" && !old_save.key?(:hand) && TS.placeable(old_save) == ["YONATH_KEY"],
      "temple run: an old save with a dealt hand loads and its collected stickers stay usable")
check(TS.collect(old_save, "KUSAMA_MIRROR"), "temple run: an old save can collect stickers outside its old hand")

home = TS.new_run(Random.new(9))
check(TS::HONOREES.all? { |b| TS.placeable_on(home, b).empty? }, "temple home: nothing fits any board before collecting")
FOUR.each { |s| TS.collect(home, s) }
check(TS::HONOREES.all? { |b| TS.placeable_on(home, b) == [FOUR.find { |s| TS.home_board(s) == b }] },
      "temple home: on each board only that honoree's sticker can be picked")
last = FOUR[3]
wrong = TS::HONOREES.find { |h| h != TS.home_board(last) }
check(!TS.record_placement(home, last, wrong) && TS.placeable(home).include?(last),
      "temple home: a sticker cannot be placed on another honoree's board")
hw = WS.empty_wall
check(TS.place(hw, home, wrong, 0, last, 0, ->(_w) { true }) == [:refused, nil] && hw == WS.empty_wall,
      "temple home: place refuses another board and leaves the wall unchanged")
FOUR[0, 3].each { |s| TS.record_placement(home, s, TS.home_board(s)) }
check(!TS.reward_earned?(home) && !TS.reward_due?(home, true), "temple reward: 3 of 4 boards is not enough")
TS.collect(home, "KUSAMA_MIRROR")
TS.record_placement(home, "KUSAMA_MIRROR", "kusama")
check(!TS.reward_earned?(home), "temple reward: a second sticker on the same board does not count twice")
check(TS.placeable_on(home, wrong).empty? && TS.other_homes(home, wrong) == [TS.home_board(last)],
      "temple home: with no fit, the board names where the rest belong")
check(TS.other_homes(home, TS.home_board(last)).empty?, "temple home: no hint on the sticker's own board")
check(!TS.record_placement(home, "KUSAMA_MIRROR", "kusama"), "temple home: the same sticker cannot be placed twice")
TS.record_placement(home, last, TS.home_board(last))
check(TS.reward_earned?(home), "temple reward: one sticker on each of the 4 boards")
check(TS.normalize_run(home.merge(placed: home[:placed] + [["KUSAMA_MIRROR", "yonath"]]))[:placed].length == 5,
      "temple run: a duplicate placement record is dropped on load")
old_cross = TS.normalize_run({ run_id: "x", collected: FOUR, placed: FOUR.zip(%w[yonath curry parton kusama]) })
check(old_cross[:placed].length == 4 && TS.reward_earned?(old_cross),
      "temple reward: an old save with cross-board placements keeps them and they count per board")
check(!TS.reward_due?(home, false), "temple reward: staff switch off means no visit")
check(TS.reward_due?(home, true), "temple reward: due when complete and on")
check(TS.arm_messenger(113, 96, home, true) && TS.take_messenger && !TS.take_messenger, "temple reward: leaving the temple arms one visit")
check(!TS.arm_messenger(93, 96, home, true) && !TS.take_messenger, "temple reward: arriving from elsewhere does not")
TS.mark_reward_shown(home)
check(!TS.reward_due?(home, true) && !TS.arm_messenger(113, 96, home, true), "temple reward: once per run")
check(TS.normalize_run(home)[:reward_shown] == true, "temple reward: shown survives a save")
check(!TS.reward_due?(TS.start_new_run, true), "temple reward: a new run starts without a visit")
roster = DesertCharSelect::PLAYABLE
check(TS.messenger_for("dt_6b53f14c", roster)[:id] == "idi4", "temple reward: the messenger is Ido")
check(TS.messenger_for(nil, roster)[:id] == "idi4", "temple reward: Ido when no character was chosen")
check(TS.messenger_for("idi4", roster) == roster[1], "temple reward: a player who is Ido meets the next roster entry")

check(TS::Art.sheet_rect("KUSAMA_DOT") == [0, 0, 48, 48] && TS::Art.sheet_rect("KUSAMA_PUMPKIN") == [0, 48, 48, 48],
      "temple art: sheet frames are row-major 48 px cells")
check(TS::Art.sheet_rect("CURRY_TOAST") == [0, 0, 48, 48] && TS::Art.sheet_rect("PARTON_NAILS") == [48, 0, 48, 48],
      "temple art: frames follow STICKERS order per honoree")

sw = WS.empty_wall
sitem = WS.add_item(sw, "parton", 0, "r1", "PARTON_BOOK", 2)
check(WS.sign_item(sw, "parton", sitem, "דנה", "a" * 50) && sitem["name"] == "דנה" && sitem["text"].length == 40,
      "temple wall: sign_item stores name and capped sentence")
check(!WS.sign_item(sw, "kusama", sitem, "x", "y") && sitem["name"] == "דנה", "temple wall: sign_item refuses another board")
check(WS.sanitize({ "v" => 4, "boards" => {} }).nil?, "temple wall: a newer wall version is refused")
# Finer placement: spots on a half-cell grid, overlap allowed, newest drawn on top.
check(TS::SPOT_COLS == 13 && TS::SPOT_ROWS == 7, "temple spots: 13 x 7 half-cell positions")
check([0, 6, 7, 27].map { |c| WS.cell_to_spot(c) } == [0, 12, 26, 90], "temple spots: old cells map to their top-left spot")
v2_wall = { "v" => 2, "boards" => { "yonath" => [{ "depth" => 1, "sheet" => 0, "items" => [
  { "s" => "YONATH_KEY", "c" => 8, "run" => "a" }, { "s" => "YONATH_BEAR", "c" => 99, "run" => "b" }] }] } }
v2_items = WS.sanitize(v2_wall)["boards"]["yonath"][0]["items"]
check(v2_items == [{ "s" => "YONATH_KEY", "p" => 28, "run" => "a", "name" => nil, "text" => nil }],
      "temple spots: a v2 item's cell 8 loads at spot 28; a bad cell is dropped")
check(WS.sanitize(WS.sanitize(v2_wall))["boards"] == WS.sanitize(v2_wall)["boards"], "temple spots: a v3 wall round-trips")
check(WS.move_spot(0, :right) == 1 && WS.move_spot(0, :left) == 12 && WS.move_spot(0, :up) == 78 && WS.move_spot(78, :down) == 0,
      "temple spots: the cursor steps half a sticker and wraps")
ov = WS.empty_wall
a1 = WS.add_item(ov, "kusama", 0, "r1", "KUSAMA_DOT", 14)
a2 = WS.add_item(ov, "kusama", 0, "r2", "KUSAMA_DOT", 15)
a3 = WS.add_item(ov, "kusama", 0, "r3", "KUSAMA_MIRROR", 28)
far = WS.add_item(ov, "kusama", 0, "r4", "KUSAMA_PUMPKIN", 17)
opage = WS.pages(ov, "kusama")[0]
check(a1 && a2 && a3 && far && WS.add_item(ov, "kusama", 0, "r5", "KUSAMA_DOT", 15).nil?,
      "temple spots: overlapping spots are allowed, the exact same spot is not")
check(opage["items"].last.equal?(far), "temple spots: items are stored oldest first, so the newest is drawn last (on top)")
check(WS.stack_at(opage, 14).map { |it| it["run"] } == %w[r3 r2 r1], "temple spots: the stack under a spot lists every overlap, newest first")
check(WS.stack_at(opage, 17).map { |it| it["run"] } == %w[r4], "temple spots: a lone sticker has a stack of one")
check(WS.stack_at(opage, 15).map { |it| it["run"] } == %w[r3 r2 r1] && !WS.overlap?(15, 17),
      "temple spots: two half-steps apart do not overlap")
check(WS.free_spot(opage) == 6 && WS.free_spot({ "items" => [{ "p" => 0 }] }) == 2, "temple spots: placing starts on an untouched spot")
v1_empty = { "v" => 1, "boards" => { "yonath" => [{ "run" => "r", "items" => [{ "s" => "RICE", "c" => 0 }] },
                                                 { "run" => "s", "items" => [{ "s" => "YONATH_KEY", "c" => 1 }] }] } }
check(WS.sanitize(v1_empty)["boards"]["yonath"].map { |p| p["sheet"] } == [1], "temple wall: a migrated sheet with no items is dropped")
old_wall = { "v" => 2, "boards" => { "kusama" => [{ "depth" => 0, "sheet" => 0, "items" => [{ "s" => "PARTON_BOOK", "c" => 1, "run" => "r" }] }] } }
check(WS.sanitize(old_wall)["boards"]["kusama"][0]["items"][0]["s"] == "PARTON_BOOK",
      "temple wall: an old item on another honoree's board still loads")
heel_wall = { "v" => 2, "boards" => { "curry" => [{ "depth" => 0, "sheet" => 0, "items" => [{ "s" => "CURRY_HEEL", "c" => 0 }] }] } }
check(WS.sanitize(heel_wall)["boards"]["curry"][0]["items"][0]["s"] == "CURRY_TOAST", "temple wall: a stored heel becomes the toast")

# Temple music: Time-Warp carries from 113 onto 96 only. Engine stubs first.
class PokemonGlobalMetadata; end
class Game_Map
  attr_reader :map_id
  def initialize(id) = (@map_id = id; @map = Struct.new(:autoplay_bgs, :bgs).new(false, nil))
  def autoplay = ($bgm_calls << [:own, @map_id])
  def autoplayAsCue = ($bgm_calls << [:own_cue, @map_id])
end
class Scene_Map
  def autofade(mapid) = ($bgm_calls << [:fade, mapid])
end
module Graphics
  def self.frame_reset; end
end
$bgm_calls = []
$bgm_now = nil
def pbBGMPlay(name) = ($bgm_calls << [:play, name]; $bgm_now = name)
def pbAutoplayOnSave = $game_map.autoplay
$game_system = Object.new
def $game_system.playing_bgm = ($bgm_now ? Struct.new(:name).new($bgm_now) : nil)
load File.join(temple_dir, "012_temple_music.rb")
MU = TS::Music
check(MU.carry_after(false, 113, 96), "temple music: leaving the temple onto 96 carries Time-Warp")
check(MU.carry_after(true, 96, 96) && !MU.carry_after(false, 96, 96), "temple music: a transfer inside 96 keeps the carry as it was")
check(!MU.carry_after(true, 96, 93) && !MU.carry_after(true, 96, 113), "temple music: leaving 96 ends the carry")
check(!MU.carry_after(false, 93, 96) && !MU.carry_after(true, 93, 96), "temple music: 96 from elsewhere plays its own music")
check(MU.owns?(true, 96) && !MU.owns?(true, 113) && !MU.owns?(false, 96), "temple music: only a carried 96 skips its own BGM")
pg = PokemonGlobalMetadata.new
$PokemonGlobal = pg
leave = $event_handlers[:temple_music]
scene = Scene_Map.new
walk = lambda do |from, to|
  $game_map = Game_Map.new(from)
  scene.autofade(to)
  leave.call(to, nil)
  $game_map = Game_Map.new(to)
  $game_map.autoplay
end
$bgm_now = "Time-Warp"
$bgm_calls = []
walk.call(113, 96)
check($bgm_calls.empty? && $bgm_now == "Time-Warp" && pg.temple_music_carry == true,
      "temple music: 113 -> 96 neither fades nor replaces Time-Warp")
$bgm_calls = []
walk.call(96, 96)
check($bgm_calls.empty?, "temple music: a door inside 96 keeps Time-Warp")
$bgm_calls = []
walk.call(96, 93)
check($bgm_calls == [[:fade, 93], [:own, 93]] && pg.temple_music_carry == false, "temple music: 96 -> 93 fades to the normal track")
$bgm_calls = []
walk.call(93, 96)
check($bgm_calls == [[:fade, 96], [:own, 96]], "temple music: 93 -> 96 plays 96's own track")
# A real load restores playing_bgm = Time-Warp while the title music sounds.
pg.temple_music_carry = true
$bgm_now = "Time-Warp"
$bgm_calls = []
$game_map = Game_Map.new(96)
pbAutoplayOnSave
check($bgm_calls == [[:play, "Time-Warp"]], "temple music: a load on a carried 96 replays Time-Warp")
$bgm_calls = []
$game_map.autoplayAsCue
check($bgm_calls.empty?, "temple music: after the load, a cue keeps the running track")
pg.temple_music_carry = false
pbAutoplayOnSave
check($bgm_calls == [[:own, 96]], "temple music: a load on an uncarried 96 plays its own track")
$PokemonGlobal = nil

tr_text = File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8")
temple_keys = Dir.glob(File.join(temple_dir, "*.rb")).flat_map { |f| File.read(f, encoding: "utf-8").scan(/"(TEMPLE_[A-Z0-9_]+)"/).flatten }
temple_keys += TS::BOARDS.values.map { |b| b[:prompt_key] }
missing = temple_keys.uniq.reject { |k| tr_text.include?("\"#{k}\": {") }
check(missing.empty?, "temple: every TEMPLE_ key is in translations.json (missing #{missing.inspect})")

# TG7 bags rules and hooks live in their own file (same check/$failures).
load File.join(__dir__, "bags_rules_test.rb")
# TG11 temple hoop rules and event flow, same pattern.
load File.join(__dir__, "hoop_rules_test.rb")
# TG10 planetarium rules, talk hooks and the show smoke run, same pattern.
load File.join(__dir__, "planet_rules_test.rb")
# TG9 toaster rules, hooks (with the bags/planet aliases loaded), altar and finale, same pattern.
load File.join(__dir__, "toaster_rules_test.rb")
# TG14 arm wrestling rules, bots, the cowboy flow and the scene smoke run, same pattern.
load File.join(__dir__, "arm_rules_test.rb")
# TG23 Alla's stand rules, talk flow and the rush scene smoke run, same pattern.
load File.join(__dir__, "alla_rules_test.rb")
# TG31 Tuta maze rules, fairness and AI cases, and the scene smoke run, same pattern.
load File.join(__dir__, "tuta_rules_test.rb")
# TG40 DJ Rush Hour rules, solver, quest, Johnny/Inbar flow and the scene smoke run, same pattern.
load File.join(__dir__, "djrush_rules_test.rb")
check(MomDadBattleRules::MAP_ID == 89, "battle: loss returns to mom-dad-in")
check([MomDadBattleRules::LOSE_X, MomDadBattleRules::LOSE_Y, MomDadBattleRules::LOSE_DIR] == [25, 3, 2],
      "battle: loss tile is (25, 3) facing down")
check(MomDadBattleRules::MONEY == 0, "battle: money is zero")
check(MomDadBattleRules::BATTLE_RULES == ["noMoney", "canLose", "canRun"],
      "battle: no prize, no loss money, can lose, can run")
check(MomDadBattleRules::INTRO == [:music, :pan, :effect, :fight],
      "battle: music, then the camera, then the effect, then the fight")
check(MomDadBattleRules.pan_returns_home?, "battle: the camera pan ends where it started")
check(MomDadBattleRules::CHILDREN.length == 4, "battle: four children")
check(MomDadBattleRules.child(0)[:id] == "4c6540a3", "battle: first child")
check(MomDadBattleRules.child(0)[:event_id] == 8, "battle: first child event")
check(MomDadBattleRules.child(3)[:event_id] == 20, "battle: last child event")
check(MomDadBattleRules.child(4)[:id] == MomDadBattleRules.child(0)[:id], "battle: child index wraps")
check(MomDadBattleRules.outcome(1) == :win, "battle: outcome 1 is a win")
check(MomDadBattleRules.outcome(2) == :lose, "battle: a loss is a loss")
check(MomDadBattleRules.outcome(3) == :lose, "battle: running is a loss")
check(MomDadBattleRules.follower_name("b25567c8") == "momdad_child_b25567c8", "battle: follower name")

# --- Hebrew RTL parentheses (bag item names) ---
bottle = "בקבוק מים (לבן)"
reversed_bottle = HebrewText.visual_reverse(bottle)
check(reversed_bottle.include?("(ןבל)"),
      "bag Hebrew name keeps opening '(' on the visual left of the word")
check(reversed_bottle.include?(")"),
      "bag Hebrew name keeps closing ')' on the visual right of the word")
check(!reversed_bottle.include?(")ןבל("),
      "bag Hebrew name does not show reversed parentheses glyphs")
check(HebrewText.visual_reverse("שלום") == "םולש", "plain Hebrew still reverses")
check(HebrewText.visual_reverse("20 Shekel") == "20 Shekel",
      "English without Hebrew is left alone")
check(HebrewText.mirror_bidi_char("(") == ")", "mirror open paren")
check(HebrewText.mirror_bidi_char(")") == "(", "mirror close paren")
check(HebrewText.visual_reverse("בדיקה (OK)") == "(OK) הקידב",
      "English parenthetical stays intact inside Hebrew")

if $failures.empty?
  puts "Plugin rule tests passed."
  exit 0
end

warn "#{$failures.size} plugin rule test(s) failed."
exit 1
