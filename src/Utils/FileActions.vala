public class FileActions : Object {
    public List<FileObject>? list_files(string path) {
        // Créer deux listes séparées pour les dossiers et les fichiers
        List<FileObject> folders = new List<FileObject>();
        List<FileObject> files = new List<FileObject>();

        try {
            var directory = File.new_for_path(path);
            var enumerator = directory.enumerate_children(
                FileAttribute.STANDARD_NAME + "," + 
                FileAttribute.STANDARD_TYPE + "," + 
                FileAttribute.STANDARD_CONTENT_TYPE + "," +
                FileAttribute.TIME_MODIFIED,
                FileQueryInfoFlags.NONE
            );
            
            FileInfo file_info;
            while ((file_info = enumerator.next_file()) != null) {
                var iterator_file = new FileObject();

                // File name (skip hidden files)
                string? name = file_info.get_name();
                if (name == null || name.has_prefix(".")) continue;

                iterator_file.name = name;

                // Check if it's a directory or file
                var file_type = file_info.get_file_type();
                iterator_file.is_folder = (file_type == FileType.DIRECTORY);

                // Get modification date
                var mod_datetime = file_info.get_modification_date_time();
                iterator_file.date = mod_datetime ?? new DateTime.now_local();

                // Ajouter à la liste appropriée
                if (iterator_file.is_folder) {
                    folders.append(iterator_file);
                } else {
                    files.append(iterator_file);
                }
            }

            // Trier chaque liste par nom
            folders.sort((a, b) => {
                return strcmp(a.name.down(), b.name.down());
            });
            files.sort((a, b) => {
                return strcmp(a.name.down(), b.name.down());
            });

            // Combiner les listes : dossiers d'abord, puis fichiers
            List<FileObject> combined = new List<FileObject>();
            foreach (var folder in folders) {
                combined.append(folder);
            }
            foreach (var file in files) {
                combined.append(file);
            }

            return combined;

        } catch (Error e) {
            print("Error listing directory %s: %s\n", path, e.message);
            return null;
        }
    }
}