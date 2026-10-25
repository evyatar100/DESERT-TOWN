# Shadow trainer - basic (TEAMROCKET_M Grunt 1).
# The player's party is swapped for this fight and put back afterwards.

def pbShadowBasicPokemon(species, item, nature, ability_index, moves, evs)
  pkmn = Pokemon.new(species, 70, $player, false)
  pkmn.item = item
  pkmn.nature = nature
  pkmn.ability_index = ability_index
  moves.each { |move| pkmn.learn_move(move) }
  GameData::Stat.each_main do |s|
    pkmn.iv[s.id] = 31
    pkmn.ev[s.id] = evs[s.id] || 0
  end
  pkmn.calc_stats
  pkmn.heal
  pkmn
end

def pbShadowBasicParty
  [
    pbShadowBasicPokemon(:PIKACHU, :LIGHTBALL, :TIMID, 0,
                         [:THUNDERBOLT, :VOLTTACKLE, :IRONTAIL, :QUICKATTACK],
                         { :HP => 4, :SPEED => 252, :SPECIAL_ATTACK => 252 }),
    pbShadowBasicPokemon(:CHARIZARD, :CHARCOAL, :TIMID, 0,
                         [:FLAMETHROWER, :AIRSLASH, :DRAGONPULSE, :ROOST],
                         { :HP => 4, :SPEED => 252, :SPECIAL_ATTACK => 252 }),
    pbShadowBasicPokemon(:SNORLAX, :LEFTOVERS, :ADAMANT, 1,
                         [:BODYSLAM, :EARTHQUAKE, :CRUNCH, :HAMMERARM],
                         { :HP => 252, :ATTACK => 252, :SPECIAL_DEFENSE => 4 })
  ]
end

def pbShadowBasicBattle
  old_party = $player.party
  $player.party = pbShadowBasicParty
  begin
    TrainerBattle.start(:TEAMROCKET_M, "Grunt", 1)
  ensure
    $player.party = old_party
  end
end
