# Decisions for the mom-dad-in circus battle. No graphics, audio, or map access.
module MomDadBattleRules
  MAP_ID = 89
  LOSE_X = 25
  LOSE_Y = 3
  LOSE_DIR = 2
  # Prize money and the money you drop on a loss are both zero.
  MONEY = 0
  BATTLE_RULES = ["noMoney", "canLose", "canRun"].freeze
  # Music, then the camera, then the effect, then the fight.
  INTRO = [:music, :pan, :effect, :fight].freeze
  # The tour already on the event. Right, up, left, left, down, right. It ends where it started.
  PAN = [[6, 8, 4], [8, 8, 4], [4, 8, 4], [4, 8, 4], [2, 8, 4], [6, 8, 4]].freeze
  # The four children of camp אמאל'ה ואבאלה on this map.
  CHILDREN = [
    { id: "4c6540a3", event_id: 8, name_key: "NAME_4C6540A3" },
    { id: "65029b81", event_id: 12, name_key: "NAME_65029B81" },
    { id: "b25567c8", event_id: 14, name_key: "NAME_B25567C8" },
    { id: "890b649e", event_id: 20, name_key: "NAME_890B649E" }
  ].freeze

  def self.child(index)
    CHILDREN[index % CHILDREN.length]
  end

  def self.follower_name(character_id)
    "momdad_child_#{character_id}"
  end

  # 1 is a win. A loss, a forfeit, and running away are all a loss.
  def self.outcome(code)
    code == 1 ? :win : :lose
  end

  def self.pan_returns_home?
    dx = 0
    dy = 0
    PAN.each do |direction, distance, _speed|
      case direction
      when 6 then dx += distance
      when 4 then dx -= distance
      when 2 then dy += distance
      when 8 then dy -= distance
      else return false
      end
    end
    dx == 0 && dy == 0
  end
end
