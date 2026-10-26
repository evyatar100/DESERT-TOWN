# The circus trainer battle on mom-dad-in (map 89).
module MomDadBattle
  @active = false

  def self.active?
    @active
  end

  def self.active=(value)
    @active = value
  end

  def self.play_music
    if $game_temp && !$game_temp.memorized_bgm && $game_system && $game_system.respond_to?(:getPlayingBGM)
      $game_temp.memorized_bgm = $game_system.getPlayingBGM
      $game_temp.memorized_bgm_position = (Audio.bgm_pos rescue 0)
    end
    bgm = pbGetTrainerBattleBGMFromType(:TEAMROCKET_M)
    pbBGMPlay(bgm) if bgm
  end

  def self.grant(child)
    name = MomDadBattleRules.follower_name(child[:id])
    return child if $PokemonGlobal && $PokemonGlobal.followers.any? { |follower| follower.name == name }
    event = $game_map&.events&.[](child[:event_id])
    return nil unless event && $game_temp
    $game_temp.followers.add_follower(event, name)
    follower = $game_temp.followers.get_follower_by_name(name)
    if follower && $game_player
      follower.moveto($game_player.x, $game_player.y)
      follower.direction = $game_player.direction
    end
    data = $PokemonGlobal.followers.find { |follower| follower.name == name }
    if data && $game_player && $game_map
      data.x = $game_player.x
      data.y = $game_player.y
      data.current_map_id = $game_map.map_id
      data.direction = $game_player.direction
    end
    hide_event(event)
    child
  end

  def self.hide_event(event)
    event.transparent = true if event.respond_to?(:transparent=)
    event.through = true if event.respond_to?(:through=)
  end

  def self.hide_followed_children
    return unless $game_map && $game_map.map_id == MomDadBattleRules::MAP_ID
    return unless $PokemonGlobal
    names = $PokemonGlobal.followers.map { |follower| follower.name }
    MomDadBattleRules::CHILDREN.each do |child|
      next unless names.include?(MomDadBattleRules.follower_name(child[:id]))
      event = $game_map.events[child[:event_id]]
      hide_event(event) if event
    end
  end

  def self.send_home
    $player.heal_party if $player.respond_to?(:heal_party)
    transfer = proc do
      next unless $game_temp
      $game_temp.player_transferring = true
      $game_temp.player_new_map_id = MomDadBattleRules::MAP_ID
      $game_temp.player_new_x = MomDadBattleRules::LOSE_X
      $game_temp.player_new_y = MomDadBattleRules::LOSE_Y
      $game_temp.player_new_direction = MomDadBattleRules::LOSE_DIR
      $scene.transfer_player if $scene.is_a?(Scene_Map)
    end
    if defined?(pbFadeOutIn)
      pbFadeOutIn { transfer.call }
    else
      transfer.call
    end
  end
end

def pbMomDadBattleIntro(event)
  # The event locks everyone before this runs. Unlock so they keep walking
  # through the music and the camera pan, then lock them again for the fight.
  pbGlobalUnlock if respond_to?(:pbGlobalUnlock)
  MomDadBattleRules::INTRO.each do |step|
    case step
    when :music
      MomDadBattle.play_music
      pbWait(0.75) if defined?(pbWait)
    when :pan
      MomDadBattleRules::PAN.each do |direction, distance, speed|
        pbScrollMap(direction, distance, speed)
      end
    when :effect
      pbExclaim(event) if event
    end
  end
  pbGlobalLock if respond_to?(:pbGlobalLock)
end

def pbMomDadBattleStart
  MomDadBattleRules::BATTLE_RULES.each { |rule| setBattleRule(rule) }
  MomDadBattle.active = true
  begin
    # The circus fight lends a party, then puts the player's own Pokémon back.
    return pbShadowBasicBattle if defined?(pbShadowBasicBattle)
    return TrainerBattle.start(:TEAMROCKET_M, "Grunt", 1)
  ensure
    MomDadBattle.active = false
  end
end

def pbMomDadBattleWin
  child = MomDadBattleRules.child(rand(MomDadBattleRules::CHILDREN.length))
  MomDadBattle.grant(child)
  pbMessage(_INTL("MSG_MOMDAD_BATTLE_WIN", _INTL(child[:name_key])))
end

def pbMomDadBattleLose
  pbMessage(_INTL("MSG_MOMDAD_BATTLE_LOSE"))
  MomDadBattle.send_home
end

EventHandlers.add(:on_trainer_load, :momdad_battle_no_money,
  proc { |trainer|
    next unless MomDadBattle.active?
    trainer.lose_text = _INTL("MSG_MOMDAD_BATTLE_TRAINER_LOSE")
    trainer.define_singleton_method(:base_money) { MomDadBattleRules::MONEY }
  }
)

EventHandlers.add(:on_frame_update, :momdad_hide_won_children,
  proc { MomDadBattle.hide_followed_children }
)

if defined?(Battle::Scene)
  class Battle::Scene
    alias momdad_pbCreateTrainerFrontSprite pbCreateTrainerFrontSprite unless method_defined?(:momdad_pbCreateTrainerFrontSprite)
    alias momdad_pbCreateTrainerBackSprite pbCreateTrainerBackSprite unless method_defined?(:momdad_pbCreateTrainerBackSprite)

    def pbCreateTrainerFrontSprite(idxTrainer, trainerType, numTrainers = 1)
      return if MomDadBattle.active?
      momdad_pbCreateTrainerFrontSprite(idxTrainer, trainerType, numTrainers)
    end

    def pbCreateTrainerBackSprite(idxTrainer, trainerType, numTrainers = 1)
      return if MomDadBattle.active?
      momdad_pbCreateTrainerBackSprite(idxTrainer, trainerType, numTrainers)
    end

    alias momdad_pbCommandMenu pbCommandMenu unless method_defined?(:momdad_pbCommandMenu)

    def pbCommandMenu(idxBattler, firstAction)
      return momdad_pbCommandMenu(idxBattler, firstAction) unless MomDadBattle.active?
      cmds = [
        _INTL("What will\n{1} do?", @battle.battlers[idxBattler].name),
        _INTL("Fight"),
        _INTL("Bag"),
        _INTL("Pokémon"),
        firstAction ? _INTL("Run") : _INTL("Cancel")
      ]
      ret = pbCommandMenuEx(idxBattler, cmds, firstAction ? 0 : 1)
      ret = -1 if ret == 3 && !firstAction
      ret
    end
  end
end

if defined?(Battle)
  class Battle
    alias momdad_pbRun pbRun unless method_defined?(:momdad_pbRun)

    def pbRun(idxBattler, duringBattle = false)
      if MomDadBattle.active? && trainerBattle? && @internalBattle
        battler = @battlers[idxBattler]
        return momdad_pbRun(idxBattler, duringBattle) if battler&.opposes?
        pbSEPlay("Battle flee") if defined?(pbSEPlay)
        pbDisplayPaused(_INTL("MSG_MOMDAD_BATTLE_RAN"))
        @decision = 3
        return 1
      end
      momdad_pbRun(idxBattler, duringBattle)
    end
  end
end
