# TG64 LilyHappy quest smoke (T6, T7, T20): the real talk hooks, Lily's flow, the camps, the
# wheel (played by the bot through the scene) and the payoff, with map and message stubs.
# A Marshal save/load round-trip runs between every step. Exit 0 = all checks passed.
require_relative "lily_happy_stubs"

$msgs = []        # [plate, text]
$choices = []     # answers for the next choice boxes (index), default 0
$saves = []
$me = []
$raise_on = nil
$scene_script = BOT

module DesertTalk
  CHARACTERS = Hash.new { |_h, id| { name_key: "NAME_#{id.upcase}", line_key: "MSG_#{id.upcase}_LINE" } }
  @name_key = nil
  def self.name_key = @name_key
  def self.name_key=(k)
    @name_key = k
  end
end

def pbMessage(text, commands = nil, _cancel = 0)
  raise Interrupt, "player closed the game" if $raise_on && text.start_with?($raise_on)
  $msgs << [DesertTalk.name_key, text]
  commands ? ($choices.shift || 0) : nil
end

def pbDesertTalk(character_id, line_key = nil)
  pbMessage(_INTL(line_key || DesertTalk::CHARACTERS[character_id][:line_key]))
end

def pbFadeOutIn
  frames = 0
  $frame_hook = lambda do
    frames += 1
    raise "smoke: frame limit" if frames > 9000
    $pressed = $scene_script.call(frames, LilyHappy::Scene.current) || []
  end
  yield
ensure
  $frame_hook = nil
end

def pbMEPlay(name) = $me << name

module DesertTownAutosave
  def self.save_now(reason) = $saves << reason
end

module MomDadBattle
  @active = false
  def self.active? = @active
  def self.active=(v)
    @active = v
  end
end

module Bags
  module Song
    @active = false
    def self.active? = @active
    def self.active=(v)
      @active = v
    end
  end
end

module TempleStickers
  def self.player_charset = $charset
end

class Ev
  attr_reader :name, :x, :y
  def initialize(name, x, y) = (@name, @x, @y = name, x, y)
  def screen_x = @x * 32
  def screen_y = @y * 32
end
GameMap = Struct.new(:map_id, :events)
GamePlayer = Struct.new(:x, :y)
$game_map = GameMap.new(98, { 2 => Ev.new("dt_648b924a", 5, 3) })
$game_player = GamePlayer.new(5, 4)

# The scene object the fade is running, for the bot.
class LilyHappy::Scene
  class << self
    attr_accessor :current
  end
  alias smoke_create create
  def create
    LilyHappy::Scene.current = self
    smoke_create
  end
end

module MenuHandlers
  def self.add(*); end
end
class Scene_Map; end

%w[004_map 005_talk_hooks 006_debug 007_payoff].each { |f| load File.join(DIR, "#{f}.rb") }

class PokemonGlobalMetadata
  attr_accessor :desert_player_charset
end
$PokemonGlobal = PokemonGlobalMetadata.new

def st = $PokemonGlobal.lily_happy

def reload!
  $PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
end

# One talk on a map, as the map event does: plate, then pbDesertTalk. Returns the messages.
def talk(map, id, choices = [])
  reload!
  $game_map.map_id = map
  $choices = choices.dup
  $msgs.clear
  DesertTalk.name_key = "NAME_#{id.upcase}"
  pbDesertTalk(id)
  $msgs.map { |_p, t| t.split("|").first }
end

def lily(map = 98, choices = []) = talk(map, LilyHappyRules::LILY, choices)
LILY_LINE = "MSG_648B924A_LINE"

# --- T7: Lily's maps ---------------------------------------------------------------
check(lily(111) == [LILY_LINE] && st[:stage] == :none, "T7: Lily on Map111 says only her line")
out = lily(98, [1])
check(out == [LILY_LINE, "LILY_INTRO_1", "LILY_INTRO_2", "LILY_INTRO_3", "LILY_ACCEPT_Q", "LILY_DECLINE"] && st[:stage] == :none,
      "D4: saying no keeps the quest fresh (#{out.inspect})")
saves0 = $saves.size
out = lily(98, [0])
check(out.last(2) == %w[LILY_GO_1 LILY_GO_CAMPS] && st[:stage] == :asked && $saves.size == saves0 + 1,
      "T20: Lily on the Playa -> accept -> :asked, autosaved")
check($msgs.select { |_p, t| t.start_with?("LILY_") }.all? { |p, _t| p == "NAME_648B924A" }, "Lily's lines are under her plate")
out = lily(91)
check(out[0..2] == [LILY_LINE, "LILY_NOT_YET", "LILY_PROGRESS"] && $msgs[2][1] == "LILY_PROGRESS|0", "T7: at the ice line: not yet, 0/4")
check($msgs[3][1] == "LILY_LEFT|LILY_CAMP_KUSOMO, LILY_CAMP_CIRCUS, LILY_CAMP_CATS, LILY_CAMP_ESCHER, LILY_CAMP_GLASS",
      "LEFT names every camp not heard (#{$msgs[3][1]})")
check(lily(93).include?("LILY_NOT_YET") && st[:stage] == :asked, "T7: at the party the same flow runs; no re-init")

# --- T6: camps ---------------------------------------------------------------------------
check(talk(88, "a715ed37") == ["MSG_A715ED37_LINE"] && talk(85, "661f55e6") == ["MSG_661F55E6_LINE"] && st[:heard].empty?,
      "T6: Mor on 88 and Changa on 85 say only their line")
check(talk(98, "6b53f14c") == ["MSG_6B53F14C_LINE"], "T6: Loooo is a seat only, not an encounter")
out = talk(95, "a715ed37")
check(out == %w[MSG_A715ED37_LINE LILY_KUSOMO_1 LILY_KUSOMO_2 LILY_HEARD] && $msgs.last == [nil, "LILY_HEARD|1"] && st[:heard] == [:kusomo],
      "T20: Kusomo: the complaint, then the 1/4 toast with no plate (#{out.inspect})")
check($msgs[1][0] == "NAME_A715ED37", "the complaint stays under the NPC's own plate")
check(talk(95, "a715ed37") == %w[MSG_A715ED37_LINE LILY_KUSOMO_AGAIN] && st[:heard].size == 1, "T20: a second talk gives AGAIN and counts nothing")
$raise_on = "LILY_CIRCUS_2"
begin
  talk(89, "a4012984")
rescue Interrupt
  nil
end
$raise_on = nil
check(st[:heard] == [:kusomo], "a complaint cut off mid-dialogue counts nothing")
talk(89, "a4012984")
talk(78, "3dc31934")
check(st[:heard] == %i[kusomo circus cats] && $msgs.last == [nil, "LILY_HEARD|3"], "T20: circus and cats counted in order")
out = lily(93)
check($msgs[2][1] == "LILY_PROGRESS|3" && $msgs[3][1] == "LILY_LEFT|LILY_CAMP_ESCHER, LILY_CAMP_GLASS", "back early: 3/4 and the two camps left")
talk(110, "b3fb6767")
check($msgs.last == [nil, "LILY_HEARD_ALL"] && LilyHappyRules.ready?(st), "T20: the 4th complaint says HEARD_ALL")
talk(109, "661f55e6")
check($msgs.last == [nil, "LILY_HEARD_EXTRA"] && st[:heard].size == 5, "a 5th complaint says HEARD_EXTRA, not 4 of 4")

# --- the wheel from Lily -----------------------------------------------------------------------
Bags::Song.active = true
out = lily(98, [0])
Bags::Song.active = false
check(out.last == "LILY_LATER" && st[:stage] == :asked, "busy (bags song): LATER without opening the wheel")
check(lily(98, [1]).last == "LILY_LATER", "WHEEL_LATER: LATER")
$scene_script = ->(_f, s) { s.phase == :title ? [Input::BACK] : [] }
out = lily(98, [0])
check(out.last == "LILY_WHEEL_QUIT" && st[:stage] == :asked, "T16: quitting the wheel records nothing; stays :asked")
$scene_script = BOT
MomDadBattle.active = true
check(lily(98) == [LILY_LINE], "no-op while the circus battle runs")
MomDadBattle.active = false

$sizes = { "lily_faces" => [512, 128] }
faces = []
LilyHappy::Portrait.singleton_class.prepend(Module.new { def show(f) = ($faces_log << f; super) })
$faces_log = faces
$raise_on = "LILY_PAYOFF_2"
begin
  lily(98, [0])
rescue Interrupt
  nil
end
$raise_on = nil
check(st[:stage] == :wheeled && st[:best] && st[:best] <= 3, "T20: the bot finishes the wheel -> :wheeled (best #{st[:best]})")
check(LilyHappy::Portrait.viewport.nil? && $all.select { |o| o.is_a?(Viewport) }.all?(&:disposed?), "an interrupted payoff disposes the portrait")
faces.clear
me0 = $me.size
saves0 = $saves.size
out = lily(91)
expect = [LILY_LINE, "LILY_REPORT_OPEN", "LILY_REPORT_KUSOMO", "LILY_REACT_1", "LILY_REPORT_CIRCUS", "LILY_REACT_2",
          "LILY_REPORT_CATS", "LILY_REACT_3", "LILY_REPORT_ESCHER", "LILY_REACT_4", "LILY_REPORT_GLASS", "LILY_REACT_5", "LILY_REPORT_WHEEL",
          st[:best] >= 3 ? "LILY_REACT_WHEEL" : "LILY_REACT_WHEEL_LOW", "LILY_PAYOFF_1", "LILY_PAYOFF_2", "LILY_PAYOFF_3"]
check(out == expect, "T4/T20: :wheeled replays the whole payoff on the next talk (#{out.inspect})")
check(faces == %i[grumpy curious giggle giggle giggle giggle giggle beam], "the portrait goes grumpy -> curious -> giggle -> beam (#{faces.inspect})")
check($me.size == me0 + 1 && $me.last == "Slots big win" && st[:stage] == :done && $saves.size == saves0 + 1, "T20: one jingle, :done, autosaved")
check($msgs.find { |_p, t| t.start_with?("LILY_REPORT_WHEEL") }[1] == "LILY_REPORT_WHEEL|#{st[:best]},#{st[:laps]}", "REPORT_WHEEL carries best and laps")
narr = %w[LILY_REPORT_OPEN LILY_REPORT_KUSOMO LILY_PAYOFF_3]
check($msgs.select { |_p, t| narr.include?(t.split("|").first) }.all? { |p, _t| p.nil? }, "report lines and PAYOFF_3 are narration (no plate)")
check(LilyHappy::Portrait.viewport.nil?, "the portrait is gone after the payoff")

# --- after: nothing repeats -----------------------------------------------------------------------
me_done = $me.size
out = lily(93, [1])
check(out == [LILY_LINE, "LILY_IDLE", "LILY_REPLAY_Q"] && $me.size == me_done, "T20: :done -> IDLE + replay offer, no second payoff")
best = st[:best]
out = lily(98, [0])
peak = $msgs.last[1].split("|")[1].to_i
check(out.last == (peak >= 3 ? "LILY_REPLAY_AFTER" : "LILY_REPLAY_AFTER_LOW") && st[:stage] == :done && st[:best] >= best, "a replay in :done: REPLAY_AFTER, best only (#{st.inspect})")
check(talk(109, "661f55e6") == ["MSG_661F55E6_LINE"] && talk(95, "a715ed37") == ["MSG_A715ED37_LINE"], "camps say nothing extra in :done")

# --- mirror ----------------------------------------------------------------------------------------
$PokemonGlobal.lily_happy = nil
$charset = "dt_648b924a"
check(lily(98, [1])[1] == "LILY_MIRROR", "playing as Lily: MIRROR before the intro")
$charset = nil
check(lily(98, [1])[1] == "LILY_INTRO_1", "another player character: no MIRROR")

check($bgm.empty?, "the quest never touches the BGM (#{$bgm.inspect})")

puts($fails.empty? ? "LilyHappy quest smoke passed." : "#{$fails.size} LilyHappy quest smoke check(s) failed.")
exit($fails.empty? ? 0 : 1)
