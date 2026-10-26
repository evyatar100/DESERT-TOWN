# Safe RPG Maker XP map event I/O through real Ruby Marshal (see ../SKILL.md).
# Usage: ruby rxdata_io.rb <dump|add|move|set-move|retarget|delete|verify> MAP.rxdata [options]
require 'json'
require 'optparse'
require 'fileutils'

# Opaque binary types: kept as raw bytes so they dump back exactly.
class RawUserDef
  attr_reader :bytes
  def initialize(bytes) = @bytes = bytes
  def _dump(_lvl) = @bytes
end
%w[Table Color Tone Rect].each do |n|
  Object.const_set(n, Class.new(RawUserDef) { def self._load(b) = new(b) })
end

def define_path(path)
  parent = Object
  path.split('::').each do |part|
    parent = if parent.const_defined?(part, false)
               parent.const_get(part, false)
             else
               parent.const_set(part, part == 'RPG' ? Module.new : Class.new)
             end
  end
  parent
end

def marshal_load(bytes, tries = 300)
  Marshal.load(bytes)
rescue ArgumentError => e
  raise unless (m = e.message.match(%r{undefined class/module ([\w:]+)})) && tries > 0
  define_path(m[1])
  marshal_load(bytes, tries - 1)
end

# Structural fingerprint; shared objects are tracked by identity, ivar order ignored.
def canon(o, seen = {})
  case o
  when nil, true, false, Integer, Float, Symbol then return o
  end
  return [:ref, seen[o.object_id]] if seen.key?(o.object_id)
  seen[o.object_id] = seen.size
  case o
  when Array then o.map { |x| canon(x, seen) }
  when Hash then o.map { |k, v| [canon(k, seen), canon(v, seen)] }
  when RawUserDef then [o.class.name, o.bytes]
  when String then [o.encoding.name, o.bytes]
  else [o.class.name, o.instance_variables.sort.map { |iv| [iv, canon(o.instance_variable_get(iv), seen)] }]
  end
end

def fail!(msg, code = 2)
  warn "ERROR: #{msg}"
  exit code
end

# ---- safety gates ---------------------------------------------------------
def editor_running?
  out = `tasklist /NH /FO CSV 2>NUL`.encode('UTF-8', invalid: :replace, undef: :replace)
  out.lines.any? { |l| l =~ /\A"(RPGXP|Game)\.exe"/i }
end

def inside_project?(path)
  dir = File.dirname(File.expand_path(path))
  loop do
    return true if File.exist?(File.join(dir, 'Game.ini'))
    parent = File.dirname(dir)
    return false if parent == dir
    dir = parent
  end
end

# --scratch-copy skips the editor check, but only for files outside a game project.
def gate!(target, scratch)
  if scratch
    fail!('--scratch-copy refused: target is inside a game project') if inside_project?(target)
  elsif editor_running?
    fail!('RPGXP.exe or Game.exe is running; close it (saving there would overwrite this write).')
  end
end

# ---- object helpers -------------------------------------------------------
def iv(o, n) = o.instance_variable_get("@#{n}")

def ivs(o, h)
  h.each { |k, v| o.instance_variable_set("@#{k}", v) }
end

def newobj(cls, h)
  o = define_path(cls).new
  ivs(o, h)
  o
end

# Existing maps store strings as raw bytes (ASCII-8BIT); new ones match.
def bin(s) = s.to_s.dup.force_encoding(Encoding::BINARY)
def txt(s) = s.is_a?(String) ? s.dup.force_encoding(Encoding::UTF_8).scrub : s

def load_map(path)
  fail!("not found: #{path}") unless File.file?(path)
  m = begin
    marshal_load(File.binread(path))
  rescue StandardError => e
    fail!("cannot read #{path}: #{e.class}: #{e.message[0, 100]}")
  end
  fail!('not a map (no @events)') unless iv(m, :events).is_a?(Hash)
  m
end

def jsonify(v, depth = 0)
  case v
  when nil, true, false, Integer, Float then v
  when Symbol then v.to_s
  when String then txt(v)
  when Array then v.map { |x| jsonify(x, depth + 1) }
  when Hash then v.to_h { |k, x| [jsonify(k, depth + 1).to_s, jsonify(x, depth + 1)] }
  when RawUserDef then { '_class' => v.class.name, 'bytes' => v.bytes.size }
  else
    return { '_class' => v.class.name, '_deep' => true } if depth > 12
    h = { '_class' => v.class.name }
    v.instance_variables.sort.each { |n| h[n.to_s.delete('@')] = jsonify(v.instance_variable_get(n), depth + 1) }
    h
  end
end

# ---- event construction ---------------------------------------------------
def cmd(code, params, indent = 0)
  newobj('RPG::EventCommand', code: code, indent: indent, parameters: params)
end

def spec_commands(spec)
  list = []
  if spec['talk']
    cid = spec['talk'].to_s
    fail!("talk must be a hex character id, got #{cid.inspect}") unless cid.match?(/\A\h+\z/)
    list << cmd(355, [bin(%(pbDesertSpeaker("#{cid}")))])
    list << cmd(355, [bin(%(pbDesertTalk("#{cid}")))])
  end
  cmds = spec['commands'] || []
  fail!('commands must be a list') unless cmds.is_a?(Array)
  cmds.each do |c|
    fail!('each command needs a "code"') unless c.is_a?(Hash) && c['code'].is_a?(Integer)
    params = (c['parameters'] || []).map { |p| p.is_a?(String) ? bin(p) : p }
    list << cmd(c.fetch('code'), params, c['indent'] || 0)
  end
  list << cmd(0, []) unless list.last && iv(list.last, :code) == 0
  list
end

def move_cmd(code, params = [])
  newobj('RPG::MoveCommand', code: code, parameters: params)
end

# Custom autonomous route. Each entry is [code, parameters]. Code 14 is Jump.
# The list always ends with the empty MoveCommand, same as maps saved by RPGXP.
def build_route(spec)
  commands = spec['route']
  unless commands
    return newobj('RPG::MoveRoute', repeat: true, skippable: false, list: [cmd(0, [])])
  end
  fail!('route must be a list of [code, parameters]') unless commands.is_a?(Array)
  list = commands.map do |entry|
    fail!('each route step must be [code, parameters]') unless entry.is_a?(Array) && entry[0].is_a?(Integer)
    params = entry[1] || []
    fail!('route parameters must be a list') unless params.is_a?(Array)
    move_cmd(entry[0], params)
  end
  list << move_cmd(0) unless list.last && iv(list.last, :code) == 0
  newobj('RPG::MoveRoute', repeat: spec.fetch('route_repeat', true),
         skippable: spec.fetch('skippable', false), list: list)
end

def flag(spec, key, default)
  spec.key?(key) ? spec[key] : default
end

def build_talk_event(id, spec)
  g = newobj('RPG::Event::Page::Graphic', tile_id: 0, character_name: bin(spec['graphic'] || ''),
             character_hue: 0, direction: spec['direction'] || 2, pattern: 0, opacity: 255, blend_type: 0)
  cond = newobj('RPG::Event::Page::Condition', switch1_valid: false, switch2_valid: false, variable_valid: false,
                self_switch_valid: false, switch1_id: 1, switch2_id: 1, variable_id: 1, variable_value: 0,
                self_switch_ch: bin('A'))
  route = build_route(spec)
  page = newobj('RPG::Event::Page', condition: cond, graphic: g,
                move_type: spec['move_type'] || 0,
                move_speed: spec['move_speed'] || 3,
                move_frequency: spec['move_frequency'] || 6,
                move_route: route,
                walk_anime: flag(spec, 'walk_anime', true),
                step_anime: flag(spec, 'step_anime', false),
                direction_fix: flag(spec, 'direction_fix', false),
                through: flag(spec, 'through', false),
                always_on_top: false, trigger: spec['trigger'] || 0, list: spec_commands(spec))
  newobj('RPG::Event', id: id, name: bin(spec['name']), x: spec['x'], y: spec['y'], pages: [page])
end

# Deep copy via Marshal, then apply overrides to the first page.
def clone_event(src, id, spec)
  e = Marshal.load(Marshal.dump(src))
  ivs(e, id: id)
  ivs(e, name: bin(spec['name'])) if spec['name']
  ivs(e, x: spec['x']) if spec['x']
  ivs(e, y: spec['y']) if spec['y']
  page = iv(e, :pages)&.first or fail!("clone_from event has no pages")
  iv(page, :graphic).instance_variable_set(:@character_name, bin(spec['graphic'])) if spec['graphic']
  ivs(page, list: spec_commands(spec)) if spec['talk'] || spec['commands']
  e
end

# ---- write pipeline -------------------------------------------------------
def fingerprint(map)
  evs = iv(map, :events).to_h { |k, e| [k, canon(e)] }
  rest = map.instance_variables.reject { |n| n == :@events }.sort.to_h { |n| [n, canon(map.instance_variable_get(n))] }
  [evs, rest]
end

# The first backup is MapNNN.rxdata.bak and is never overwritten; later edits use .bak.1, .bak.2, ...
def next_backup(path)
  return "#{path}.bak" unless File.exist?("#{path}.bak")
  n = 1
  n += 1 while File.exist?("#{path}.bak.#{n}")
  "#{path}.bak.#{n}"
end

# touched: event ids allowed to differ from before_fp. Restores .bak on any mismatch.
def safe_write(path, map, before_fp, touched, scratch)
  gate!(path, scratch)
  had = File.exist?(path)
  bak = next_backup(path)
  FileUtils.cp(path, bak) if had
  tmp = "#{path}.tmp"
  File.binwrite(tmp, Marshal.dump(map))
  File.rename(tmp, path)
  problems = []
  begin
    again = marshal_load(File.binread(path))
    ev_before, rest_before = before_fp
    ev_after, rest_after = fingerprint(again)
    problems << 'reload differs from the object written' unless canon(again) == canon(map)
    problems << 'non-event map data changed' unless rest_before == rest_after
    (ev_before.keys | ev_after.keys).each do |id|
      next if touched.include?(id)
      problems << "untouched event #{id} changed" unless ev_before[id] == ev_after[id]
    end
  rescue StandardError => e
    problems << "reload failed: #{e.class}: #{e.message[0, 120]}"
  end
  unless problems.empty?
    had ? FileUtils.cp(bak, path) : File.delete(path)
    fail!("verify failed, restored #{had ? '.bak' : 'nothing (new file removed)'}: #{problems.join('; ')}", 3)
  end
  puts "OK wrote #{path} (backup: #{had ? bak : 'none, new file'}); reload verified; untouched events identical"
end

def event_summary(e)
  "event #{iv(e, :id)} #{txt(iv(e, :name)).inspect} at (#{iv(e, :x)},#{iv(e, :y)})"
end

def occupied_by(map, x, y, except = nil)
  iv(map, :events).values.find { |e| iv(e, :x) == x && iv(e, :y) == y && iv(e, :id) != except }
end

def check_bounds!(map, x, y)
  w = iv(map, :width)
  h = iv(map, :height)
  ok = x.is_a?(Integer) && y.is_a?(Integer) && x.between?(0, w - 1) && y.between?(0, h - 1)
  fail!("(#{x.inspect},#{y.inspect}) is outside the #{w}x#{h} map") unless ok
end

# ---- commands -------------------------------------------------------------
def cmd_dump(path, o)
  map = load_map(path)
  evs = iv(map, :events).sort.map { |_, e| jsonify(e) }
  doc = { 'file' => File.basename(path), 'width' => iv(map, :width), 'height' => iv(map, :height), 'events' => evs }
  out = JSON.pretty_generate(doc)
  if o[:out]
    File.binwrite(o[:out], out)
  else
    $stdout.binmode
    $stdout.write(out + "\n")
  end
end

# An auto-picked id may reuse one deleted earlier (seen in any backup); things that refer to it by id would misfire.
def warn_reused_id(path, id)
  hit = Dir.glob("#{path}.bak*").sort.find do |b|
    marshal_load(File.binread(b)).then { |m| iv(m, :events)&.key?(id) }
  rescue StandardError
    false
  end
  return unless hit
  warn "WARNING: id #{id} existed in #{hit} (deleted earlier?); pin a fresh id with \"id\" in the spec if anything refers to it."
end

def cmd_add(path, o)
  fail!('add needs --spec FILE.json') unless o[:spec]
  raw = JSON.parse(File.read(o[:spec], encoding: 'UTF-8'))
  specs = raw.is_a?(Array) ? raw : [raw]
  fail!('spec list is empty') if specs.empty?
  map = load_map(path)
  events = iv(map, :events)
  taken = {}
  events.each_value { |e| taken[[iv(e, :x), iv(e, :y)]] = e }
  added = []
  specs.each do |spec|
    fail!('each spec must be an object') unless spec.is_a?(Hash)
    id = spec['id'] || (events.keys.max.to_i + 1)
    warn_reused_id(path, id) unless spec['id']
    fail!("event id #{id} already exists") if events.key?(id)
    check_bounds!(map, spec['x'], spec['y'])
    if (other = taken[[spec['x'], spec['y']]]) && !o[:overlap]
      fail!("tile is taken by #{event_summary(other)} (use --allow-overlap to stack)")
    end
    src = nil
    if spec['clone_from']
      src = events[spec['clone_from']] or fail!("clone_from #{spec['clone_from']} not found")
      fail!("clone_from event #{spec['clone_from']} has no pages") if iv(src, :pages).nil? || iv(src, :pages).empty?
    end
    events[id] = src ? clone_event(src, id, spec) : build_talk_event(id, spec)
    taken[[spec['x'], spec['y']]] = events[id]
    added << id
  end
  if o[:dry]
    added.each { |id| puts "DRY RUN would add #{event_summary(events[id])}" }
    return
  end
  # The in-memory map is already edited. Fingerprint the file still on disk.
  before = fingerprint(load_map(path))
  safe_write(o[:out] || path, map, before, added, o[:scratch])
  added.each { |id| puts "added #{event_summary(events[id])}" }
end

# Autonomous movement on the first page. Type 1 is random. Speed 3 is Slow, frequency 4 is High.
def cmd_set_move(path, o)
  gate!(path, o[:scratch])
  ids = o[:ids]
  ids = [o[:id]] if (ids.nil? || ids.empty?) && o[:id]
  fail!('set-move needs --id N') unless ids && !ids.empty?
  fail!('set-move needs --move-type, --move-speed, or --move-frequency') unless o[:move_type] || o[:move_speed] || o[:move_frequency]
  if o[:move_type] && !o[:move_type].between?(0, 3)
    fail!("move type #{o[:move_type]} is outside 0..3")
  end
  if o[:move_speed] && !o[:move_speed].between?(1, 6)
    fail!("move speed #{o[:move_speed]} is outside 1..6")
  end
  if o[:move_frequency] && !o[:move_frequency].between?(1, 6)
    fail!("move frequency #{o[:move_frequency]} is outside 1..6")
  end
  map = load_map(path)
  events = iv(map, :events)
  ids.each do |id|
    e = events[id] or fail!("no event #{id}")
    iv(e, :pages)&.first or fail!("event #{id} has no pages")
  end
  before = fingerprint(map)
  ids.each do |id|
    page = iv(events[id], :pages).first
    h = {}
    h[:move_type] = o[:move_type] if o[:move_type]
    h[:move_speed] = o[:move_speed] if o[:move_speed]
    h[:move_frequency] = o[:move_frequency] if o[:move_frequency]
    ivs(page, h)
    puts "set-move #{event_summary(events[id])} type=#{iv(page, :move_type)} speed=#{iv(page, :move_speed)} freq=#{iv(page, :move_frequency)}"
  end
  safe_write(o[:out] || path, map, before, ids, o[:scratch])
end

# Change an existing event in place. Keeps its id, tile, direction, and any command
# that is not listed in drop_text. talk prepends pbDesertSpeaker / pbDesertTalk.
# graphic is applied to every page. page limits talk / insert_before_end to one page.
def apply_retarget(e, ed)
  ivs(e, name: bin(ed['name'])) if ed['name']
  pages = iv(e, :pages)
  fail!("event #{iv(e, :id)} has no pages") if pages.nil? || pages.empty?
  pages.each_with_index do |page, i|
    if ed['graphic']
      graphic = iv(page, :graphic) or fail!("event #{iv(e, :id)} page #{i} has no graphic")
      graphic.instance_variable_set(:@character_name, bin(ed['graphic']))
    end
    next unless ed['talk'] || ed['insert_before_end']
    next if ed.key?('page') && i != ed['page']
    list = iv(page, :list) || []
    if ed['talk']
      cid = ed['talk'].to_s
      fail!("talk must be a hex character id, got #{cid.inspect}") unless cid.match?(/\A\h+\z/)
      drop = Array(ed['drop_text']).map { |s| s.to_s }
      kept = list.reject do |c|
        params = iv(c, :parameters) || []
        iv(c, :code) == 101 && params[0] && drop.include?(txt(params[0]))
      end
      kept = kept[0...-1] if kept.last && iv(kept.last, :code) == 0
      new_list = [
        cmd(355, [bin(%(pbDesertSpeaker("#{cid}")))]),
        cmd(355, [bin(%(pbDesertTalk("#{cid}")))])
      ]
      new_list.concat(kept)
      new_list << cmd(0, [])
      ivs(page, list: new_list)
    else
      body = list.dup
      body.pop if body.last && iv(body.last, :code) == 0
      ed['insert_before_end'].each do |c|
        fail!('each insert_before_end command needs a code') unless c.is_a?(Hash) && c['code'].is_a?(Integer)
        params = (c['parameters'] || []).map { |p| p.is_a?(String) ? bin(p) : p }
        body << cmd(c['code'], params, c['indent'] || 0)
      end
      body << cmd(0, [])
      ivs(page, list: body)
    end
  end
end

def cmd_retarget(path, o)
  fail!('retarget needs --spec FILE.json') unless o[:spec]
  spec = JSON.parse(File.read(o[:spec], encoding: 'UTF-8'))
  edits = spec['events']
  fail!('retarget spec needs an "events" list') unless edits.is_a?(Array) && !edits.empty?
  map = load_map(path)
  events = iv(map, :events)
  ids = edits.map do |ed|
    fail!('each retarget event needs an id') unless ed.is_a?(Hash) && ed['id'].is_a?(Integer)
    events[ed['id']] or fail!("no event #{ed['id']}")
    ed['id']
  end
  fail!("retarget ids repeat: #{ids.inspect}") unless ids.uniq.size == ids.size
  before = fingerprint(map)
  edits.each { |ed| apply_retarget(events[ed['id']], ed) }
  if o[:dry]
    edits.each { |ed| puts "DRY RUN would retarget #{event_summary(events[ed['id']])}" }
    return
  end
  safe_write(o[:out] || path, map, before, ids, o[:scratch])
  edits.each { |ed| puts "retargeted #{event_summary(events[ed['id']])}" }
end

def cmd_move(path, o)
  fail!('move needs --id N --x X --y Y') unless o[:id] && o[:x] && o[:y]
  map = load_map(path)
  e = iv(map, :events)[o[:id]] or fail!("no event #{o[:id]}")
  check_bounds!(map, o[:x], o[:y])
  if (other = occupied_by(map, o[:x], o[:y], o[:id])) && !o[:overlap]
    fail!("tile is taken by #{event_summary(other)} (use --allow-overlap)")
  end
  before = fingerprint(map)
  ivs(e, x: o[:x], y: o[:y])
  safe_write(o[:out] || path, map, before, [o[:id]], o[:scratch])
  puts "moved #{event_summary(e)}"
end

def cmd_delete(path, o)
  fail!('delete needs --id N') unless o[:id]
  map = load_map(path)
  e = iv(map, :events)[o[:id]] or fail!("no event #{o[:id]}")
  before = fingerprint(map)
  iv(map, :events).delete(o[:id])
  safe_write(o[:out] || path, map, before, [o[:id]], o[:scratch])
  puts "deleted #{event_summary(e)}"
end

# Read-only: load, dump, reload, compare. Never writes the input.
def cmd_verify(path, _o)
  fail!("not found: #{path}") unless File.file?(path)
  src = File.binread(path)
  a = begin
    marshal_load(src)
  rescue StandardError => e
    fail!("cannot read #{path}: #{e.class}: #{e.message[0, 100]}")
  end
  out = Marshal.dump(a)
  b = marshal_load(out)
  verdict = if out == src then 'BYTE_EXACT'
            elsif canon(a) == canon(b) then 'SEMANTIC_EQUAL'
            else 'MISMATCH' end
  puts "#{File.basename(path)}\t#{verdict}\tevents=#{iv(a, :events)&.size}"
  exit 3 if verdict == 'MISMATCH'
end

o = {}
sub = ARGV.shift
OptionParser.new do |op|
  op.on('--spec F') { |v| o[:spec] = v }
  op.on('--id N', Integer) { |v| (o[:ids] ||= []) << v; o[:id] = v }
  op.on('--x N', Integer) { |v| o[:x] = v }
  op.on('--y N', Integer) { |v| o[:y] = v }
  op.on('--move-type N', Integer) { |v| o[:move_type] = v }
  op.on('--move-speed N', Integer) { |v| o[:move_speed] = v }
  op.on('--move-frequency N', Integer) { |v| o[:move_frequency] = v }
  op.on('--out F') { |v| o[:out] = v }
  op.on('--dry-run') { o[:dry] = true }
  op.on('--allow-overlap') { o[:overlap] = true }
  op.on('--scratch-copy') { o[:scratch] = true }
end.parse!(ARGV)
path = ARGV.shift or fail!('usage: rxdata_io.rb <dump|add|move|set-move|retarget|delete|verify> MAP.rxdata [options]')
cmds = { 'dump' => :cmd_dump, 'add' => :cmd_add, 'move' => :cmd_move, 'set-move' => :cmd_set_move, 'retarget' => :cmd_retarget, 'delete' => :cmd_delete, 'verify' => :cmd_verify }
fail!("unknown command #{sub.inspect}") unless cmds[sub]
send(cmds[sub], path, o)
