# TG21/TG23 Alla's stand: loaded from plugin_rules_test.rb (shares check/$failures).
# AllaRules and AllaRushRules are pure; the talk flow runs against stubs with a scripted rush scene.
require "json"
alla_dir = File.join(ROOT, "Plugins/zAllaStand")
load File.join(alla_dir, "000_rules.rb")
load File.join(alla_dir, "001_rules_rush.rb")
AR = AllaRules
ARR = AllaRushRules

class AllaTestBag
  attr_reader :items
  def initialize(items = {}) = (@items = Hash.new(0).merge(items))
  def quantity(i) = @items[i]
  def add(i, n = 1) = (@items[i] += n; true)
end
alla_st = ->(stage, extra = {}) { AR.normalize({ stage: stage }.merge(extra)) }
ALL3 = %i[tal elias mario].freeze

#-------------------------------------------------------------------------------
# T1: alla_decide for every stage x vote count x hotdog_given
#-------------------------------------------------------------------------------
wrong = []
(0..3).each do |n|
  votes = ALL3.first(n)
  [false, true].each do |given|
    want = { none: :intro, campaign: n >= 3 ? :count : :remind, rush: :rush, done: given ? :after : :hotdog_recover }
    want.each do |stage, d|
      wrong << [stage, n, given] unless AR.alla_decide(alla_st.call(stage, votes: votes, hotdog_given: given)) == d
    end
  end
end
check(wrong.empty?, "alla T1: alla_decide matches the table for every stage x votes x given (wrong: #{wrong.inspect})")

#-------------------------------------------------------------------------------
# T2: camper_decide for each camper x stage x voted x after-heard
#-------------------------------------------------------------------------------
wrong = []
ALL3.each do |who|
  [true, false].each do |voted|
    votes = voted ? [who] : []
    wrong << [:none, who] unless AR.camper_decide(alla_st.call(:none, votes: votes), who) == :plain
    wrong << [:campaign, who, voted] unless AR.camper_decide(alla_st.call(:campaign, votes: votes), who) == (voted ? :voted : :vote)
    wrong << [:rush, who] unless AR.camper_decide(alla_st.call(:rush, votes: votes), who) == :plain
    wrong << [:done, who] unless AR.camper_decide(alla_st.call(:done, votes: votes), who) == :after
    wrong << [:done_heard, who] unless AR.camper_decide(alla_st.call(:done, votes: votes), who, true) == :plain
  end
end
check(wrong.empty? && AR.camper_decide(alla_st.call(:campaign), :alla) == :plain, "alla T2: camper_decide for each camper x stage x voted (wrong: #{wrong.inspect})")

#-------------------------------------------------------------------------------
# T3: normalize
#-------------------------------------------------------------------------------
check(AR.normalize(nil) == AR.new_state && AR.normalize(5) == AR.new_state, "alla T3: missing state -> :none")
check(AR.normalize({ stage: :bogus, votes: [:tal] })[:stage] == :none && AR.normalize({ stage: "rush" })[:stage] == :none, "alla T3: junk stage -> :none")
cleaned = AR.normalize({ stage: :campaign, votes: [:mario, :tal, :tal, :bob, "elias", nil], hotdog_given: 1, extra: 1 })
check(cleaned == { stage: :campaign, votes: %i[tal mario], hotdog_given: false }, "alla T3: junk and duplicate votes cleaned, junk keys dropped (#{cleaned.inspect})")
check(AR.normalize({ stage: :done, votes: "x" })[:votes] == [], "alla T3: non-array votes -> []")
held_state = { stage: :rush, votes: [:tal], hotdog_given: true }
check(AR.normalize(held_state).equal?(held_state), "alla T3: normalize repairs the same hash in place")

#-------------------------------------------------------------------------------
# T4: the happy path through every mutator, and the guards
#-------------------------------------------------------------------------------
st = AR.new_state
bag = AllaTestBag.new
check(!AR.vote!(st, :tal) && !AR.count!(st) && !AR.open!(st) && !AR.hotdog!(st, bag), "alla T4: nothing moves from :none except campaign!")
check(AR.campaign!(st) && !AR.campaign!(st) && st[:stage] == :campaign, "alla T4: campaign! once")
check(AR.vote!(st, :tal) && !AR.vote!(st, :tal) && st[:votes] == [:tal], "alla T4: vote! is idempotent")
check(!AR.vote!(st, :bob) && st[:votes] == [:tal], "alla T4: vote! ignores a stranger")
check(!AR.count!(st) && st[:stage] == :campaign, "alla T4: count! with 1 vote is a no-op")
AR.vote!(st, :elias)
check(!AR.count!(st) && st[:stage] == :campaign, "alla T4: count! with 2 votes is a no-op")
AR.vote!(st, :mario)
check(AR.count!(st) && st[:stage] == :rush && !AR.count!(st), "alla T4: count! with 3 votes moves to :rush, once")
check(!AR.vote!(st, :tal) && !AR.hotdog!(st, bag), "alla T4: no vote and no hot dog during the rush")
check(AR.open!(st) && st[:stage] == :done && !AR.open!(st), "alla T4: open! once")
check(AR.hotdog!(st, bag) && bag.quantity(:ALLAHOTDOG) == 1 && st[:hotdog_given], "alla T4: hotdog! gives the item and sets the flag")
check(!AR.hotdog!(st, bag) && bag.quantity(:ALLAHOTDOG) == 1, "alla T4: a second hotdog! adds nothing")
held = AllaTestBag.new(ALLAHOTDOG: 1)
st2 = alla_st.call(:done)
check(AR.hotdog!(st2, held) && held.quantity(:ALLAHOTDOG) == 1 && st2[:hotdog_given], "alla T4: an item already held is not doubled")
check(!AR.hotdog!(alla_st.call(:done), nil), "alla T4: hotdog! without a bag does nothing")
st3 = alla_st.call(:done)
AR.debug_jump!(st3, :campaign_votes)
check(st3 == { stage: :campaign, votes: ALL3, hotdog_given: false } && AR.alla_decide(st3) == :count, "alla T4: debug jump 'campaign + 3 votes'")
AR.debug_jump!(st3, :campaign)
check(st3[:stage] == :campaign && st3[:votes] == [], "alla T4: debug jump 'campaign' has no votes")
AR.debug_jump!(st3, :rush)
check(st3[:stage] == :rush && st3[:votes] == ALL3, "alla T4: debug jump 'rush'")
AR.debug_jump!(st3, :done, AllaTestBag.new(ALLAHOTDOG: 1))
check(st3[:stage] == :done && st3[:hotdog_given], "alla T4: debug jump 'done' with the item held counts as given")
AR.debug_jump!(st3, :done, AllaTestBag.new)
check(!st3[:hotdog_given] && !AR.debug_jump!(st3, :none), "alla T4: debug jump 'done' without it leaves the recover path; :none is refused")

#-------------------------------------------------------------------------------
# T5: laws on hand-built orders
#-------------------------------------------------------------------------------
o = ->(toppings, voted = false) { { toppings: toppings, voted: voted } }
al = ->(law, ord) { ARR.apply_law(law, ord) }
check(al.call(0, o.call(%i[onion ketchup])) == %i[ketchup onion], "alla T5: L0 as ordered")
check(al.call(1, o.call(%i[mustard ketchup])) == %i[ketchup] && al.call(1, o.call(%i[mustard])) == [], "alla T5: L1 removes mustard (an empty bun is legal)")
check(al.call(2, o.call(%i[onion])) == %i[ketchup onion] && al.call(2, o.call(%i[ketchup kraut])) == %i[ketchup kraut], "alla T5: L2 adds ketchup once")
check(al.call(3, o.call(%i[onion mustard])) == %i[mustard onion] && al.call(3, o.call(%i[kraut])) == %i[kraut], "alla T5: L3 with exactly 2 or 1 toppings keeps them")
check(al.call(3, o.call(%i[onion mustard kraut])) == %i[mustard onion], "alla T5: L3 keeps the first 2 in listed order")
check(al.call(3, o.call(%i[kraut ketchup mustard])) == %i[ketchup kraut], "alla T5: L3 drops the listed third, not by colour")
check(al.call(4, o.call(%i[onion], false)) == [] && al.call(4, o.call(%i[onion], true)) == %i[onion], "alla T5: L4 onion only for those who voted")
check(al.call(5, o.call(%i[kraut mustard])) == %i[mustard kraut] && al.call(5, o.call(%i[kraut ketchup])) == %i[ketchup], "alla T5: L5 kraut only with mustard")
check(al.call(5, o.call(%i[kraut mustard])) != al.call(5, o.call(%i[kraut])), "alla T5: L5 after a no-mustard order the kraut goes")
check(al.call(5, ARR.apply_law(1, o.call(%i[kraut mustard])).then { |t| o.call(t) }) == [], "alla T5: L5 on an L1-style result (no mustard) drops the kraut")
check(ARR.correct?(1, o.call(%i[mustard onion]), %i[onion]) && !ARR.correct?(1, o.call(%i[mustard onion]), %i[mustard onion]) &&
      ARR.correct?(0, o.call(%i[onion mustard]), %i[mustard onion]), "alla T5: correct? compares sets, not click order")
check(ARR.sensitive?(2, o.call(%i[onion])) && !ARR.sensitive?(2, o.call(%i[ketchup])) && !ARR.sensitive?(0, o.call(%i[onion])), "alla T5: sensitive? = law(order) != order")

#-------------------------------------------------------------------------------
# T6: the rush layout over 200 seeds
#-------------------------------------------------------------------------------
problems = []
200.times do |seed|
  r = ARR.rush(seed)
  l = r[:laws]
  problems << [seed, :phase1] unless l[0] == 0
  problems << [seed, :laws] unless l[1..2].all? { |x| (1..5).include?(x) } && l[1] != l[2] && l[0] != l[1]
  problems << [seed, :count] unless r[:orders].length == 9
  [1, 2].each do |ph|
    n = r[:orders][ph * 3, 3].count { |ord| ARR.sensitive?(l[ph], ord) }
    problems << [seed, :sensitive, ph, n] if n < 2
  end
  problems << [seed, :phase1_sensitive] if r[:orders][0, 3].any? { |ord| ARR.sensitive?(0, ord) }
  r[:orders].each do |ord|
    t = ord[:toppings]
    problems << [seed, :voted] unless ord[:voted] == (ord[:customer] != ARR::STRANGER)
    problems << [seed, :empty_answer] if ARR.apply_law(ord[:law], ord).empty?
    problems << [seed, :order] unless (1..3).cover?(t.length) && t.uniq == t && (t - ARR::TOPPINGS).empty? && (ARR::CUSTOMERS + [ARR::STRANGER]).include?(ord[:customer])
  end
  problems << [seed, :determinism] unless ARR.rush(seed) == r
end
check(problems.empty?, "alla T6: 200 seeds: phase 1 is L0, no repeat, quota of 2 law-sensitive orders, same seed same rush; voted orders come from campers, others from the stranger; no bare-bun answer (#{problems.first(3).inspect})")
check((0..60).map { |s| ARR.rush(s)[:orders].map { |x| x[:toppings] } }.uniq.length > 30, "alla T6: different seeds give different rushes")

#-------------------------------------------------------------------------------
# T7: pass mark, window, early fail, and two bots
#-------------------------------------------------------------------------------
check((0..5).map { |n| ARR.pass_mark(n) } == [7, 6, 5, 5, 5, 5], "alla T7: pass_mark 7, 6, 5, 5...")
check((0..5).map { |n| ARR.window(n) } == [8.0, 9.0, 10.0, 11.0, 11.0, 11.0], "alla T7: window 8, 9, 10, 11, 11...")
check((0..4).all? { |n| ARR.early_fail?(9 - ARR.pass_mark(n) + 1, n) && !ARR.early_fail?(9 - ARR.pass_mark(n), n) }, "alla T7: early_fail? exactly when wrong > 9 - P")
bot = lambda do |losses, seed, mode|
  correct = 0
  wrong = 0
  ARR.rush(seed)[:orders].each do |ord|
    served = mode == :law ? ARR.apply_law(ord[:law], ord) : ARR.as_ordered(ord)
    ARR.correct?(ord[:law], ord, served) ? correct += 1 : wrong += 1
    break if ARR.early_fail?(wrong, losses)
  end
  ARR.passed?(correct, losses) && !ARR.early_fail?(wrong, losses)
end
check((0..199).none? { |s| bot.call(0, s, :ordered) } && (0..199).none? { |s| bot.call(1, s, :ordered) }, "alla T7: serving exactly as ordered never passes at losses 0 or 1 (200 seeds)")
check((0..199).all? { |s| [0, 1, 2, 5].all? { |l| bot.call(l, s, :law) } }, "alla T7: applying the law always passes")

#-------------------------------------------------------------------------------
# Engine stubs for the plugin files
#-------------------------------------------------------------------------------
$alla_log = []
$alla_picks = []
$alla_rushes = []
def pbMessage(msg, commands = nil, _cancel = 0)
  $alla_log << [msg, DesertTalk.name_key]
  return nil unless commands
  raise "alla test: no scripted choice for #{msg}" if $alla_picks.empty?
  $alla_picks.shift
end
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
def pbSEPlay(name, *) = ($alla_log << [:se, name])
def pbMEPlay(name, *) = ($alla_log << [:me, name])
def pbWait(_s) = ($alla_log << [:wait])
Tone = Struct.new(:r, :g, :b, :gray) unless defined?(Tone)
class AllaScreen
  def start_tone_change(tone, _d) = ($alla_log << [:tone, tone.r])
end
module GameData
  module Item
    def self.get(id) = Struct.new(:portion_name, :pocket).new(id.to_s, 8)
  end
end
class PokemonBag
  def self.pocket_names = Array.new(8) { |i| "P#{i + 1}" }
end unless PokemonBag.respond_to?(:pocket_names)
AllaMap = Struct.new(:map_id)
module AllaStand
  class RushScene
    def initialize(losses, _seed) = ($alla_log << [:rush, losses])
    def run = ($alla_rushes.shift || raise("alla test: no scripted rush result"))
  end
end
%w[001_state 002_quest 003_talk_hooks 005_debug].each { |f| load File.join(alla_dir, "#{f}.rb") }
saved = [$game_map, $bag, $PokemonGlobal, $game_screen]
$PokemonGlobal = PokemonGlobalMetadata.new
$bag = AllaTestBag.new
$game_screen = AllaScreen.new
AllaStand.reset
talk = lambda do |id, map_id = 98, picks: [], rushes: []|
  $alla_log.clear
  $alla_picks = picks
  $alla_rushes = rushes
  $game_map = AllaMap.new(map_id)
  pbDesertTalk(id)
  $alla_log.dup
end
msgs = ->(log) { log.select { |e| e.is_a?(Array) && e[0].is_a?(String) }.map { |e| e[0] } }
keys = ->(log) { msgs.call(log).map { |m| m.split("|")[0] } }
state = -> { $PokemonGlobal.alla_stand }
ALLA = "4c4e039d"
TAL = "9b3660d1"
ELIAS = "788b2614"
MARIO = "bb70b1dd"
pass = { passed: true, correct: 8, shown: 9 }
fail = { passed: false, correct: 3, shown: 6 }

check(AllaStand.state.equal?($PokemonGlobal.alla_stand) && state.call == AR.new_state, "alla: a new save starts at :none")
check(keys.call(talk.call(TAL)) == ["MSG_9B3660D1_LINE"] && keys.call(talk.call(ELIAS)) == ["MSG_788B2614_LINE"],
      "alla: campers say only their own line before the quest")
out = keys.call(talk.call(ALLA))
check(out[0] == "MSG_4C4E039D_LINE" && out[1..4] == %w[ALLA_ASK_1 ALLA_ASK_2 ALLA_ASK_3 ALLA_ASK_4] && state.call[:stage] == :campaign,
      "alla: first talk = own line, ASK_1..4, then :campaign (#{out.inspect})")
check(talk.call(ALLA).map { |e| e[0] }.grep(String).last == "ALLA_REMIND|0,NAME_9B3660D1, NAME_788B2614 וNAME_BB70B1DD",
      "alla: REMIND gets {1}=count and {2}=the missing names joined the Hebrew way")
log = talk.call(TAL)
check(keys.call(log) == %w[MSG_9B3660D1_LINE ALLA_VOTE_TAL_1 ALLA_VOTE_TAL_2] && log.last == [:se, "Voltorb Flip point"] && state.call[:votes] == [:tal] &&
      log.select { |e| e[0].to_s.start_with?("ALLA_") }.all? { |e| e[1] == "NAME_9B3660D1" }, "alla: Tal votes with her own plate and the SE (#{keys.call(log).inspect})")
check(keys.call(talk.call(TAL)) == %w[MSG_9B3660D1_LINE ALLA_VOTED_TAL], "alla: Tal again gives ALLA_VOTED_TAL")
check(keys.call(talk.call(TAL, 93)) == ["MSG_9B3660D1_LINE"] && keys.call(talk.call(TAL, 111)) == ["MSG_9B3660D1_LINE"], "alla: Tal on Map093 and Map111 says only her line")
check(msgs.call(talk.call(ALLA)).last == "ALLA_REMIND|1,NAME_788B2614 וNAME_BB70B1DD", "alla: REMIND with one vote names the other two")
talk.call(MARIO)
check(msgs.call(talk.call(ALLA)).last == "ALLA_REMIND|2,NAME_788B2614", "alla: REMIND with two votes names the one left")
check(state.call[:stage] == :campaign && AR.alla_decide(state.call) == :remind, "alla: still :campaign with 2 votes (save point)")
talk.call(ELIAS)
log = talk.call(ALLA, rushes: [fail], picks: [1])
check(keys.call(log) == %w[MSG_4C4E039D_LINE ALLA_COUNT_1 ALLA_COUNT_2 ALLA_COUNT_3 ALLA_COUNT_4 ALLA_COUNT_5 ALLA_RUSH_PRE_1 ALLA_RUSH_PRE_2 ALLA_RUSH_LOSE ALLA_RETRY_ASK] &&
      state.call[:stage] == :rush && log.include?([:rush, 0]), "alla: the count, PRE_1 and PRE_2, a failed rush, 'again?' answered No (#{keys.call(log).inspect})")
check(state.call == { stage: :rush, votes: ALL3, hotdog_given: false } && AllaStand.rush_losses == 1, "alla: a loss mutates nothing but the easing")
log = talk.call(ALLA, rushes: [fail, pass], picks: [0])
check(keys.call(log).first(9) == %w[MSG_4C4E039D_LINE ALLA_RUSH_PRE_1 ALLA_RUSH_LOSE ALLA_RETRY_ASK ALLA_END_TITLE ALLA_CEREMONY_1 ALLA_CEREMONY_2 ALLA_CEREMONY_3 ALLA_GOT_HOTDOG] &&
      keys.call(log).length == 11 && keys.call(log)[9].include?("Key item get") &&
      log.select { |e| e[0] == :rush }.map { |e| e[1] } == [1, 2], "alla: PRE_2 only the first time, retry goes at once (losses 1 then 2), then the title, ceremony, hot dog (#{keys.call(log).inspect})")
check(log.index([:me, "Slots big win"]) > log.index { |e| e[0] == "ALLA_END_TITLE" } && log.find { |e| e[0] == "ALLA_END_TITLE" }[1].nil?,
      "alla: title is narration (no plate), then the ME")
check(log.each_with_index.select { |e, _| e[0] == :tone }.map { |e, _| e[1] } == [-255, 0] && AllaStand.rush_losses == 0, "alla: the screen dims for the title and comes back; a pass resets the easing")
check(state.call == { stage: :done, votes: ALL3, hotdog_given: true } && $bag.quantity(:ALLAHOTDOG) == 1, "alla: done, hot dog given once")
out = keys.call(talk.call(ALLA))
check(out[1] == "ALLA_AFTER_1" && keys.call(talk.call(ALLA))[1] == "ALLA_AFTER_2" && keys.call(talk.call(ALLA))[1] == "ALLA_AFTER_3" && keys.call(talk.call(ALLA))[1] == "ALLA_AFTER_1" &&
      $bag.quantity(:ALLAHOTDOG) == 1, "alla: after lines rotate 1, 2, 3, 1; nothing more is given")
check(keys.call(talk.call(TAL)) == %w[MSG_9B3660D1_LINE ALLA_AFTER_TAL] && keys.call(talk.call(TAL)) == ["MSG_9B3660D1_LINE"] &&
      keys.call(talk.call(MARIO)) == %w[MSG_BB70B1DD_LINE ALLA_AFTER_MARIO] && keys.call(talk.call(ELIAS, 93)) == ["MSG_788B2614_LINE"],
      "alla: each camper says the after line once per session, then only their own; other maps untouched")
check(keys.call(talk.call(ALLA, 95)) == ["MSG_4C4E039D_LINE"], "alla: Alla's hook runs on map 98 only")
$PokemonGlobal.alla_stand = { stage: :done, votes: ALL3, hotdog_given: false }
$bag = AllaTestBag.new
log = talk.call(ALLA)
check(keys.call(log)[1] == "ALLA_HOTDOG_RECOVER" && keys.call(log)[2] == "ALLA_GOT_HOTDOG" && $bag.quantity(:ALLAHOTDOG) == 1 && state.call[:hotdog_given],
      "alla: a game stopped between open! and the hot dog recovers with one line, no replay")
AllaStand.reset
check(state.call == AR.new_state && AllaStand.rush_losses == 0 && $bag.quantity(:ALLAHOTDOG) == 1, "alla: reset gives a fresh state and keeps an item already given")
$PokemonGlobal.alla_stand = { stage: :campaign, votes: [], hotdog_given: false }
log = talk.call(ALLA, rushes: [])
check(keys.call(log) == %w[MSG_4C4E039D_LINE ALLA_REMIND], "alla: a campaign with no votes just reminds")
check(AllaStand::WARP == [11, 15, 8] && AllaStand::STAND_XY == [11, 14], "alla: the warp tile is below the stand tile")

#-------------------------------------------------------------------------------
# Layering, T8 keys, T11 grep
#-------------------------------------------------------------------------------
alla_src = Dir.glob(File.join(alla_dir, "*.rb")).to_h { |f| [File.basename(f, ".rb"), File.read(f, encoding: "utf-8")] }
writers = alla_src.reject { |k, _| k == "000_rules" }.select { |_, src| src.match?(/\b(st|state)\[:\w+\]\s*=[^=]/) }
check(writers.empty?, "alla: only AllaRules writes the quest state (#{writers.keys.inspect})")
check(alla_src.values_at("000_rules", "001_rules_rush").join.scan(/pbMessage|\$game_|pbSEPlay|_INTL|Graphics|Bitmap/).empty?, "alla: 000_rules and 001_rules_rush are pure")
tr_doc = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
used = alla_src.values.flat_map { |src| src.scan(/\b(ALLA_[A-Z0-9_]+|NAME_[0-9A-F]{8})\b/).flatten }.uniq
used = used.reject { |k| k.end_with?("_") }
ALL3.each { |w| %w[VOTE_%s_1 VOTE_%s_2 VOTED_%s AFTER_%s].each { |f| used << "ALLA_#{f % w.to_s.upcase}" } }
(0..5).each { |n| used << "ALLA_LAW_#{n}" }
used.uniq!
bad_keys = used.reject { |k| tr_doc[k].is_a?(Hash) && !tr_doc[k]["en"].to_s.empty? && !tr_doc[k]["he"].to_s.empty? }
check(used.length > 60 && bad_keys.empty?, "alla T8: every ALLA_/NAME_ key used in zAllaStand has en and he (#{used.length} used, missing #{bad_keys.inspect})")
check(tr_doc["ALLA_END_TITLE"]["he"].b == "הנקנקיה של עלא".b, "alla T8: ALLA_END_TITLE is the founder's title byte for byte")
grep = %w[pbDuel WildBattle pbShadowBasicParty].select { |n| alla_src.values.any? { |src| src.include?(n) } }
check(grep.empty?, "alla T11: zAllaStand has no duel or battle (#{grep.inspect})")

# The Rush scene against fake graphics, in its own process.
smoke = IO.popen([RbConfig.ruby, File.join(__dir__, "alla_scene_smoke.rb")], err: [:child, :out], &:read)
smoke_fails = smoke.lines.grep(/FAIL|Error/).map(&:strip)
check($?.success? && smoke_fails.empty?, "alla T12: rush scene smoke run passes (#{smoke_fails.first(3).inspect})")
$game_map, $bag, $PokemonGlobal, $game_screen = saved
DesertTalk.clear_speaker if DesertTalk.respond_to?(:clear_speaker)
