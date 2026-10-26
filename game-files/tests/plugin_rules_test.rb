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
load File.join(ROOT, "Plugins/HebrewSupport/hebrew_support.rb")
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
check(DesertTownControls.color_keys == [:H, :J, :K, :F, :G], "color keys are H J K F G")
taken = DesertTownControls::TAKEN_KEYS.keys
DesertTownControls.color_keys.each do |key|
  check(!taken.include?(key), "color key #{key} is free")
end
check(DesertTownControls::MIRROR_INPUT[:red] == :USE, "red mirrors Use, the C input")
check(DesertTownControls::MIRROR_INPUT[:blue] == :BACK, "blue mirrors Back, the X input")
check(!DesertTownControls::MIRROR_INPUT.value?(:ACTION), "no color key mirrors the Z menu")
check(DesertTownArcade::BAG_KEY == :B, "B is still the existing bag key")

check(DesertTownControls.bag_toggle(false, false) == :none, "no orange press leaves the bag alone")
check(DesertTownControls.bag_toggle(false, true) == :open, "orange on the map opens the bag")
check(DesertTownControls.bag_toggle(true, true) == :close, "orange in the bag closes it")
check(DesertTownControls.bag_toggle(true, false) == :none, "an open bag stays open without a new press")

%i[USE BACK ACTION UP DOWN LEFT RIGHT JUMPUP JUMPDOWN SPECIAL AUX1 AUX2].each do |input|
  check(DesertTownControls.slide_should_close?([input], []), "#{input} closes a slide")
end
%i[A S D C X Z F G H J K SPACE RETURN ESCAPE].each do |key|
  check(DesertTownControls.slide_should_close?([], [key]), "#{key} closes a slide")
end
check(!DesertTownControls.slide_should_close?([], []), "a slide stays up until a button")

$dt_trigger = Input::USE
$dt_raw_trigger = nil
check(Input.trigger?(Input::USE), "C still confirms")
check(!Input.trigger?(Input::ACTION), "C does not open the menu")

$dt_trigger = nil
$dt_raw_trigger = :H
check(Input.trigger?(Input::USE), "red confirms like C")
check(!Input.trigger?(Input::BACK), "red does not cancel")
check(!Input.trigger?(Input::ACTION), "red does not open the menu")

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

$dt_trigger = nil
$dt_press = nil
$dt_raw_trigger = nil
$dt_raw_press = nil
$dt_raw_trigger = :B
check(DesertTownArcade.bag_key_pressed?, "B still requests the bag")
$dt_raw_trigger = :K
check(DesertTownArcade.bag_key_pressed?, "orange requests the bag")
$dt_raw_trigger = :H
check(!DesertTownArcade.bag_key_pressed?, "red does not request the bag")

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
check(HebrewText.ltr_token?("(OK)"), "English in parentheses stays LTR")
check(HebrewText.visual_reverse("בדיקה (OK)") == "(OK) הקידב",
      "English parenthetical stays intact inside Hebrew")

if $failures.empty?
  puts "Plugin rule tests passed."
  exit 0
end

warn "#{$failures.size} plugin rule test(s) failed."
exit 1
