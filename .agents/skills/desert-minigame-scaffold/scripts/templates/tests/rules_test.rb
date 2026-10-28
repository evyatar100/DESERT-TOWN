# __TICKET__ __NAME__: loaded from plugin_rules_test.rb (shares check/$failures and ROOT).
# __NAME__Rules is pure; the scene runs in its own process (__SNAKE___scene_smoke.rb).
require "json"
require "rbconfig"
%w[000_rules 001_state].each { |f| require File.join(ROOT, "Plugins/z__NAME__", "#{f}.rb") }

module __NAME__Test
  R = __NAME__Rules
  DIR = File.join(ROOT, "Plugins/z__NAME__")

  # Ticks with Yellow every `every` steps (0 = never) until the game ends.
  def self.play(every)
    g = R.new_game
    n = 0
    until g[:over]
      n += 1
      R.tick(g, every > 0 && (n % every).zero?)
    end
    g
  end

  check(play(0)[:over] == :lost, "__SNAKE__: an idle game is lost")
  check(play(2)[:over] == :won, "__SNAKE__: a steady presser wins")
  won = play(2)
  check(R.tick(won, true) == [] && won[:taps] == R::TARGET, "__SNAKE__: a finished game never changes")
  st = R.new_state
  check(R.record!(st, nil, 1.0) == false && st == R.new_state, "__SNAKE__: a quit records nothing")
  R.record!(st, :won, 5.0)
  R.record!(st, :lost, 9.0)
  R.record!(st, :won, 7.0)
  check(st == { wins: 2, plays: 3, best: 5.0 }, "__SNAKE__: record! counts wins and plays and keeps the best time (#{st.inspect})")
  held = { wins: 3, junk: 1, best: -2 }
  check(R.normalize(held).equal?(held) && held == { wins: 3, plays: 0, best: nil }, "__SNAKE__: normalize fixes the saved hash in place")
  check(R.normalize("garbage") == R.new_state, "__SNAKE__: garbage loads fresh")

  meta = File.read(File.join(DIR, "meta.txt"))
  check(meta.include?("Name       = __NAME__") && %w[HebrewSupport DesertTalk DesertTownArcade].all? { |r| meta.include?("Requires   = #{r}") },
        "__SNAKE__: meta.txt names __NAME__ and its 3 requirements")
  tr_data = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
  keys = Dir.glob(File.join(DIR, "*.rb")).flat_map { |f| File.read(f, encoding: "utf-8").scan(/"(__PREFIX___[A-Z0-9_]+)"/).flatten }.uniq
  missing = keys.reject { |k| tr_data[k] && !tr_data[k]["en"].to_s.strip.empty? && !tr_data[k]["he"].to_s.strip.empty? }
  check(!keys.empty? && missing.empty?, "__SNAKE__ copy: every __PREFIX___* key the code uses has en and he (missing #{missing.inspect})")

  smoke = IO.popen([RbConfig.ruby, File.join(__dir__, "__SNAKE___scene_smoke.rb")], err: [:child, :out], &:read)
  smoke_fails = smoke.lines.grep(/FAIL|Error/).map(&:strip)
  check($?.success? && smoke_fails.empty?, "__SNAKE__: scene smoke run passes (#{smoke_fails.first(3).inspect})")
end
