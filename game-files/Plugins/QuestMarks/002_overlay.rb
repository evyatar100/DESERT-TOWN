#===============================================================================
# QuestMarks - the bobbing "!" sprites on the map (spec D2-D7). Own viewport at z 99_990;
# shown only while the player is free. Rebuilt on a map change, scene start, the busy->free
# edge and a POLL-frame check; per frame only x/y/visible change.
#===============================================================================

module QuestMarks
  module Overlay
    R = QuestMarksRules
    OUTLINE = [40, 24, 24].freeze
    BODY = [255, 255, 255].freeze
    BANG = [176, 24, 24].freeze

    @sprites = {}        # event id -> Sprite
    @ids = []
    @key = nil           # [scene, map id, events hash] the ids were built for
    @index = nil
    @was_free = false
    @dirty = false
    @frame = 0
    @poll = 0
    @frame_h = {}        # charset name -> frame height

    class << self
      attr_reader :ids, :sprites, :viewport
    end

    def self.dirty! = (@dirty = true)

    def self.flags
      t = $game_temp
      {
        scene_map: $scene.is_a?(Scene_Map),
        message: t&.message_window_showing,
        menu: t&.in_menu,
        battle: t&.in_battle,
        transfer: t&.player_transferring,
        interpreter: pbMapInterpreterRunning?,
        forced: $game_player&.move_route_forcing,
        momdad: defined?(MomDadBattle) && MomDadBattle.active?
      }
    end

    # full: after Scene_Map#update (rebuild checks, frame advance). Otherwise visibility only
    # (before update and from miniupdate, which runs inside every message and menu loop).
    def self.sync(scene, full)
      return dispose_all unless ENABLED && $game_map
      free = R.visible?(flags)
      if full
        key = [scene.object_id, $game_map.map_id, $game_map.events.object_id]
        if key != @key
          dispose_all
          @key = key
          @index = QuestMarks.names_index($game_map.events)
          rebuild
        elsif free && (!@was_free || @dirty)
          rebuild
        elsif free && (@poll += 1) >= R::POLL
          rebuild
        end
        @frame += 1
      end
      @was_free = free if full || !free
      place(free)
    end

    def self.rebuild
      @poll = 0
      @dirty = false
      ids = QuestMarks.targets($game_map.map_id, @index || {})
      return if ids == @ids && @sprites.size == ids.size
      drop_sprites
      @ids = ids
      ids.each { |id| @sprites[id] = new_sprite }
    end

    def self.place(free)
      return if @sprites.empty?
      bob = R.bob_offset(@frame)
      sw, sh = Graphics.width, Graphics.height
      @sprites.each do |id, spr|
        next if spr.disposed?
        ev = $game_map.events[id]
        show = free && ev && R.drawable?(ev.instance_variable_get(:@erased), ev.transparent, ev.opacity, ev.character_name)
        if show
          x, y = R.position(ev.screen_x, ev.screen_y, frame_h(ev.character_name))
          y += bob
          show = R.on_screen?(x, y, sw, sh)
          spr.x = x
          spr.y = y
        end
        spr.visible = !!show
      end
    end

    def self.frame_h(name)
      @frame_h[name] ||= begin
        bmp = AnimatedBitmap.new("Graphics/Characters/" + name)
        h = bmp.height / 4
        bmp.dispose
        h
      rescue StandardError
        48
      end
    end

    def self.new_sprite
      if !@viewport || @viewport.disposed?
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = R::Z
      end
      spr = Sprite.new(@viewport)
      spr.bitmap = bitmap
      spr.visible = false
      spr
    end

    # One shared balloon for the session: 12x12 body, a 2-row tail, a dark-red "!".
    def self.bitmap
      return @bitmap if @bitmap && !@bitmap.disposed?
      b = Bitmap.new(R::BALLOON_W, R::BALLOON_H)
      dark = Color.new(*OUTLINE)
      white = Color.new(*BODY)
      clear = Color.new(0, 0, 0, 0)
      b.fill_rect(0, 0, 12, 12, dark)
      b.fill_rect(1, 1, 10, 10, white)
      [[0, 0], [11, 0], [0, 11], [11, 11]].each { |x, y| b.fill_rect(x, y, 1, 1, clear) }
      b.fill_rect(4, 11, 4, 2, dark)
      b.fill_rect(5, 11, 2, 1, white)
      b.fill_rect(5, 13, 2, 1, dark)
      bang = Color.new(*BANG)
      b.fill_rect(5, 2, 2, 5, bang)
      b.fill_rect(5, 8, 2, 2, bang)
      @bitmap = b
    end

    def self.drop_sprites
      @sprites.each_value { |s| s.dispose unless s.disposed? }
      @sprites = {}
      @ids = []
    end

    # Map change, Scene_Map#dispose, ENABLED off. The shared bitmap lives for the session.
    def self.dispose_all
      drop_sprites
      @viewport.dispose if @viewport && !@viewport.disposed?
      @viewport = nil
      @key = nil
      @index = nil
      @was_free = false
    end
  end
end

# Guarded so stub engines without these methods still load the plugin.
if Scene_Map.method_defined?(:update) && Scene_Map.method_defined?(:dispose)
  class Scene_Map
    alias quest_marks_update update unless method_defined?(:quest_marks_update)
    alias quest_marks_dispose dispose unless method_defined?(:quest_marks_dispose)

    def update
      QuestMarks::Overlay.sync(self, false)
      quest_marks_update
      QuestMarks::Overlay.sync(self, true)
    end

    def dispose
      QuestMarks::Overlay.dispose_all
      quest_marks_dispose
    end
  end
end

if Scene_Map.method_defined?(:miniupdate)
  class Scene_Map
    alias quest_marks_miniupdate miniupdate unless method_defined?(:quest_marks_miniupdate)

    def miniupdate
      quest_marks_miniupdate
      QuestMarks::Overlay.sync(self, false)
    end
  end
end
