#===============================================================================
# Deep-playa 8 and 9 were saved into tileset slots the open RPG Maker XP
# project does not keep. A project save writes those slots back as nil, and
# Game_Map#updateTileset then crashes with:
#   undefined method `tileset_name' for nil:NilClass
# Rebuild the missing RPG::Tileset in memory before that call.
#===============================================================================

module DesertTownTilesets
  # map_id => [tileset_id, editor name, graphic stem]
  MAPS = {
    107 => [56, "deep-playa 8", "deep-playa 8_ts"],
    108 => [57, "deep-playa 9", "deep-playa 9_ts"]
  }

  module_function

  def ensure(game_map)
    map = game_map.instance_variable_get(:@map)
    return if !map
    spec = MAPS[game_map.map_id]
    return if !spec
    tileset_id, name, graphic = spec
    slot = map.tileset_id
    slot = tileset_id if !slot || slot <= 0
    $data_tilesets ||= []
    return if slot < $data_tilesets.length && $data_tilesets[slot]
    $data_tilesets[slot] = build(slot, name, graphic, map)
  end

  def build(tileset_id, name, graphic, map)
    count = tile_count(graphic)
    tileset = RPG::Tileset.new
    tileset.id = tileset_id
    tileset.name = name
    tileset.tileset_name = graphic
    tileset.autotile_names = ["", "", "", "", "", "", ""]
    tileset.panorama_name = ""
    tileset.panorama_hue = 0
    tileset.fog_name = ""
    tileset.fog_hue = 0
    tileset.fog_opacity = 64
    tileset.fog_blend_type = 0
    tileset.fog_zoom = 200
    tileset.fog_sx = 0
    tileset.fog_sy = 0
    tileset.battleback_name = ""
    tileset.passages = Table.new(count)
    tileset.priorities = Table.new(count)
    tileset.terrain_tags = Table.new(count)
    apply_priorities(tileset, map)
    tileset
  end

  def tile_count(graphic)
    bitmap = Bitmap.new("Graphics/Tilesets/" + graphic)
    count = 384 + (bitmap.height / 32) * 8
    bitmap.dispose
    return count
  rescue StandardError
    return 3216
  end

  def apply_priorities(tileset, map)
    data = map.data
    return if !data
    limit = tileset.priorities.xsize
    (1..2).each do |layer|
      priority = (layer == 1) ? 1 : 2
      (0...data.xsize).each do |x|
        (0...data.ysize).each do |y|
          tile_id = data[x, y, layer]
          next if !tile_id || tile_id <= 0 || tile_id >= limit
          tileset.priorities[tile_id] = priority
        end
      end
    end
  end
end

class Game_Map
  alias desert_town_tilesets_updateTileset updateTileset

  def updateTileset
    DesertTownTilesets.ensure(self)
    desert_town_tilesets_updateTileset
  end
end
