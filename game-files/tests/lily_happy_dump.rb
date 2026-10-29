# TG64 LilyHappy: prints the Ruby rules' constants, LCG sequence and seeded event logs as JSON,
# for the Python mirror test (T17). Usage: ruby lily_happy_dump.rb
require "json"
dir = File.join(File.expand_path("..", __dir__), "Plugins/zLilyHappy")
%w[000_rules 000_wheel_rules].each { |f| load File.join(dir, "#{f}.rb") }
R = LilyHappyRules

NAMES = %w[FPS SEATS HEART_START HEART_MAX FIX_GAIN FIX_HIT CHAIN COMP_LINES PLAY_F FINALE_F TURN_F MOOP_LOCK_F
           HALF_DELAY_F SPREAD_DELAY_F FIRST_SPAWN_F PHASES NEED CAP MAX_LAPS LILY LILY_MAPS SEAT_IDS EASY_ORDER LEFT_CAP REPORT_CAP LILY_CHARSET].freeze

# script: "random:<seed>" drives random_input from Lcg(seed); "bot" uses bot_input.
def run(seed, script)
  g = R.new_game(seed)
  rng = script.start_with?("random") ? R::Lcg.new(script.split(":")[1].to_i) : nil
  log = []
  until g[:over] == :done
    input = rng ? R.random_input(rng) : R.bot_input(g)
    ev = R.tick(g, input)
    log << [g[:f], g[:finale], ev] unless ev.empty?
  end
  { "log" => log, "hearts" => g[:hearts], "peak" => g[:peak], "laps" => g[:laps], "fixes" => g[:fixes], "k" => g[:k] }
end

# Quest-side samples for the A1 / TG65 mirror: states walked through the real mutators.
def samples
  heard = [[], %i[shorty], %i[shorty loooo gufak], %i[shorty loooo gufak turtle], R::ENCOUNTERS.keys]
  out = [R.new_state]
  heard.each do |h|
    s = R.new_state
    R.start!(s)
    h.each { |e| R.hear!(s, e) }
    out << s
  end
  out << R.state_at(:wheeled) << R.state_at(:done)
end
MAPS = [98, 91, 93, 95, 97, 96, 89, 78, 110, 109, 88, 85, 111, 112].freeze

lcg = R::Lcg.new(12_345)
out = {
  "constants" => NAMES.to_h { |n| [n, R.const_get(n)] },
  "encounters" => R::ENCOUNTERS.to_h { |k, v| [k.to_s, v] },
  "lcg" => Array.new(8) { lcg.rand },
  "quest" => samples.map do |st|
    {
      "heard" => st[:heard].map(&:to_s), "stage" => st[:stage].to_s,
      "marks" => MAPS.map { |m| R.marks(st, m).transform_keys(&:to_s) },
      "left" => R.left_places(st) { |e| e.to_s == "sushi" ? "kusomo" : e.to_s },
      "report" => R.report_list(st).then { |a, n| [a.map(&:to_s), n] }
    }
  end,
  "runs" => [[11, "random:1"], [22, "random:2"], [33, "bot"]].map { |seed, s| run(seed, s) }
}
puts JSON.generate(out)
