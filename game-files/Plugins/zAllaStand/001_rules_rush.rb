#===============================================================================
# AllaStand (TG23) - pure rules for the Hot-Dog Rush: toppings, Alla's laws, the
# rush layout, pass mark and decision window. No graphics, audio or messages.
#===============================================================================

module AllaRushRules
  ORDERS = 9
  PHASE_LEN = 3
  TOPPINGS = %i[ketchup mustard onion kraut].freeze
  LAWS = [0, 1, 2, 3, 4, 5].freeze
  CUSTOMERS = %i[tal elias mario].freeze
  # The three campers have all voted by the rush; a voted=false order comes from a stranger.
  STRANGER = :stranger
  SENSITIVE_MIN = 2
  SLIDE_TIME = 0.25
  INPUT_LOCK = 0.15
  RESULT_TIME = 0.5
  BANNER_TIME = 3.0
  CARD_LOCK = 1.0

  # An order: {toppings: [distinct, in listed order], voted: bool}. The answer is a set of toppings.
  def self.apply_law(law, order)
    t = order[:toppings].dup
    case law
    when 1 then t.delete(:mustard)
    when 2 then t << :ketchup unless t.include?(:ketchup)
    when 3 then t = t.first(2)
    when 4 then t.delete(:onion) unless order[:voted]
    when 5 then t.delete(:kraut) unless t.include?(:mustard)
    end
    TOPPINGS.select { |k| t.include?(k) }
  end

  def self.as_ordered(order)
    TOPPINGS.select { |k| order[:toppings].include?(k) }
  end

  def self.sensitive?(law, order)
    apply_law(law, order) != as_ordered(order)
  end

  def self.correct?(law, order, served)
    served.sort == apply_law(law, order).sort
  end

  def self.random_order(rng)
    n = 1 + rng.rand(3)
    { toppings: TOPPINGS.shuffle(random: rng).first(n), voted: rng.rand(2) == 0 }
  end

  # Re-rolls until the order's sensitivity to the law is the wanted one and the answer is not a bare bun.
  def self.order_for(rng, law, want)
    loop do
      o = random_order(rng)
      next if apply_law(law, o).empty? || sensitive?(law, o) != want
      return o.merge(customer: o[:voted] ? CUSTOMERS[rng.rand(CUSTOMERS.length)] : STRANGER)
    end
  end

  # {laws: [3 law ids], orders: [9 orders]}; one Random per rush.
  def self.rush(seed)
    rng = Random.new(seed)
    laws = [0]
    2.times do
      pool = LAWS.drop(1) - [laws.last]
      laws << pool[rng.rand(pool.length)]
    end
    orders = []
    laws.each_with_index do |law, i|
      if i == 0
        PHASE_LEN.times { orders << order_for(rng, 0, false) }
      else
        wants = [true, true, rng.rand(2) == 0].shuffle(random: rng)
        wants.each { |w| orders << order_for(rng, law, w) }
      end
    end
    orders.each_with_index { |o, k| o[:law] = laws[k / PHASE_LEN] }
    { laws: laws, orders: orders }
  end

  def self.phase(index)
    index / PHASE_LEN
  end

  def self.pass_mark(losses)
    [7 - losses, 5].max
  end

  def self.window(losses)
    [8.0 + 1.0 * losses, 11.0].min
  end

  def self.early_fail?(wrong, losses)
    wrong > ORDERS - pass_mark(losses)
  end

  def self.passed?(correct, losses)
    correct >= pass_mark(losses)
  end
end
