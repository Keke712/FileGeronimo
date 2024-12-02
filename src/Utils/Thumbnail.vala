public class Thumbnail : Object {
    private const int THUMBNAIL_SIZE = 128;
    private static AsyncQueue<ThumbnailRequest?>? request_queue = null;
    private static Thread<void>? worker_thread = null;
    private static bool worker_running = false;
    private static bool is_initialized = false;

    public delegate void ThumbnailCallback(Gdk.Texture? texture);

    public static void init() {
        if (is_initialized) return;
        
        request_queue = new AsyncQueue<ThumbnailRequest?>();
        worker_running = true;
        
        worker_thread = new Thread<void>("thumbnail-worker", () => {
            while (worker_running) {
                var request = request_queue.pop();
                if (request != null) {
                    process_thumbnail_request(request);
                }
            }
        });
        is_initialized = true;

    }

    public static void request_thumbnail(string file_path, owned ThumbnailCallback callback) {
        // Initialiser si ce n'est pas déjà fait
        if (!is_initialized) {
            init();
        }

        if (request_queue == null) {
            warning("Thumbnail system not initialized");
            callback(null);
            return;
        }

        if (!is_image_file(file_path)) {
            callback(null);
            return;
        }

        // Vérifier d'abord le cache
        var cache = ThumbnailCache.get_instance();
        var cached_texture = cache.get_texture(file_path);
        if (cached_texture != null) {
            callback(cached_texture);
            return;
        }

        // Ajouter la requête à la file d'attente de manière sécurisée
        var request = new ThumbnailRequest(file_path, (owned)callback);
        request_queue.push(request);
    }

    private static void process_thumbnail_request(ThumbnailRequest request) {
        if (!FileUtils.test(request.file_path, FileTest.EXISTS)) {
            Idle.add(() => {
                request.callback(null);
                return false;
            });
            return;
        }

        try {
            var file = File.new_for_path(request.file_path);
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

            var pixbuf = new Gdk.Pixbuf.from_file_at_scale(request.file_path, new_width, new_height, true);
            var scaled_texture = Gdk.Texture.for_pixbuf(pixbuf);

            // Mettre en cache
            var cache = ThumbnailCache.get_instance();
            cache.set_texture(request.file_path, scaled_texture);

            // Retourner sur le thread principal pour le callback
            Idle.add(() => {
                request.callback(scaled_texture);
                return false;
            });
        } catch (Error e) {
            Idle.add(() => {
                request.callback(null);
                return false;
            });
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

    public static void cleanup() {
        if (is_initialized && worker_running && request_queue != null) {
            worker_running = false;
            
            // Créer une requête vide pour réveiller le thread au lieu de pousser null
            var empty_request = new ThumbnailRequest("", (texture) => {});
            request_queue.push(empty_request);

            if (worker_thread != null) {
                worker_thread.join();
            }

            request_queue = null;
            worker_thread = null;
            is_initialized = false;
        }
    }
}

private class ThumbnailRequest {
    public string file_path;
    public Thumbnail.ThumbnailCallback callback;

    public ThumbnailRequest(string path, owned Thumbnail.ThumbnailCallback cb) {
        file_path = path;
        callback = (owned)cb;
    }
}