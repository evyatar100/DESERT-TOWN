#===============================================================================
# __NAME__ - pure rules (no engine calls). Python mirror: tests/__SNAKE___rules.py.
# Scaffold game: press Yellow TARGET times within LIMIT seconds. Replace with the spec's game.
#===============================================================================

module __NAME__Rules
  DT = 1.0 / 60
  TARGET = 20
  LIMIT = 10.0
  MAX_COUNT = 9_999
  KEYS = %i[wins plays best].freeze

  def self.new_state
    { wins: 0, plays: 0, best: nil }
  end

  # In place, so a held reference to the saved hash stays live; garbage loads fresh.
  def self.normalize(state)
    return new_state unless state.is_a?(Hash)
    state.keys.each { |k| state.delete(k) unless KEYS.include?(k) }
    state[:wins] = state[:wins].is_a?(Integer) ? state[:wins].clamp(0, MAX_COUNT) : 0
    state[:plays] = state[:plays].is_a?(Integer) ? state[:plays].clamp(0, MAX_COUNT) : 0
    state[:best] = nil unless state[:best].is_a?(Numeric) && state[:best] > 0
    state
  end

  def self.new_game
    { time: 0.0, taps: 0, over: nil }
  end

  # One fixed 1/60 s step. Returns this step's events; a finished game never changes.
  def self.tick(g, press)
    return [] if g[:over]
    events = []
    g[:time] += DT
    if press
      g[:taps] += 1
      events << :tap
    end
    if g[:taps] >= TARGET
      g[:over] = :won
      events << :won
    elsif g[:time] >= LIMIT
      g[:over] = :lost
      events << :lost
    end
    events
  end

  # The only writer of the saved state. A quit (any other result) records nothing.
  def self.record!(state, result, time)
    return false unless %i[won lost].include?(result)
    state[:plays] = [state[:plays] + 1, MAX_COUNT].min
    if result == :won
      state[:wins] = [state[:wins] + 1, MAX_COUNT].min
      state[:best] = time if state[:best].nil? || time < state[:best]
    end
    true
  end
end
