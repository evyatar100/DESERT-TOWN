# TG64 LilyHappy scene smoke run (T15, T16, T18): fake graphics, input and clock in their
# own process. Exit 0 = all checks passed.
require_relative "lily_happy_stubs"

# script: (frame, scene) -> the buttons pressed this frame.
def run_scene(state, record: true, seed: 0, limit: 9000, &script)
  $all.clear
  $loaded.clear
  scene = LilyHappy::Scene.new(state, record: record, seed: seed)
  frames = 0
  $frame_hook = lambda do
    frames += 1
    raise "smoke: frame limit" if frames > limit
    $pressed = script.call(frames, scene) || []
  end
  [scene.run, scene]
ensure
  $frame_hook = nil
end

st = R.state_at(:asked)
res, = run_scene(st) { |_f, s| s.phase == :title ? [Input::BACK] : [] }
check(res[:result] == :quit && st == R.state_at(:asked), "Blue on the title leaves and records nothing")
check(all_disposed?, "every sprite, bitmap and the viewport are disposed on leaving")

phases = []
res, scene = run_scene(st) { |f, s| phases << s.phase unless phases.last == s.phase; BOT.call(f, s) }
vp = $all.find { |o| o.is_a?(Viewport) }
check(res[:result] == :finished && st[:stage] == :wheeled && st[:best] == res[:peak], "T16: a finished run in :asked records once (#{st.inspect})")
check(res[:peak] <= R::CAP && res[:fixes] > 0, "the bot plays by inputs (peak #{res[:peak]}, fixes #{res[:fixes]}, laps #{res[:laps]})")
check(phases == %i[title play card], "title -> play -> card (#{phases.inspect})")
check(scene.game[:f] == R::PLAY_F && scene.game[:finale] == R::FINALE_F, "the run ends at 90.0 s, then the 2.0 s finale")
check(vp && vp.z == 99_999, "the viewport sits at z 99_999, above pbFadeOutIn")
check(all_disposed?, "everything is disposed after a finished run")
check(R::SEAT_IDS.all? { |id| $loaded.include?("dt_#{id}") }, "the six seat charsets are loaded")

st2 = R.state_at(:asked)
res, = run_scene(st2, record: false, &BOT)
check(res[:result] == :finished && st2 == R.state_at(:asked), "T16: an F9 game (record: false) never writes the state")

# T15: the pause freezes the clock, the bubbles, the floats and the blinking.
def snapshot(s)
  [s.game[:f], s.game[:bubbles].map { |b| b && b[:left] }, s.instance_variable_get(:@floats).map { |x| x[:t] },
   s.instance_variable_get(:@anim), s.instance_variable_get(:@fb_t)]
end

def seq(log, key, f, keys) = keys[[f - (log[key] ||= f), keys.size - 1].min]

st3 = R.state_at(:asked)
log = {}
res, = run_scene(st3) do |f, s|
  case s.phase
  when :title then [Input::USE]
  when :play
    if log[:resume_f]
      f >= log[:resume_f] + 30 ? [Input::BACK] : []
    else
      log[:fixed_at] ||= f if s.game[:fixes] > 0
      log[:fixed_at] && f >= log[:fixed_at] + 10 ? [Input::BACK] : BOT.call(f, s)
    end
  when :pause
    if log[:resume_f] then seq(log, :p2, f, [[Input::DOWN], [], [Input::DOWN], [], [Input::USE]])
    elsif !log[:snap] then (log[:snap] = [f, snapshot(s)]; [])
    elsif f < log[:snap][0] + 90 then (log[:same] = snapshot(s) == log[:snap][1] if log[:same] != false; [])
    else (log[:resume_f] = f; [Input::BACK])
    end
  end
end
live = log[:snap][1]
check(live[2].any?(&:positive?) && live[1].any?, "T15: the pause caught live floats and bubbles (#{live.inspect})")
check(log[:same] == true, "T15: 1.5 s of pause changes no clock, bubble, float, blink or feedback timer")
check(res[:result] == :quit && st3 == R.state_at(:asked), "T16: Blue resumes; Quit in the pause records nothing")

# Restart, then quit: nothing written, and the clock starts again.
st4 = R.state_at(:asked)
log = {}
res, = run_scene(st4) do |f, s|
  case s.phase
  when :title then [Input::USE]
  when :play
    if log[:r_f]
      log[:f_after] ||= s.game[:f]
      f >= log[:r_f] + 20 ? [Input::BACK] : []
    else
      f >= 120 ? [Input::BACK] : []
    end
  when :pause
    if log[:r_f] then seq(log, :p1, f, [[Input::DOWN], [], [Input::USE]])
    else
      keys = seq(log, :p0, f, [[Input::DOWN], [], [Input::USE]])
      log[:r_f] = f if keys == [Input::USE]
      keys
    end
  end
end
check(log[:f_after] && log[:f_after] < 10, "pause Restart starts a fresh 90 s (f #{log[:f_after]})")
check(res[:result] == :quit && st4 == R.state_at(:asked), "T16: restart then quit writes nothing")

# The finale takes no input: Blue there does not pause.
st5 = R.state_at(:asked)
paused_in_finale = false
run_scene(st5) do |f, s|
  if s.phase == :play && s.game[:over] == :finale then [Input::BACK]
  elsif s.phase == :pause then paused_in_finale = true; [Input::BACK]
  else BOT.call(f, s)
  end
end
check(!paused_in_finale, "the 2.0 s finale ignores Blue")

# A replay in :done only raises best.
st6 = R.state_at(:done)
st6[:best] = 0
res, = run_scene(st6, &BOT)
check(st6[:stage] == :done && st6[:best] == res[:peak] && st6[:laps] == 1, "a replay in :done updates only best (#{st6.inspect})")

# T18: wrong-size and missing art fall back; every bitmap is still disposed.
$sizes = { "wheel_bg" => [10, 10] }
run_scene(R.new_state) { |_f, s| s.phase == :title ? [Input::BACK] : [] }
check($loaded.include?("wheel_bg") && all_disposed?, "T18: a wrong-size wheel_bg falls back and is disposed")
$sizes = { "wheel_bg" => [512, 384] }
run_scene(R.new_state) { |_f, s| s.phase == :title ? [Input::BACK] : [] }
check($loaded.include?("wheel_bg") && all_disposed?, "T18: an installed wheel_bg is used and disposed")
$sizes = {}
check(LilyHappy::Art.faces.nil?, "T18: a missing lily_faces gives no portrait")
$sizes = { "lily_faces" => [128, 128] }
check(LilyHappy::Art.faces.nil?, "T18: a wrong-size lily_faces gives no portrait")
$sizes = {}

begin
  run_scene(R.new_state) { |f, _s| raise "boom" if f == 5 }
rescue RuntimeError
  nil
end
check(all_disposed?, "an error inside the loop still disposes everything (ensure)")
check($bgm.empty?, "the scene never touches the BGM (#{$bgm.inspect})")

puts($fails.empty? ? "LilyHappy scene smoke passed." : "#{$fails.size} LilyHappy scene smoke check(s) failed.")
exit($fails.empty? ? 0 : 1)
