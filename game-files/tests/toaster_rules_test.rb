# TG9 toaster quest: loaded from plugin_rules_test.rb (shares check/$failures).
# ToasterRules is pure; the hooks, duels, altar and finale run against stubs.
require "json"
toast_dir = File.join(ROOT, "Plugins/zToaster")
load File.join(toast_dir, "000_rules.rb")
TR = ToasterRules

class ToastTestBag
  attr_reader :items
  def initialize(items = {}) = (@items = Hash.new(0).merge(items))
  def quantity(i) = @items[i]
  def add(i, n = 1) = (@items[i] += n; true)
  def remove(i, n = 1)
    return false if @items[i] < n
    @items[i] -= n
    true
  end
end
toast_st = ->(stage, extra = {}) { TR.normalize({ stage: stage }.merge(extra)) }
held = ->(items) { ToastTestBag.new(items) }

#-------------------------------------------------------------------------------
# 1: every decision, every stage, with and without the item
#-------------------------------------------------------------------------------
want = {
  none:    [:intro, :intro, :plain, :plain, :plain, :sealed, :sealed],
  asked:   [:remind_noodles, :remind_noodles, :duel, :plain, :plain, :sealed, :sealed],
  lead:    [:remind_clerk, :remind_clerk, :remind, :hearing, :hearing, :sealed, :sealed],
  permit:  [:remind_vault, :remind_vault, :remind, :reissue, :remind, :fight, :fight],
  toaster: [:remind_altar, :finale, :remind, :closed, :closed, :regive, :empty],
  done:    [:crumb_recover, :crumb_recover, :after, :closed, :closed, :empty, :empty]
}
item_for = { permit: :TOASTPERMIT }
wrong = []
want.each do |stage, (e0, e1, nd, c0, c1, a0, a1)|
  st = toast_st.call(stage)
  wrong << [:eyal, stage] unless TR.eyal_decide(st, held.call({})) == e0 && TR.eyal_decide(st, held.call(TOASTER: 1)) == e1
  wrong << [:noodles, stage] unless TR.noodles_decide(st) == nd
  form = held.call(item_for.fetch(stage, :TOASTPERMIT) => 1)
  wrong << [:clerk, stage] unless TR.clerk_decide(st, held.call({})) == c0 && TR.clerk_decide(st, form) == c1
  wrong << [:altar, stage] unless TR.altar_decide(st, held.call({})) == a0 && TR.altar_decide(st, held.call(TOASTER: 1)) == a1
end
check(wrong.empty?, "toast 1: every decide x stage x item matches the spec table (wrong: #{wrong.inspect})")
check(TR.eyal_decide(toast_st.call(:done, crumb_given: true), held.call({})) == :after, "toast 1: done + crumb given -> after")
check(TR.altar_graphic(:empty, true) == "" && TR.altar_graphic(:sealed, true) == "toaster_altar" &&
      TR.altar_graphic(:fight, false) == "Object ball" && TR.altar_graphic(:regive, true) == "toaster_altar",
      "toast 1: the altar is empty exactly on :empty, the fallback graphic without the art")

#-------------------------------------------------------------------------------
# 2 + 6: mutators move only from their guard stage; a repeat is a no-op
#-------------------------------------------------------------------------------
movers = {
  ask!:     ->(s, _b) { TR.ask!(s) },
  lead!:    ->(s, _b) { TR.lead!(s) },
  permit!:  ->(s, b) { TR.permit!(s, b) },
  claim!:   ->(s, b) { TR.claim!(s, b) },
  deliver!: ->(s, b) { TR.deliver!(s, b, :jar) },
  crumb!:   ->(s, b) { TR.crumb!(s, b) }
}
guard = { ask!: :none, lead!: :asked, permit!: :lead, claim!: :permit, deliver!: :toaster, crumb!: :done }
off = []
movers.each do |name, fn|
  TR::STAGES.each do |stage|
    next if stage == guard[name]
    s = toast_st.call(stage)
    b = held.call(TOASTPERMIT: 1, TOASTER: 1)
    before = [s.dup, b.items.dup]
    off << [name, stage] if fn.call(s, b) || [s, b.items] != before
  end
end
check(off.empty?, "toast 2: no mutator moves from a stage other than its guard (#{off.inspect})")
s = toast_st.call(:none)
check(TR.ask!(s) && s[:stage] == :asked && !TR.ask!(s), "toast 2: ask! once")
check(TR.lead!(s) && s[:stage] == :lead && !TR.lead!(s), "toast 2: lead! once")
b = held.call({})
check(TR.permit!(s, b) && b.quantity(:TOASTPERMIT) == 1 && s[:stage] == :permit && !TR.permit!(s, b) && b.quantity(:TOASTPERMIT) == 1,
      "toast 2: permit! adds one form and moves to :permit, once")
check(!TR.reissue!(s, b) && b.quantity(:TOASTPERMIT) == 1, "toast 6: reissue! never gives a second held form")
b.remove(:TOASTPERMIT)
check(TR.reissue!(s, b) && !TR.reissue!(s, b) && b.quantity(:TOASTPERMIT) == 1, "toast 6: a lost form is reissued exactly once")
check(TR.claim!(s, b) && b.quantity(:TOASTPERMIT) == 0 && b.quantity(:TOASTER) == 1 && s[:stage] == :toaster && !TR.claim!(s, b),
      "toast 2: claim! swaps the form for the toaster, once")
check(!TR.regive!(s, b) && b.quantity(:TOASTER) == 1, "toast 6: regive! never gives a second held toaster")
b.remove(:TOASTER)
check(TR.regive!(s, b) && !TR.regive!(s, b) && b.quantity(:TOASTER) == 1, "toast 6: a lost toaster comes back exactly once")
s2 = toast_st.call(:permit)
b2 = held.call({})
check(TR.claim!(s2, b2) && b2.quantity(:TOASTER) == 1, "toast 2: claim! without the form (lost) still gives the toaster")

#-------------------------------------------------------------------------------
# 3-5: happy path, plug guards, crumb once, crash recovery
#-------------------------------------------------------------------------------
s = TR.new_state
b = held.call({})
path = TR.ask!(s) && TR.lead!(s) && TR.permit!(s, b) && TR.claim!(s, b)
[nil, :notyet, :oven, "ac"].each { |p| path &&= !TR.deliver!(s, b, p) && s[:stage] == :toaster && b.quantity(:TOASTER) == 1 }
check(path, "toast 4: deliver! with not-yet or a bad plug changes nothing")
path = TR.deliver!(s, b, :ac) && s[:plug] == :ac && s[:stage] == :done && b.quantity(:TOASTER) == 0
check(path && TR.eyal_decide(s, b) == :crumb_recover, "toast 5: after deliver! and before crumb! Eyal recovers the crumb")
check(TR.crumb!(s, b) && !TR.crumb!(s, b) && b.quantity(:TOASTCRUMB) == 1 && s[:crumb_given],
      "toast 4: two crumb! calls give one crumb")
check(b.items.select { |_, v| v > 0 } == { TOASTCRUMB: 1 } && s == { stage: :done, crumb_given: true, plug: :ac },
      "toast 3: happy path ends with the crumb only, crumb_given and the plug")
check(TR.oren_after?(s) && !TR.oren_after?(toast_st.call(:done, plug: :jar)) && !TR.oren_after?(toast_st.call(:toaster, plug: :ac)),
      "toast: Oren's after-line only after the AC was unplugged")
check(!TR.deliver!(toast_st.call(:toaster), held.call({}), :ac), "toast 4: deliver! needs the toaster held")

#-------------------------------------------------------------------------------
# 7, 8: battle outcome, normalize
#-------------------------------------------------------------------------------
check(TR.battle_won?(1) && [0, 2, 3, 4, 5, nil].none? { |o| TR.battle_won?(o) }, "toast 7: only outcome 1 is a win")
check([nil, "x", [1], 3].all? { |g| TR.normalize(g) == TR.new_state }, "toast 8: nil or garbage loads as a fresh state")
check(TR.normalize({ stage: :party, crumb_given: "yes", plug: :fridge, junk: 1 }) == TR.new_state,
      "toast 8: unknown stage, bad crumb flag, bad plug and extra keys are repaired")
kept = { stage: :done, crumb_given: true, plug: :jar }
check(TR.normalize(kept).equal?(kept) && kept == { stage: :done, crumb_given: true, plug: :jar }, "toast 8: a valid state is kept")
check(TR.plug_for(0) == :ac && TR.plug_for(1) == :jar && TR.plug_for(2).nil? && TR.plug_for(nil).nil?, "toast: plug menu mapping")
check(TR.inject_index([355, 101, 0]) == 2 && TR.inject_index([355]) == 1 && TR.inject_index([]).nil?, "toast: inject before the end command")
s = toast_st.call(:done, crumb_given: true, plug: :ac)
b = held.call(TOASTCRUMB: 1)
check(TR.debug_jump!(s, b, :toaster) && s == { stage: :toaster, crumb_given: false, plug: nil } &&
      b.items.select { |_, v| v > 0 } == { TOASTER: 1 }, "toast debug: jump to toaster holds exactly the toaster")
check(TR.debug_jump!(s, b, :permit) && b.items.select { |_, v| v > 0 } == { TOASTPERMIT: 1 } && !TR.debug_jump!(s, b, :done),
      "toast debug: jump to permit holds the form; never to done")

#-------------------------------------------------------------------------------
# Engine stubs for the plugin files
#-------------------------------------------------------------------------------
$toast_log = []
$toast_picks = []
$toast_duels = []
$toast_outcomes = []
$toast_frames = 0
def pbMessage(msg, commands = nil, _cancel = 0)
  $toast_log << [msg, DesertTalk.name_key]
  return nil unless commands
  raise "toast test: no scripted choice for #{msg}" if $toast_picks.empty?
  $toast_picks.shift
end
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
def pbReceiveItem(i, n = 1) = ($toast_log << [:received, i]; $bag.add(i, n))
# Like the engine: a wait runs map frames, and each frame runs the speaker clear.
def pbUpdateSceneMap = ($toast_frames += 1; $event_handlers[:desert_talk_clear_speaker]&.call)
def pbWait(_s) = 3.times { pbUpdateSceneMap }
def pbSEPlay(name, *) = ($toast_log << [:se, name])
def pbMEPlay(name, *) = ($toast_log << [:me, name])
def pbFadeOutIn = ($toast_log << :fade; yield)
def pbResolveBitmap(_path) = $toast_art
def setBattleRule(rule) = ($toast_rules << rule)
def pbShadowBasicParty = %i[lent_pikachu lent_charizard lent_snorlax]
def pbTransferPlayer(map_id, x, y, direction = 2) = ($toast_log << [:transfer, map_id, x, y, direction])
ToastInterp = Struct.new(:self_event) { def get_self = self_event }
def pbMapInterpreter = ($toast_interp ||= ToastInterp.new(nil))
module WildBattle
  def self.start_core(pkmn)
    $toast_log << [:battle, pkmn.species, pkmn.form, pkmn.name, pkmn.moves, $player.party.dup, $toast_rules.dup]
    out = $toast_outcomes.shift
    raise "toast test: battle crashed" if out == :raise
    out
  end
end
class Pokemon
  attr_reader :species, :level, :form, :moves, :iv
  attr_accessor :name
  def initialize(species, level) = (@species, @level, @form, @moves, @iv = species, level, 0, [:THUNDERSHOCK], {})
  def form_simple=(f)
    @form = f
  end
  def forget_all_moves = (@moves = [])
  def learn_move(m) = (@moves << m)
  def calc_stats; end
  def heal; end
  def play_cry = ($toast_log << [:cry, @species])
end unless defined?(Pokemon)
module GameData
  module Stat
    def self.each_main = %i[HP ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED].each { |s| yield Struct.new(:id).new(s) }
  end unless const_defined?(:Stat, false)
  module Item
    def self.get(id) = Struct.new(:portion_name, :pocket).new(id.to_s, 8)
  end
end
class PokemonBag
  def self.pocket_names = Array.new(8) { |i| "P#{i + 1}" }
end unless PokemonBag.respond_to?(:pocket_names)
class ToastScreen
  def start_shake(*a) = ($toast_log << [:shake, *a])
  def start_flash(_c, d) = ($toast_log << [:flash, d])
end
class Color
  def initialize(*); end
end unless defined?(Color)
ToastPlayer = Struct.new(:party)
ToastMap = Struct.new(:map_id, :events)
ToastEv = Struct.new(:name, :character_name)
ToastPage = Struct.new(:graphic, :list, :trigger)
ToastGraphic = Struct.new(:character_name)
ToastRpgEvent = Struct.new(:name, :pages)
ToastRpgMap = Struct.new(:events)
module MenuHandlers
  def self.add(_menu, id, _h) = (($toast_menu ||= []) << id)
end unless defined?(MenuHandlers)

# The real duel wrapper: a stub engine pbDuel, then duel_moves.rb wraps it.
def pbDuel(trainer_id, trainer_name, event, speeches)
  $toast_log << [:duel, trainer_id, trainer_name, event&.name, speeches, $desert_duel_moves.dup]
  $toast_duels.shift
end
class IconSprite
  def setBitmap(_file = nil, _hue = 0); end
end unless defined?(IconSprite)
class PokemonDuel
  def pbStartDuel(_o, _e); end
end unless defined?(PokemonDuel)
load File.join(ROOT, "Plugins/DesertTalk/duel_moves.rb") unless defined?(DESERT_DUEL_PROFILES)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
kobel = DESERT_DUEL_PROFILES.keys.dup

%w[001_state 002_duels 003_talk_hooks 004_altar 005_finale 007_debug].each { |f| load File.join(toast_dir, "#{f}.rb") }
saved = [$game_map, $bag, $PokemonGlobal, $player, $game_screen, $game_switches]
$PokemonGlobal = PokemonGlobalMetadata.new
$bag = ToastTestBag.new
$player = ToastPlayer.new([:own_mon])
$game_screen = ToastScreen.new
$game_switches = {}
$map_interpreter_running = true
events = {
  3 => ToastEv.new("dt_0f0fdcf5"), 5 => ToastEv.new("dt_c081cd67"), 10 => ToastEv.new("dt_266d65c6"),
  9 => ToastEv.new("toaster_altar", "toaster_altar"), 33 => ToastEv.new("dt_326f5ab5")
}
talk = lambda do |id, map_id = 95, picks: [], duels: []|
  $toast_log.clear
  $toast_picks = picks
  $toast_duels = duels
  $game_map = ToastMap.new(map_id, events)
  $toast_interp = ToastInterp.new(events.values.find { |e| e.name == "dt_#{id}" })
  pbDesertTalk(id)
  $toast_log.dup
end
script = lambda do |name, map_id, picks: [], duels: [], outcomes: []|
  $toast_log.clear
  $toast_picks, $toast_duels, $toast_outcomes, $toast_rules = picks, duels, outcomes, []
  $game_map = ToastMap.new(map_id, events)
  $toast_interp = ToastInterp.new(name == :clerk ? events[33] : events[9])
  name == :clerk ? pbToasterClerk : pbToasterAltar
  $toast_log.dup
end
msgs = ->(log) { log.select { |e| e.is_a?(Array) && e[0].is_a?(String) }.map { |e| e[0].split("|")[0] } }
gots = ->(log) { log.select { |e| e.is_a?(Array) && e[0].is_a?(String) && e[0].start_with?("\\me[Key item get]") }.map { |e| e[0].split("|")[1].to_s.sub("\\wtnp[40]", "") } }
st = -> { $PokemonGlobal.toaster_quest }

#-------------------------------------------------------------------------------
# 11: duel profiles
#-------------------------------------------------------------------------------
prof = DESERT_DUEL_PROFILES
check(kobel.all? { |k| prof.key?(k) } && prof[[95, "dt_c081cd67"]] && prof[[80, "dt_326f5ab5"]] &&
      [[95, "dt_c081cd67"], [80, "dt_326f5ab5"]].all? { |k| prof[k][:moves].length == 4 && prof[k][:name].start_with?("NAME_") },
      "toast 11: both duel profiles are added (4 moves, a NAME_ key) and Kobel/Dan stay")
check(Toaster::DUELS.values.all? { |d| d[:speeches].length == 12 && d[:speeches].uniq.length == 12 } &&
      Toaster::DUELS.values.all? { |d| d[:speeches].each_slice(3).map { |t| t.map { |k| k[/_(BLK|PRC|FRC|SPC)\d\z/, 1] }.uniq } == [["BLK"], ["PRC"], ["FRC"], ["SPC"]] },
      "toast 11: 12 speeches each, in pbDuel order defend/precise/fierce/special")

#-------------------------------------------------------------------------------
# Hooks: Eyal, HaNoodles, Yunik, Oren
#-------------------------------------------------------------------------------
log = talk.call("c081cd67")
check(msgs.call(log) == ["MSG_C081CD67_LINE"] && st.call[:stage] == :none, "toast hook: HaNoodles before the ask says only his line")
log = talk.call("0f0fdcf5", 93)
check(msgs.call(log) == ["MSG_0F0FDCF5_LINE"] && st.call[:stage] == :none, "toast hook: Eyal on Map093 says only his own line")
log = talk.call("0f0fdcf5")
check(msgs.call(log) == %w[MSG_0F0FDCF5_LINE TOAST_EYAL_ASK_1 TOAST_EYAL_ASK_2 TOAST_EYAL_ASK_3 TOAST_EYAL_ASK_4] &&
      log[1..].all? { |_, n| n == "NAME_0F0FDCF5" } && st.call[:stage] == :asked,
      "toast flow 1: Eyal's own line, then ASK_1..4 with his plate; stage asked")
check(msgs.call(talk.call("0f0fdcf5"))[1..] == ["TOAST_EYAL_REMIND_NOODLES"], "toast flow 1: back early, Eyal names HaNoodles")
check(msgs.call(script.call(:clerk, 80)).empty? && st.call[:stage] == :asked, "toast hook: Yunik before the lead adds nothing")

log = talk.call("c081cd67", duels: [false])
duel = log.find { |e| e[0] == :duel }
check(msgs.call(log) == %w[MSG_C081CD67_LINE TOAST_NOODLE_PRE_1 TOAST_NOODLE_PRE_2 TOAST_NOODLE_PRE_3 TOAST_NOODLE_LOSE] &&
      duel && duel[1] == :BLACKBELT && duel[2] == "NAME_C081CD67" && duel[3] == "dt_c081cd67" &&
      duel[4] == Toaster::DUELS[:noodles][:speeches] && duel[5] == Toaster::DUELS[:noodles][:moves] && st.call[:stage] == :asked,
      "toast duel 1: PRE, a pbDuel with his profile's moves and name, a loss changes nothing")
log = talk.call("c081cd67", duels: [true])
check(msgs.call(log) == %w[MSG_C081CD67_LINE TOAST_NOODLE_PRE_3 TOAST_NOODLE_WIN_1 TOAST_NOODLE_WIN_2] && st.call[:stage] == :lead,
      "toast duel 1: a retry repeats only PRE_3; a win reveals the Committee (lead)")
check($desert_duel_moves.nil?, "toast duel: the move labels are cleared after the duel")
check(msgs.call(talk.call("c081cd67"))[1..] == ["TOAST_NOODLE_REMIND"], "toast: HaNoodles reminds after the lead")
check(msgs.call(talk.call("0f0fdcf5"))[1..] == ["TOAST_EYAL_REMIND_CLERK"], "toast flow 1: Eyal names the clerk")

log = script.call(:clerk, 80, duels: [false])
check(msgs.call(log) == %w[TOAST_CLERK_PRE_1 TOAST_CLERK_PRE_2 TOAST_CLERK_PRE_3 TOAST_CLERK_LOSE] && st.call[:stage] == :lead &&
      $bag.quantity(:TOASTPERMIT) == 0 && log.find { |e| e[0] == :duel }[3] == "dt_326f5ab5",
      "toast duel 2: the hearing is a duel on Yunik's event; a loss is 'appeal denied', nothing changes")
log = script.call(:clerk, 80, duels: [true])
check(msgs.call(log) == ["TOAST_CLERK_PRE_3", "TOAST_CLERK_WIN_1", "\\me[Key item get]You obtained \\c[1]{1}\\c[0]!",
                         "You put the {1} in\\nyour Bag's <icon=bagPocket{2}>\\c[1]{3}\\c[0] pocket.",
                         "TOAST_CLERK_WIN_2", "TOAST_CLERK_WIN_3", "TOAST_CLERK_WIN_4"] &&
      gots.call(log) == ["TOASTPERMIT"] && $bag.quantity(:TOASTPERMIT) == 1 && st.call[:stage] == :permit,
      "toast duel 2: a win issues one form (fanfare, no second add), then team, vault and mummy lines")
check(msgs.call(script.call(:clerk, 80)) == ["TOAST_CLERK_REMIND"] && $bag.quantity(:TOASTPERMIT) == 1, "toast: Yunik reminds while the form is held")
$bag.remove(:TOASTPERMIT)
log = script.call(:clerk, 80)
check(msgs.call(log).values_at(0, -1) == %w[TOAST_CLERK_REISSUE TOAST_CLERK_REMIND] && $bag.quantity(:TOASTPERMIT) == 1,
      "toast 6: a lost form is reissued once, then the reminder")
check(msgs.call(script.call(:clerk, 95)).empty?, "toast: pbToasterClerk off Map080 does nothing")
check(msgs.call(talk.call("0f0fdcf5"))[1..] == ["TOAST_EYAL_REMIND_VAULT"], "toast flow 1: Eyal sends the player to the vault")

#-------------------------------------------------------------------------------
# Altar: sealed, losses, win, regive, empty; the party always comes back
#-------------------------------------------------------------------------------
$PokemonGlobal.toaster_quest = { stage: :asked, crumb_given: false, plug: nil }
check(msgs.call(script.call(:altar, 94)) == ["TOAST_ALTAR_SEALED"], "toast altar: sealed without the form")
$PokemonGlobal.toaster_quest = { stage: :permit, crumb_given: false, plug: nil }
[2, 3, 5].each do |outcome|
  log = script.call(:altar, 94, outcomes: [outcome])
  bt = log.find { |e| e[0] == :battle }
  check(msgs.call(log) == %w[TOAST_ALTAR_POSSESSED_1 TOAST_ALTAR_POSSESSED_2 TOAST_ALTAR_LOSE] &&
        log.last == [:transfer, 80, 8, 15, 2] && log.include?(:fade) && st.call[:stage] == :permit &&
        $bag.quantity(:TOASTPERMIT) == 1 && $player.party == [:own_mon],
        "toast altar: outcome #{outcome} zaps the player to Old City (8,15) with the form kept and the party back")
  check(bt && bt[1] == :ROTOM && bt[2] == 1 && bt[3] == "TOAST_ROTOM_NAME" && bt[4] == %i[OVERHEAT THUNDERBOLT WILLOWISP CONFUSERAY] &&
        bt[5] == pbShadowBasicParty && bt[6] == %w[canLose disablePokeBalls noExp], "toast altar: Heat Rotom 'the toaster' vs the lent party, canLose") if outcome == 2
end
log = script.call(:altar, 94, outcomes: [:raise]) rescue nil
check($player.party == [:own_mon] && st.call[:stage] == :permit, "toast altar: a crashed battle still restores the player's party")
first = [$toast_log.index { |e| e[0] == :se }, $toast_log.index { |e| e[0] == :shake }, $toast_log.index { |e| e[0] == :cry }]
check(first.all? && first.max < $toast_log.index { |e| e[0] == "TOAST_ALTAR_POSSESSED_1" }, "toast altar: sparks, shake and the cry come before the lines")
events[9].character_name = "toaster_altar"
log = script.call(:altar, 94, outcomes: [1])
check(msgs.call(log).values_at(2, 3, -1) == %w[TOAST_ALTAR_WIN_1 TOAST_ALTAR_WIN_2 TOAST_GOT_TOASTER] && gots.call(log) == ["TOASTER"] &&
      log.last == [:transfer, 80, 8, 15, 2] && st.call[:stage] == :toaster && $bag.quantity(:TOASTER) == 1 &&
      $bag.quantity(:TOASTPERMIT) == 0 && events[9].character_name == "" && log.include?([:se, "Slots coin"]),
      "toast altar: a win claims the toaster (form gone), empties the live altar, escorts out")
check(msgs.call(script.call(:altar, 94)) == ["TOAST_ALTAR_EMPTY"], "toast altar: empty while the toaster is held")
$bag.remove(:TOASTER)
check(msgs.call(talk.call("0f0fdcf5"))[1..] == ["TOAST_EYAL_REMIND_ALTAR"], "toast flow 1: without the toaster Eyal sends the player back")
log = script.call(:altar, 94)
check(msgs.call(log)[0] == "TOAST_ALTAR_REGIVE" && $bag.quantity(:TOASTER) == 1 && msgs.call(script.call(:altar, 94)) == ["TOAST_ALTAR_EMPTY"],
      "toast 6: the altar gives a lost toaster back once")

# Odd saves: an item already held is never added a second time.
oddbag = ToastTestBag.new(TOASTPERMIT: 1)
ost = { stage: :lead, crumb_given: false, plug: nil }
check(TR.permit!(ost, oddbag) && oddbag.quantity(:TOASTPERMIT) == 1 && ost[:stage] == :permit, "toast odd save: permit! with a permit held adds none")
oddbag = ToastTestBag.new(TOASTER: 1, TOASTPERMIT: 1)
ost = { stage: :permit, crumb_given: false, plug: nil }
check(TR.claim!(ost, oddbag) && oddbag.quantity(:TOASTER) == 1 && oddbag.quantity(:TOASTPERMIT) == 0 && ost[:stage] == :toaster,
      "toast odd save: claim! with a toaster held adds none and still drops the permit")

# Map setup dressing (94) and Yunik's injected call (80).
page = ToastPage.new(ToastGraphic.new("toaster_altar"), [])
rpg94 = ToastRpgMap.new({ 1 => ToastRpgEvent.new("dt_1820dc9d", [ToastPage.new(ToastGraphic.new("dt_1820dc9d"), [])]),
                          9 => ToastRpgEvent.new("toaster_altar", [page]) })
$toast_art = "Graphics/Characters/toaster_altar"
$event_handlers[:toaster_altar].call(94, rpg94, nil)
check(page.graphic.character_name == "", "toast map: the altar loads empty once the toaster is claimed")
$PokemonGlobal.toaster_quest = { stage: :permit, crumb_given: false, plug: nil }
$event_handlers[:toaster_altar].call(94, rpg94, nil)
lost_art = page.graphic.character_name
$toast_art = nil
$event_handlers[:toaster_altar].call(94, rpg94, nil)
check(lost_art == "toaster_altar" && page.graphic.character_name == "Object ball" &&
      rpg94.events[1].pages[0].graphic.character_name == "dt_1820dc9d", "toast map: art when present, else Object ball; mummies untouched")
$event_handlers[:toaster_altar].call(93, rpg94, nil)
cmd = ->(c, p) { RPG::EventCommand.new(c, 0, p) }
ypage = ToastPage.new(nil, [cmd.call(355, ['pbDesertSpeaker("326f5ab5")']), cmd.call(101, ["MSG_326F5AB5_OLDCITY"]), cmd.call(0, [])], 0)
rpg80 = ToastRpgMap.new({ 3 => ToastRpgEvent.new("dt_326f5ab5", [ypage]), 1 => ToastRpgEvent.new("Cave entrance", [ToastPage.new(nil, [cmd.call(0, [])])]) })
2.times { $event_handlers[:toaster_clerk].call(80, rpg80, nil) }
$event_handlers[:toaster_clerk].call(81, rpg80, nil)
check(ypage.list.map(&:code) == [355, 101, 355, 0] && ypage.list[2].parameters == ["pbToasterClerk"] &&
      rpg80.events[1].pages[0].list.length == 1, "toast map: Yunik's page gets one pbToasterClerk after his own line, once")

# Only his Action talk page is injected: autorun, parallel, empty and unrelated pages are skipped.
auto = ToastPage.new(nil, [cmd.call(355, ['pbDesertSpeaker("326f5ab5")']), cmd.call(0, [])], 3)
para = ToastPage.new(nil, [cmd.call(101, ["MSG_326F5AB5_OLDCITY"]), cmd.call(0, [])], 4)
empty = ToastPage.new(nil, [], 0)
other = ToastPage.new(nil, [cmd.call(101, ["something else"]), cmd.call(0, [])], 0)
talkp = ToastPage.new(nil, [cmd.call(355, ['pbDesertSpeaker("326f5ab5")']), cmd.call(0, [])], 0)
Toaster.inject_clerk(ToastRpgMap.new({ 3 => ToastRpgEvent.new("dt_326f5ab5", [auto, para, empty, other, talkp]) }))
check([auto, para, empty, other].map { |pg| pg.list.length } == [2, 2, 0, 2] && talkp.list.map(&:code) == [355, 355, 0],
      "toast map: autorun, parallel, empty and unrelated pages get no call; the Action talk page does")

# A map restored from a save (no setup) is re-injected and re-dressed, idempotently.
ToastSavedMap = Struct.new(:map_id, :events, :rpg) do
  def instance_variable_get(n) = n == :@map ? rpg : super
end
ToastLive = Struct.new(:name, :character_name)
rpg_saved80 = ToastRpgMap.new({ 3 => ToastRpgEvent.new("dt_326f5ab5", [ToastPage.new(nil, [cmd.call(355, ['pbDesertSpeaker("326f5ab5")']), cmd.call(0, [])], 0)]) })
$game_map = ToastSavedMap.new(80, {}, rpg_saved80)
2.times { Toaster.restore_saved_map }
check(rpg_saved80.events[3].pages[0].list.map(&:code) == [355, 355, 0], "toast saved map: Yunik is injected once on a restored Map080")
$PokemonGlobal.toaster_quest = { stage: :permit, crumb_given: false, plug: nil }
$toast_art = "Graphics/Characters/toaster_altar"
saved_altar = ToastPage.new(ToastGraphic.new(""), [])
live_altar = ToastLive.new("toaster_altar", "")
$game_map = ToastSavedMap.new(94, { 9 => live_altar }, ToastRpgMap.new({ 9 => ToastRpgEvent.new("toaster_altar", [saved_altar]) }))
Toaster.restore_saved_map
check(saved_altar.graphic.character_name == "toaster_altar" && live_altar.character_name == "toaster_altar",
      "toast saved map: the altar is dressed on a restored Map094 (page and live event)")
$PokemonGlobal.toaster_quest = { stage: :toaster, crumb_given: false, plug: nil }

#-------------------------------------------------------------------------------
# Finale, ceremony, crumb, after-lines, Oren
#-------------------------------------------------------------------------------
log = talk.call("0f0fdcf5", picks: [2])
check(msgs.call(log)[1..] == %w[TOAST_EYAL_FINALE_1 TOAST_EYAL_FINALE_2 TOAST_EYAL_FINALE_3 TOAST_PLUG_ASK TOAST_PLUG_NOTYET] &&
      st.call[:stage] == :toaster && $bag.quantity(:TOASTER) == 1, "toast 4: 'not yet' keeps the toaster and the stage")
frames = $toast_frames
log = talk.call("0f0fdcf5", picks: [0])
m = msgs.call(log)
end_at = m.index("TOAST_END_RECEIVED")
check(m[5, 2] == %w[TOAST_PLUG_AC_1 TOAST_PLUG_AC_2] && log.find { |e| e[0] == "TOAST_PLUG_AC_2" }[1] == "NAME_266D65C6",
      "toast finale: AC: Eyal decides, Oren howls with his own plate")
check(end_at && log.find { |e| e[0] == "TOAST_END_RECEIVED" }[1].nil? && log.index([:se, "Vending machine dispense"]) < log.index { |e| e[0] == "TOAST_END_RECEIVED" } &&
      log.any? { |e| e[0] == :flash } && $toast_frames > frames, "toast finale: tick, tick, pop and flash (frames run), then the plain narration")
check(m[end_at + 1, 4] == %w[TOAST_CEREMONY_1 TOAST_CEREMONY_2 TOAST_CEREMONY_3 TOAST_CEREMONY_4] &&
      log.index([:me, "Slots big win"]) > log.index { |e| e[0] == "TOAST_END_RECEIVED" } && gots.call(log) == ["TOASTCRUMB"],
      "toast finale: ME, the 4-step ceremony, then one framed crumb")
check(st.call == { stage: :done, crumb_given: true, plug: :ac } && $bag.quantity(:TOASTER) == 0 && $bag.quantity(:TOASTCRUMB) == 1 &&
      $bag.quantity(:TOASTPERMIT) == 0, "toast 3: done, the toaster with Eyal, one crumb, no form")
afters = 4.times.map { msgs.call(talk.call("0f0fdcf5"))[1..] }
check(afters == [["TOAST_EYAL_AFTER_1"], ["TOAST_EYAL_AFTER_2"], ["TOAST_EYAL_AFTER_3"], ["TOAST_EYAL_AFTER_1"]] && $bag.quantity(:TOASTCRUMB) == 1,
      "toast after: Eyal rotates 3 after-lines; no second crumb")
check(msgs.call(talk.call("c081cd67"))[1..] == ["TOAST_NOODLE_AFTER"] && msgs.call(script.call(:clerk, 80)) == ["TOAST_CLERK_CLOSED"] &&
      msgs.call(script.call(:altar, 94)) == ["TOAST_ALTAR_EMPTY"], "toast after: HaNoodles, Yunik and the altar remember")
check(msgs.call(talk.call("266d65c6")) == %w[MSG_266D65C6_LINE TOAST_OREN_AC_AFTER] && msgs.call(talk.call("266d65c6", 93)) == ["MSG_266D65C6_LINE"],
      "toast after: Oren complains after his line, on Kusomo only")
$PokemonGlobal.toaster_quest = { stage: :toaster, crumb_given: false, plug: nil }
$bag = ToastTestBag.new(TOASTER: 1)
log = talk.call("0f0fdcf5", picks: [1])
check(msgs.call(log)[5, 2] == %w[TOAST_PLUG_JAR_1 TOAST_PLUG_JAR_2] && st.call[:plug] == :jar &&
      msgs.call(talk.call("266d65c6")) == ["MSG_266D65C6_LINE"], "toast finale: the jar path; Oren has no complaint")
$PokemonGlobal.toaster_quest = { stage: :done, crumb_given: false, plug: :jar }
$bag = ToastTestBag.new
log = talk.call("0f0fdcf5")
check(msgs.call(log)[1] == "TOAST_CRUMB_RECOVER" && !msgs.call(log).include?("TOAST_END_RECEIVED") && $bag.quantity(:TOASTCRUMB) == 1 &&
      msgs.call(talk.call("0f0fdcf5"))[1] == "TOAST_EYAL_AFTER_2", "toast 5: crash recovery: one line and the crumb, no replay")
$PokemonGlobal.toaster_quest = "garbage"
check(st.call == TR.new_state, "toast 8: a broken saved value loads as a fresh state")
menu = ($toast_menu || []) + ($bags_menu || []) + ($planet_menu || [])
check(%i[dt_toaster_reset dt_toaster_jump dt_toaster_battle].all? { |i| menu.include?(i) }, "toast debug: the F9 entries are registered")
$bag = ToastTestBag.new(TOASTER: 1, TOASTCRUMB: 1, TOASTPERMIT: 2)
Toaster.reset
check(st.call == TR.new_state && $bag.items.values.all?(&:zero?), "toast debug: reset clears the state and the 3 items")
$toast_rules = []
$toast_outcomes = [3]
out = Toaster.final_battle
check(out == 3 && st.call == TR.new_state && $player.party == [:own_mon], "toast debug: the test battle returns the outcome and touches no state")

#-------------------------------------------------------------------------------
# Coexistence: every pbDesertTalk hook still fires for its own character
#-------------------------------------------------------------------------------
$PokemonGlobal = PokemonGlobalMetadata.new
$PokemonGlobal.planet_quest = { stage: :asked, shows: 0, finished: false }
$bag = ToastTestBag.new
chain = %i[bags_pbDesertTalk planet_pbDesertTalk toaster_pbDesertTalk].select { |a| Object.private_method_defined?(a) || respond_to?(a, true) }
check(chain.length == 3, "toast chain: the zBags, zPlanetarium and zToaster aliases are all loaded (#{chain.inspect})")
inbar = msgs.call(talk.call("c414cf08"))
hagar = msgs.call(talk.call("b19b1f15"))
cowboy = talk.call("670f79e3", picks: [1])
eyal = msgs.call(talk.call("0f0fdcf5"))
check(inbar[0] == "MSG_C414CF08_LINE" && inbar[1] == "BAGS_INBAR_ASK_1" && !inbar.any? { |k| k.start_with?("TOAST_", "PLANET_") },
      "toast chain: Inbar still runs the bags quest, and only it (#{inbar.inspect})")
check(hagar[1] == "PLANET_HAGAR_GIVE_1" && $bag.quantity(:LITTLERAM) == 1 && !hagar.any? { |k| k.start_with?("TOAST_", "BAGS_") },
      "toast chain: Hagar still gives the little ram, and only that (#{hagar.inspect})")
check(msgs.call(cowboy).include?("AW_CHALLENGE") && cowboy.none? { |e| e[0] == :received } && msgs.call(cowboy).none? { |k| k.start_with?("TOAST_") },
      "toast chain: cowboy Shirpaz still offers her arm-wrestling challenge (not now: no bag)")
check(eyal[0] == "MSG_0F0FDCF5_LINE" && eyal[1] == "TOAST_EYAL_ASK_1" && eyal.none? { |k| k.start_with?("PLANET_", "BAGS_") },
      "toast chain: Eyal on Kusomo talks only toast")
$game_map = ToastMap.new(33, events)
$toast_log.clear
$toast_picks = [1]
pbPlanetEyal
check(msgs.call($toast_log).none? { |k| k.start_with?("TOAST_") } && st.call[:stage] == :asked, "toast chain: Deep Playa Eyal (pbPlanetEyal) never runs toast")

#-------------------------------------------------------------------------------
# Layering and 10: keys
#-------------------------------------------------------------------------------
toast_src = Dir.glob(File.join(toast_dir, "*.rb")).to_h { |f| [File.basename(f, ".rb"), File.read(f, encoding: "utf-8")] }
writers = toast_src.reject { |k, _| k == "000_rules" }.select { |_, src| src.match?(/\b(st|state)\[:\w+\]\s*=[^=]/) }
check(writers.empty?, "toast: only ToasterRules writes the quest state (#{writers.keys.inspect})")
check(toast_src["000_rules"].scan(/pbMessage|\$game_|pbSEPlay|_INTL/).empty?, "toast: 000_rules is pure")
tr_doc = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
used = toast_src.values.flat_map { |src| src.scan(/\b(TOAST_[A-Z0-9_]+|NAME_[0-9A-F]{8})\b/).flatten }.uniq
bad_keys = used.reject { |k| tr_doc[k].is_a?(Hash) && !tr_doc[k]["en"].to_s.empty? && !tr_doc[k]["he"].to_s.empty? }
check(used.length > 90 && bad_keys.empty?, "toast 10: every TOAST_/NAME_ key used in zToaster has en and he (#{used.length} used, missing #{bad_keys.inspect})")
check(tr_doc["TOAST_END_RECEIVED"]["he"].b == "אייל הבוס קיבל טוסט.".b, "toast 10: TOAST_END_RECEIVED is the fixed line byte for byte")
$game_map, $bag, $PokemonGlobal, $player, $game_screen, $game_switches = saved
DesertTalk.clear_speaker if DesertTalk.respond_to?(:clear_speaker)
