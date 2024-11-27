public class Thumbnail : Object {
    private const int THUMBNAIL_SIZE = 128;

    public static Gdk.Texture? create_thumbnail(string file_path) {
        if (!is_image_file(file_path)) {
            return null;
        }

        // Vérifier d'abord le cache
        var cache = ThumbnailCache.get_instance();
        var cached_texture = cache.get_texture(file_path);
        if (cached_texture != null) {
            return cached_texture;
        }

        // Si le fichier n'existe pas, retourner null directement
        if (!FileUtils.test(file_path, FileTest.EXISTS)) {
            return null;
        }

        try {
            var file = File.new_for_path(file_path);
            var texture = Gdk.Texture.from_file(file);
            
            // Calculate new dimensions maintaining aspect ratio
            int orig_width = texture.width;
            int orig_height = texture.height;
            int new_width, new_height;
            
            if (orig_width > orig_height) {
                new_width = THUMBNAIL_SIZE;
                new_height = (int)((double)orig_height / orig_width * THUMBNAIL_SIZE);
            } else {
                new_height = THUMBNAIL_SIZE;
                new_width = (int)((double)orig_width / orig_height * THUMBNAIL_SIZE);
            }

            // Create scaled texture
            var pixbuf = new Gdk.Pixbuf.from_file_at_scale(file_path, new_width, new_height, true);
            Gdk.Texture scaled_texture = Gdk.Texture.for_pixbuf(pixbuf);

            // Ajouter au cache avant de retourner
            cache.set_texture(file_path, scaled_texture);
            return scaled_texture;
        } catch (Error e) {
            print("Error creating thumbnail for %s: %s\n", file_path, e.message);
            return null;
        }
    }

    private static bool is_image_file(string file_path) {
        string lower_path = file_path.down();
        return lower_path.has_suffix(".jpg") || 
               lower_path.has_suffix(".jpeg") || 
               lower_path.has_suffix(".png") || 
               lower_path.has_suffix(".gif") || 
               lower_path.has_suffix(".webp");
    }
}