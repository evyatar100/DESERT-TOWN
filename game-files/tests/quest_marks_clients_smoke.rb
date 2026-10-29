# TG65 Batches 2-3 adapter smoke: each quest's real *_marks.rb registers with the real QuestMarks
# registry and resolves to the golden event ids of its first mid-quest step. Exit 0 = all passed.
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)
def echoln(*) = nil

class PokemonGlobalMetadata; end
$PokemonGlobal = PokemonGlobalMetadata.new

class SmokeBag
  def initialize(items = {}) = (@items = Hash.new(0).merge(items))
  def quantity(i) = @items[i]
  def add(i, n = 1) = (@items[i] += n; true)
  def remove(i, n = 1) = (@items[i] -= n; true)
end
$bag = SmokeBag.new

# Every quest loads before QuestMarks here: the adapters must be no-ops without it (T6).
P = File.join(ROOT, "Plugins")
QUESTS = {
  "zToaster" => %w[000_rules 001_state 009_marks], "zAllaStand" => %w[000_rules 001_state 006_marks],
  "zPlanetarium" => %w[000_rules 001_state 007_marks], "zDJRush" => %w[000_rules 001_state 008_marks],
  "zBags" => %w[000_rules 001_state 010_marks], "zShiraWedding" => %w[000_rules 001_state 007_marks],
  "zFlamingoBand" => %w[000_rules 003_marks]
}.freeze
QUESTS.each { |dir, files| files.each { |f| load File.join(P, dir, "#{f}.rb") } }
check(!defined?(QuestMarks), "T6: every adapter loads and does nothing without QuestMarks")

# FlamingoBand's main file aliases engine classes; its client reads only the saved hash.
class PokemonGlobalMetadata
  attr_accessor :flamingo_band
end
module FlamingoBand
  def self.state = ($PokemonGlobal.flamingo_band ||= FlamingoBandRules.new_state)
end

load File.join(P, "QuestMarks/000_rules.rb")
load File.join(P, "QuestMarks/001_registry.rb")
QUESTS.each { |dir, files| load File.join(P, dir, "#{files.last}.rb") }
check(QuestMarks.clients.sort == %i[alla bags djrush flamingo planet shira toaster],
      "every Batch 2-3 quest registers (#{QuestMarks.clients.inspect})")

Ev = Struct.new(:name)
# Golden names per map id (tests/golden/MapNNN.json), only the events these rows need.
MAPS = {
  80 => { 3 => "dt_326f5ab5" }, 93 => { 82 => "djrush_car", 48 => "dt_648b924a" },
  94 => { 9 => "toaster_altar" }, 95 => { 2 => "dt_670f79e3", 4 => "dt_b19b1f15", 5 => "dt_c081cd67", 15 => "dt_c414cf08" },
  98 => { 3 => "dt_9b3660d1", 4 => "dt_788b2614", 6 => "dt_bb70b1dd", 9 => "dt_4b08e38a", 10 => "dt_7a2a022c",
          15 => "dt_4c4e039d", 16 => "shira_eviatar", 17 => "shira_wedding" },
  77 => { 2 => "dt_708d6c34", 3 => "dt_9923f1c4", 4 => "dt_c626f0d6", 5 => "dt_671405a6", 6 => "dt_754ba04a",
          10 => "dt_708d6c34", 21 => "dt_708d6c34" },
  33 => { 2 => "planet_eyal" }, 109 => { 3 => "dt_d5383627" }
}.freeze
def ids(map_id) = QuestMarks.targets(map_id, QuestMarks.names_index(MAPS[map_id].transform_values { |n| Ev.new(n) }))

check(MAPS.keys.all? { |m| ids(m).empty? }, "fresh save: no mark anywhere (givers off)")
$PokemonGlobal.toaster_quest[:stage] = :lead
check(ids(80) == [3] && ids(95).empty?, "toaster :lead: Yonik (80 ev3)")
$PokemonGlobal.toaster_quest[:stage] = :permit
$bag.add(:TOASTPERMIT)
check(ids(94) == [9] && ids(80).empty?, "toaster :permit + permit held: the altar (94 ev9)")
$PokemonGlobal.alla_stand[:stage] = :campaign
$PokemonGlobal.alla_stand[:votes] = [:tal]
check(ids(98) == [4, 6], "alla :campaign: Elias and Mario (98 ev4, ev6)")
$PokemonGlobal.alla_stand[:stage] = :done
$PokemonGlobal.alla_stand[:hotdog_given] = true
$PokemonGlobal.planet_quest[:stage] = :asked
check(ids(95) == [4] && ids(33).empty?, "planet :asked, no ram: Hagar (95 ev4)")
$PokemonGlobal.dj_rush[:stage] = :intro
check(ids(93) == [82], "dj :intro: the art car (93 ev82)")
$PokemonGlobal.dj_rush[:stage] = :bag
$bag.add(:MUSICBAG)
check(ids(98) == [9] && ids(93).empty?, "dj :bag + bag held: Johnny on the Playa (98 ev9)")
$PokemonGlobal.dj_rush[:stage] = :done
$PokemonGlobal.bags_quest[:inbar] = :asked
$bag.add(:ICEBAG)
check(ids(95) == [2, 4] && ids(98) == [10] && ids(109) == [3], "bags short: cowboy (+Hagar), Toga, Pixel with an ice bag")
$bag.add(:SURPRISEBAG, 2)
check(ids(95) == [4, 15] && ids(98).empty? && ids(109).empty?, "bags count 2: Inbar only (+Hagar)")
$PokemonGlobal.shira_wedding[:stage] = :seated
check(ids(98) == [16, 17], "shira :seated: Eviatar and Shira (98 ev16, ev17)")
$PokemonGlobal.shira_wedding[:stage] = :done
FlamingoBand.state[:intro_done] = true
check(ids(77) == [2, 4, 5, 6], "band: 708d6c34 capped at its lowest id, host unmarked (#{ids(77).inspect})")
FlamingoBandRules.claim(FlamingoBand.state, "c626f0d6", 77)
check(ids(77) == [2, 5, 6], "band: a consumed member loses the mark")
check(QuestMarks.clients.none? { |k| QuestMarks.disabled?(k) }, "no client raised or was disabled")

puts($fails.empty? ? "QuestMarks clients smoke passed." : "#{$fails.size} QuestMarks clients smoke check(s) failed.")
exit($fails.empty? ? 0 : 1)
