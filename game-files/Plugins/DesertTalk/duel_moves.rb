#===============================================================================
# Named move labels for Desert Town duels.
# The shared duel script labels the four commands DEFEND, PRECISE ATTACK,
# FIERCE ATTACK, and SPECIAL ATTACK. While one of these duels is running,
# those four labels are that fighter's move names. Other duels keep the
# original labels.
# DesertTalk loads before HebrewSupport, so this wrapper sees the English
# label before it is drawn.
#===============================================================================

DESERT_DUEL_PROFILES = {
  [93, "dt_207a26e8"] => {
    :moves => [
      "MSG_207A26E8_MOVE1",
      "MSG_207A26E8_MOVE2",
      "MSG_207A26E8_MOVE3",
      "MSG_207A26E8_MOVE4"
    ],
    :name => "NAME_207A26E8"
  },
  [22, "Duel NPC"] => {
    :moves => [
      "MSG_PIRAMID_DUEL_MOVE1",
      "MSG_PIRAMID_DUEL_MOVE2",
      "MSG_PIRAMID_DUEL_MOVE3",
      "MSG_PIRAMID_DUEL_MOVE4"
    ],
    :name => "NAME_PIRAMID_DUEL"
  }
}

def desert_duel_profile(event)
  return nil if !$game_map || !event || !event.respond_to?(:name)
  return DESERT_DUEL_PROFILES[[$game_map.map_id, event.name.to_s]]
end

alias pbDuel_without_desert_moves pbDuel
def pbDuel(trainer_id, trainer_name, event, speeches)
  profile = desert_duel_profile(event)
  if profile
    $desert_duel_moves = profile[:moves].map { |key| _INTL(key) }
    trainer_name = _INTL(profile[:name])
  end
  begin
    return pbDuel_without_desert_moves(trainer_id, trainer_name, event, speeches)
  ensure
    $desert_duel_moves = nil if profile
  end
end

# The duel draws a trainer battle sprite for the opponent. These two fights
# leave that sprite blank. The fighter on the map, and the name and HP
# windows, stay. Other duels still show the sprite.
class IconSprite
  alias setBitmap_without_desert_duel setBitmap
  def setBitmap(file = nil, hue = 0)
    if $desert_duel_sprite_slot
      $desert_duel_sprite_slot += 1
      file = nil if $desert_duel_sprite_slot == 2
    end
    setBitmap_without_desert_duel(file, hue)
  end
end

class PokemonDuel
  alias pbStartDuel_without_desert_sprite pbStartDuel
  def pbStartDuel(opponent, event)
    $desert_duel_sprite_slot = $desert_duel_moves ? 0 : nil
    begin
      pbStartDuel_without_desert_sprite(opponent, event)
    ensure
      $desert_duel_sprite_slot = nil
    end
  end
end

alias _desert_duel_intl _INTL
def _INTL(message, *arg)
  if $desert_duel_moves.is_a?(Array)
    case message
    when "DEFEND"
      message = $desert_duel_moves[0]
    when "PRECISE ATTACK"
      message = $desert_duel_moves[1]
    when "FIERCE ATTACK"
      message = $desert_duel_moves[2]
    when "SPECIAL ATTACK"
      message = $desert_duel_moves[3]
    end
  end
  return _desert_duel_intl(message, *arg)
end
