public class FileMonitor : Object {
    private static FileMonitor? instance;
    private HashTable<string, GLib.FileMonitor> monitors;
    private HashTable<string, List<FileExplorer>> watchers;
    
    public static FileMonitor get_instance() {
        if (instance == null) {
            instance = new FileMonitor();
        }
        return instance;
    }
    
    private FileMonitor() {
        monitors = new HashTable<string, GLib.FileMonitor>(str_hash, str_equal);
        watchers = new HashTable<string, List<FileExplorer>>(str_hash, str_equal);
    }
    
    public void watch_directory(string path, FileExplorer explorer) {
        if (!watchers.contains(path)) {
            watchers.set(path, new List<FileExplorer>());
            setup_monitor(path);
            
            // Surveiller également le répertoire parent
            string parent_path = Path.get_dirname(path);
            if (parent_path != path) {
                setup_monitor(parent_path);
            }
        }
        
        unowned List<FileExplorer> list = watchers.get(path);
        bool explorer_exists = false;
        foreach (var existing in list) {
            if (existing == explorer) {
                explorer_exists = true;
                break;
            }
        }
        if (!explorer_exists) {
            list.append(explorer);
        }
    }
    
    public void unwatch_directory(string path, FileExplorer explorer) {
        if (watchers.contains(path)) {
            unowned List<FileExplorer> list = watchers.get(path);
            list.remove(explorer);
            
            if (list.length() == 0) {
                watchers.remove(path);
                if (monitors.contains(path)) {
                    monitors.get(path).cancel();
                    monitors.remove(path);
                }
            }
        }
    }
    
    private void setup_monitor(string path) {
        try {
            if (monitors.contains(path)) return;

            var file = File.new_for_path(path);
            var monitor = file.monitor_directory(FileMonitorFlags.WATCH_MOVES | FileMonitorFlags.WATCH_MOUNTS);
            
            monitor.changed.connect((file, other_file, event_type) => {
                if (event_type == FileMonitorEvent.CREATED || 
                    event_type == FileMonitorEvent.DELETED ||
                    event_type == FileMonitorEvent.MOVED_IN ||
                    event_type == FileMonitorEvent.MOVED_OUT ||
                    event_type == FileMonitorEvent.RENAMED) {
                    
                    // Obtenir tous les chemins concernés
                    string[] paths_to_notify = {};
                    paths_to_notify += path;

                    // Ajouter le chemin du fichier source
                    if (file != null) {
                        string? file_path = file.get_path();
                        if (file_path != null) {
                            paths_to_notify += Path.get_dirname(file_path);
                        }
                    }

                    // Ajouter le chemin du fichier de destination
                    if (other_file != null) {
                        string? other_path = other_file.get_path();
                        if (other_path != null) {
                            paths_to_notify += Path.get_dirname(other_path);
                        }
                    }

                    // Notifier pour chaque chemin unique
                    var notified_paths = new HashTable<string, bool>(str_hash, str_equal);
                    foreach (string p in paths_to_notify) {
                        if (!notified_paths.contains(p)) {
                            notify_affected_explorers(p);
                            notified_paths.set(p, true);
                        }
                    }
                }
            });
            
            monitors.set(path, monitor);
        } catch (Error e) {
            warning("Failed to set up directory monitor for %s: %s", path, e.message);
        }
    }

    private void notify_affected_explorers(string path) {
        // Notifier le dossier actuel et tous ses parents
        string current_path = path;
        while (current_path != "/" && current_path != "") {
            if (watchers.contains(current_path)) {
                unowned List<FileExplorer> list = watchers.get(current_path);
                foreach (var explorer in list) {
                    Idle.add(() => {
                        explorer._directory(explorer.current_directory.text);
                        return false;
                    });
                }
            }
            string parent = Path.get_dirname(current_path);
            if (parent == current_path) break;
            current_path = parent;
        }
    }
}