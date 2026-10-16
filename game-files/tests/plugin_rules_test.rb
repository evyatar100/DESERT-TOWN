# Frozen-engine checks for the decision methods in the Desert Town plugins.
# Stubs stand in for RPG Maker and Pokemon Essentials.

ROOT = File.expand_path("..", __dir__)
$failures = []

def check(condition, message)
  if condition
    puts "  PASS: #{message}"
  else
    puts "  FAIL: #{message}"
    $failures << message
  end
end

class PokemonBag
  def reset_last_selections; end
  def last_viewed_pocket; 0; end
end

class PokemonBag_Scene
  def pbStartScene(*); end
  def pbRefresh; end
end

class Window_DrawableCommand
  def drawItem(*); end
end

class Window_PokemonBag < Window_DrawableCommand
end

class PokemonBagScreen
end

module Game
  class << self
    def start_new; end
    def load(_data); end
  end
end

module EventHandlers
  def self.add(*); end
end

load File.join(ROOT, "Plugins/BurningManBag/burning_man_bag.rb")
load File.join(ROOT, "Plugins/HebrewSupport/ice_in_timer.rb")
load File.join(ROOT, "Plugins/HebrewSupport/ice_seller.rb")

class QuantityBag
  attr_reader :items

  def initialize(items)
    @items = Hash.new(0)
    items.each { |key, value| @items[key] = value }
  end

  def quantity(item_id)
    @items[item_id] || 0
  end

  def remove(item_id, amount = 1)
    @items[item_id] = quantity(item_id) - amount
  end

  def add(item_id, amount = 1)
    @items[item_id] = quantity(item_id) + amount
  end
end

def _INTL(message, *_args)
  message
end

$messages = []
def pbMessage(message)
  $messages << message
end

$received = []
def pbReceiveItem(item)
  $received << item
end

$scripted_choices = []
def pbShowCommands(_window, _commands, _cancel_index)
  raise "pbIceSeller asked for a choice but the test queued none" if $scripted_choices.empty?
  $scripted_choices.shift
end

def run_seller(bills, choices)
  $bag = QuantityBag.new({ TWENTYSHECKELBILL: bills })
  $messages = []
  $received = []
  $scripted_choices = choices.dup
  pbIceSeller
  $bag
end

# --- ice seller decisions ---
check(IceSellerRules.decide(0, 5) == :purchase, "5 bills purchases an ice bag")
check(IceSellerRules.decide(0, 4) == :not_enough, "4 bills is not enough")
check(IceSellerRules.decide(1, 0) == :line, "choice 1 explains the line")
check(IceSellerRules.decide(4, 9) == :exit, "exit choice leaves")
check(IceSellerRules.decide(5, 9) == :exit, "cancel leaves")

bag = run_seller(5, [0])
check(bag.quantity(:TWENTYSHECKELBILL) == 0, "purchase removes 5 bills")
check($received == [:ICEBAG], "purchase gives ICEBAG")
check($messages.include?("POPCORN_RESPONSE_THANKS"), "purchase thanks the player")

bag = run_seller(3, [0, 4])
check(bag.quantity(:TWENTYSHECKELBILL) == 3, "not enough keeps the bills")
check($received.empty?, "not enough does not give ICEBAG")
check($messages.include?("POPCORN_RESPONSE_NOT_ENOUGH"), "not enough explains the price")

bag = run_seller(5, [5])
check(bag.quantity(:TWENTYSHECKELBILL) == 5, "cancel keeps the bills")
check($received.empty?, "cancel does not give ICEBAG")

bag = run_seller(5, [4])
check(bag.quantity(:TWENTYSHECKELBILL) == 5, "exit choice keeps the bills")
check($received.empty?, "exit choice does not give ICEBAG")

# --- ice timer ---
stats = Object.new
class << stats
  attr_accessor :play_time
end
stats.play_time = 1_000
$stats = stats

game_map = Object.new
class << game_map
  attr_accessor :map_id
end
game_map.map_id = IceInTimer::ICE_IN_MAP_ID
$game_map = game_map

check(IceInTimer.seconds_remaining(1_000, 1_000, 420) == 420, "timer starts at 7 minutes")
check(IceInTimer.seconds_remaining(1_419, 1_000, 420) == 1, "419 seconds still has time left")
check(IceInTimer.seconds_remaining(1_420, 1_000, 420) == 0, "420 seconds is the timeout")

IceInTimer.stop
IceInTimer.start
check(!IceInTimer.expired?, "a fresh timer is not expired")
stats.play_time = 1_000 + 419
check(!IceInTimer.expired?, "419 seconds on the ice map is not expired")
stats.play_time = 1_000 + 420
check(IceInTimer.expired?, "420 seconds on the ice map expires")

$transfers = []
def pbTransferPlayer(map_id, x, y, direction = 2)
  $transfers << [map_id, x, y, direction]
end

$messages = []
IceInTimer.trigger_rescue
dest = IceInTimer.rescue_destination
check($transfers == [dest], "rescue requests a transfer to map 91 at (41, 35)")
check(dest == [91, 41, 35, 2], "rescue destination is Ice Camp (41, 35)")
check($messages.include?("MSG_ICE_IN_TIMEOUT"), "rescue shows the timeout message")

$transfers = []
IceInTimer.instance_variable_set(:@rescuing, true)
IceInTimer.trigger_rescue
check($transfers.empty?, "a second rescue does not start while one is running")

# --- starter items ---
[0, 1, 4].each do |amount|
  pocket = QuantityBag.new({ WHITEWATERBOTTLE: amount })
  BurningManBag.normalize_starter_quantity(pocket, :WHITEWATERBOTTLE)
  check(pocket.quantity(:WHITEWATERBOTTLE) == 1, "starter quantity #{amount} becomes 1")
end

module GameData
  module Item
    def self.exists?(_item_id)
      true
    end
  end
end

pocket = QuantityBag.new({ WHITEWATERBOTTLE: 3, USBDISK: 0 })
BurningManBag.ensure_single_starter_items(pocket)
check(pocket.quantity(:WHITEWATERBOTTLE) == 1, "three bottles collapse to one")
check(pocket.quantity(:USBDISK) == 1, "a missing disk is added once")
check(pocket.quantity(:TOWNMAP) == 1, "a missing town map is added once")

if $failures.empty?
  puts "Plugin rule tests passed."
  exit 0
end

warn "#{$failures.size} plugin rule test(s) failed."
exit 1
