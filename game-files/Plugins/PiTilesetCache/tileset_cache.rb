#===============================================================================
# TG69: Persistent tileset bitmap cache
#===============================================================================
# On the Pi 4, decoding a tileset PNG takes 250-400 ms. When the player walks
# between connected maps the same tilesets are loaded and disposed repeatedly.
# This plugin keeps the decoded (and TilesetWrapper-wrapped) bitmap alive after
# TilesetBitmaps#remove so the next add() for the same filename is instant.
#
# Memory: each cached tileset keeps ~2-8 MB in GPU VRAM. The cache is capped
# at MAX_CACHED entries; the oldest-unused entry is evicted when full.
#===============================================================================
class TilemapRenderer::TilesetBitmaps
  MAX_CACHED = 8

  @@_ts_bitmaps = {}   # filename => Bitmap (the wrapped/ready version)
  @@_ts_wraps   = {}   # filename => bool   (mega-texture flag)
  @@_ts_order   = []   # filenames in LRU order (most recent at the end)

  #-----------------------------------------------------------------------------
  # Override add: check the persistent cache before hitting the disk.
  #-----------------------------------------------------------------------------
  alias _ts_cache_add add
  def add(filename)
    return if nil_or_empty?(filename)
    if @bitmaps[filename]
      @load_counts[filename] += 1
      return
    end
    cached = @@_ts_bitmaps[filename]
    if cached && !cached.disposed?
      @bitmaps[filename]      = cached
      @bitmap_wraps[filename] = @@_ts_wraps.fetch(filename, false)
      @load_counts[filename]  = 1
      @changed = true
      _ts_touch(filename)
      return
    end
    # Cache miss — load from disk (expensive).
    bitmap = pbGetTileset(filename)
    @bitmap_wraps[filename] = false
    if bitmap.mega?
      self[filename] = TilemapRenderer::TilesetWrapper.wrapTileset(bitmap)
      @bitmap_wraps[filename] = true
      bitmap.dispose
    else
      self[filename] = bitmap
    end
    @load_counts[filename] = 1
    _ts_store(filename, @bitmaps[filename], @bitmap_wraps[filename])
  end

  #-----------------------------------------------------------------------------
  # Override remove: keep the bitmap alive in the persistent cache.
  #-----------------------------------------------------------------------------
  alias _ts_cache_remove remove
  def remove(filename)
    return if nil_or_empty?(filename) || !@bitmaps[filename]
    if @load_counts[filename] && @load_counts[filename] > 1
      @load_counts[filename] -= 1
      return
    end
    # Detach from this TilesetBitmaps instance but do NOT dispose.
    @bitmaps.delete(filename)
    @bitmap_wraps.delete(filename)
    @load_counts.delete(filename)
  end

  private

  def _ts_store(filename, bmp, is_wrap)
    # Protect the bitmap from any external dispose call.
    unless bmp.respond_to?(:_ts_cached?)
      bmp.define_singleton_method(:_ts_cached?) { true }
      bmp.define_singleton_method(:dispose)     { }
      bmp.define_singleton_method(:disposed?)   { false }
    end
    @@_ts_bitmaps[filename] = bmp
    @@_ts_wraps[filename]   = is_wrap
    _ts_touch(filename)
    _ts_evict
  end

  def _ts_touch(filename)
    @@_ts_order.delete(filename)
    @@_ts_order.push(filename)
  end

  def _ts_evict
    while @@_ts_order.length > MAX_CACHED
      old = @@_ts_order.shift
      bmp = @@_ts_bitmaps.delete(old)
      @@_ts_wraps.delete(old)
      next unless bmp
      # Restore real dispose before freeing.
      bmp.define_singleton_method(:dispose)   { super() }
      bmp.define_singleton_method(:disposed?) { super() }
      bmp.dispose
    end
  end
end
