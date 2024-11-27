public class ThumbnailCache : Object {
    private static ThumbnailCache? instance;
    private HashTable<string, Gdk.Texture> cache;
    private const uint MAX_CACHE_SIZE = 100;

    public static ThumbnailCache get_instance() {
        if (instance == null) {
            instance = new ThumbnailCache();
        }
        return instance;
    }

    private ThumbnailCache() {
        cache = new HashTable<string, Gdk.Texture>(str_hash, str_equal);
    }

    public Gdk.Texture? get_texture(string path) {
        return cache.get(path);
    }

    public void set_texture(string path, Gdk.Texture texture) {
        // Si le cache est plein, on supprime une entrée au hasard
        if (cache.size() >= MAX_CACHE_SIZE) {
            string? key_to_remove = null;
            cache.foreach((key, value) => {
                if (key_to_remove == null) key_to_remove = key;
            });
            if (key_to_remove != null) {
                cache.remove(key_to_remove);
            }
        }
        cache.insert(path, texture);
    }

    public void clear() {
        cache.remove_all();
    }
}
