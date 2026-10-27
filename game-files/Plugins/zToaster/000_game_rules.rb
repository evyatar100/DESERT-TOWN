#===============================================================================
# Toaster (TG17) - pure rules for Yunik's two mini-games: the Stamp Desk and the
# Eviction. No graphics, audio or messages. Python mirror: tests/toaster_rules.py.
#===============================================================================

module ToasterDeskRules
  FORMS = 12
  PHASE_LEN = 4
  STRIPES = %i[green red blue yellow].freeze
  COPIES = [1, 2, 3].freeze
  APPLIANCES = (1..8).to_a.freeze
  HEATING = [1, 2, 3, 4].freeze
  RULES = [1, 2, 3, 4, 5, 6].freeze
  FIRST_RULES = [1, 3, 4].freeze
  BANNER_TIME = 2.0
  SLIDE_TIME = 0.25
  SETTLE_TIME = 0.15
  STAMP_TIME = 0.4
  CARD_LOCK = 1.0

  def self.heats?(form)
    HEATING.include?(form[:appliance])
  end

  # true = the correct answer is approve.
  def self.approve?(rule, form)
    case rule
    when 1 then form[:copies] == 3
    when 2 then !heats?(form)
    when 3 then form[:stripe] == :green
    when 4 then form[:stripe] != :red
    when 5 then form[:stripe] != :blue || form[:copies] >= 2
    when 6 then !heats?(form) || form[:stripe] == :yellow
    else false
    end
  end

  def self.random_form(rng)
    { stripe: STRIPES[rng.rand(STRIPES.length)], copies: COPIES[rng.rand(COPIES.length)],
      appliance: APPLIANCES[rng.rand(APPLIANCES.length)] }
  end

  # Re-rolls until the form's answer under the rule is the wanted one.
  def self.form_for(rng, rule, want)
    loop do
      f = random_form(rng)
      return f.merge(approve: want) if approve?(rule, f) == want
    end
  end

  # {rules: [3 rule ids], forms: [12 forms with :approve]}; one Random per hearing.
  def self.hearing(seed)
    rng = Random.new(seed)
    rules = []
    rules << FIRST_RULES[rng.rand(FIRST_RULES.length)]
    2.times do
      pool = RULES - [rules.last]
      rules << pool[rng.rand(pool.length)]
    end
    forms = rules.flat_map do |rule|
      wants = [true, true, false, false].shuffle(random: rng)
      wants.map { |w| form_for(rng, rule, w) }
    end
    { rules: rules, forms: forms }
  end

  def self.phase(index)
    index / PHASE_LEN
  end

  def self.pass_mark(losses)
    [10 - losses, 7].max
  end

  def self.window(losses)
    [6.0 + 1.0 * losses, 9.0].min
  end

  def self.early_fail?(wrong, losses)
    wrong > FORMS - pass_mark(losses)
  end

  # pressed: true approve, false reject, nil timeout (always wrong).
  def self.correct?(form, pressed)
    !pressed.nil? && pressed == form[:approve]
  end

  def self.passed?(correct, losses)
    correct >= pass_mark(losses)
  end
end

module ToasterEvictRules
  CELLS = 9
  COLS = 3
  CENTRE = 4
  STAMPS = 5
  TIME = 60.0
  WINDOWS = [1.60, 1.35, 1.15, 0.95, 0.80].freeze
  GAP = 0.35
  HIT_GAP = 0.60
  POP_TIME = 0.12
  FLICKER_MIN_H = 2
  FLICKER_CHANCE = 0.25
  FLICKER_TIME = 0.25
  WASTE_LOCK = 0.50
  HIT_LOCK = 0.25
  WASTE_SHOW = 0.5
  ZIP_TIME = 0.5
  CARD_TIME = 1.5

  def self.ease(losses)
    [1.0 + 0.10 * losses, 1.40].min
  end

  def self.window(h, losses)
    WINDOWS[h.clamp(0, WINDOWS.length - 1)] * ease(losses)
  end

  def self.start_h(last_hits)
    [[last_hits - 1, 0].max, 3].min
  end

  # A random cell that is none of the excluded ones (nil entries ignored).
  def self.spawn(rng, *excluded)
    pool = (0...CELLS).to_a - excluded.compact
    pool[rng.rand(pool.length)]
  end

  def self.flicker?(rng, h)
    h >= FLICKER_MIN_H && rng.rand < FLICKER_CHANCE
  end

  # One step in screen space, no wrapping. dir: 2 down, 4 left, 6 right, 8 up.
  def self.move(cell, dir)
    row, col = cell.divmod(COLS)
    case dir
    when 2 then row += 1 if row < COLS - 1
    when 8 then row -= 1 if row > 0
    when 4 then col -= 1 if col > 0
    when 6 then col += 1 if col < COLS - 1
    end
    row * COLS + col
  end
end
