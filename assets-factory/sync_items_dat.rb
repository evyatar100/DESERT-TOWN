# Upserts PBS/items.txt sections into Data/items.dat without launching the game.
# Each listed item is built from the ICEBAG record (same class and ivars), then the
# file is reloaded and every other item is checked unchanged.
#   ruby assets-factory/sync_items_dat.rb SURPRISEBAG BAGOFBAGS DESERTBAG [--backup FILE]
require 'fileutils'

GAME = File.expand_path('../game-files', __dir__)
PBS = File.join(GAME, 'PBS/items.txt')
DAT = File.join(GAME, 'Data/items.dat')
FIELD_USE = { 'OnPokemon' => 1, 'Direct' => 2, 'TM' => 3, 'HM' => 4, 'TR' => 5 }.freeze

def define_path(path)
  parent = Object
  path.split('::').each do |part|
    parent = parent.const_defined?(part, false) ? parent.const_get(part, false) : parent.const_set(part, Class.new)
  end
end

def marshal_load(bytes)
  Marshal.load(bytes)
rescue ArgumentError => e
  m = e.message.match(%r{undefined class/module ([\w:]+)}) or raise
  define_path(m[1])
  retry
end

def pbs_sections(path)
  sections = {}
  current = nil
  File.read(path, encoding: 'bom|utf-8').each_line do |line|
    line = line.strip
    next if line.empty? || line.start_with?('#')
    if (m = line.match(/\A\[([A-Z0-9_]+)\]\z/))
      current = sections[m[1]] = {}
    elsif current && (m = line.match(/\A(\w+)\s*=\s*(.*)\z/))
      current[m[1]] = m[2]
    end
  end
  sections
end

def utf8(s) = s.dup.force_encoding(Encoding::UTF_8)

def build(template, id, f)
  item = Marshal.load(Marshal.dump(template))
  price = f.fetch('Price', '0').to_i
  {
    id: id.to_sym, real_name: utf8(f.fetch('Name')), real_name_plural: utf8(f.fetch('NamePlural')),
    pocket: f.fetch('Pocket').to_i, price: price, sell_price: price / 2,
    field_use: FIELD_USE.fetch(f['FieldUse'], 0), flags: f.fetch('Flags', '').split(',').map(&:strip),
    show_quantity: f['ShowQuantity'] == 'true' ? true : nil, real_description: utf8(f.fetch('Description', ''))
  }.each { |k, v| item.instance_variable_set("@#{k}", v) }
  item
end

ids = ARGV.take_while { |a| !a.start_with?('--') }
backup = ARGV[ARGV.index('--backup') + 1] if ARGV.include?('--backup')
abort 'usage: sync_items_dat.rb ID [ID ...] [--backup FILE]' if ids.empty?
sections = pbs_sections(PBS)
src = File.binread(DAT)
items = marshal_load(src)
template = items[:ICEBAG] or abort 'ICEBAG missing from items.dat'
before = items.reject { |k, _| ids.include?(k.to_s) }.transform_values { |v| Marshal.dump(v) }
ids.each do |id|
  f = sections[id] or abort "[#{id}] not in PBS/items.txt"
  items[id.to_sym] = build(template, id, f)
end
FileUtils.cp(DAT, backup) if backup
File.binwrite("#{DAT}.tmp", Marshal.dump(items))
again = marshal_load(File.binread("#{DAT}.tmp"))
same = before.all? { |k, v| again[k] && Marshal.dump(again[k]) == v }
abort "verify failed: other items changed; #{DAT} untouched" unless same && ids.all? { |i| again[i.to_sym] }
File.rename("#{DAT}.tmp", DAT)
ids.each { |i| o = again[i.to_sym]; puts "#{i}: #{o.instance_variable_get(:@real_name)} field_use=#{o.instance_variable_get(:@field_use)} flags=#{o.instance_variable_get(:@flags)}" }
puts "OK #{DAT}: #{again.size} items, all others unchanged"
