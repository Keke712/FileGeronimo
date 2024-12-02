public class FileActions : Object {
    private List<string> copied_files = new List<string>();
    private List<string> cut_files = new List<string>();
    public signal void cut_files_changed(); // Add signal

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

                // Check if file is in cut list and set opacity
                string full_path = Path.build_filename(path, name);
                iterator_file.opacity = cut_files.find_custom(full_path, strcmp) != null ? 0.5 : 1.0;

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

    public void move_selected_to_trash(FileExplorer explorer) {
        var selection_model = explorer.is_grid_view ? explorer.grid_view.model : explorer.list_view.model as Gtk.MultiSelection;
        if (selection_model == null) return;

        var selected = selection_model.get_selection();
        for (uint i = 0; i < selected.get_size(); i++) {
            uint position = selected.get_nth(i);
            var file_obj = selection_model.get_item(position) as FileObject;
            if (file_obj != null) {
                string file_path = Path.build_filename(explorer.current_directory.text, file_obj.name);
                try {
                    var file = File.new_for_path(file_path);
                    string trash_path = Path.build_filename(GLib.Environment.get_user_data_dir(), "Trash/files", file_obj.name);
                    file.move(File.new_for_path(trash_path), FileCopyFlags.NONE);
                    explorer.action_history.add_action(new FileAction(
                        FileAction.ActionType.MOVE,
                        file_path,
                        trash_path
                    ));
                } catch (Error e) {
                    print("Error moving file to trash: %s\n", e.message);
                }
            }
        }
        explorer.refresh_current_directory();
    }

    public void copy_selected_files(FileExplorer explorer) {
        // Clear copied files
        if (copied_files.is_empty() == false) {
            foreach (unowned string e in copied_files) {
                copied_files.remove(e);
            }
        }
        
        // Get selected files
        var selection_model = explorer.is_grid_view ? explorer.grid_view.model : explorer.list_view.model as Gtk.MultiSelection;
        if (selection_model == null) return;

        var selected = selection_model.get_selection();
        for (uint i = 0; i < selected.get_size(); i++) {
            uint position = selected.get_nth(i);
            var file_obj = selection_model.get_item(position) as FileObject;
            if (file_obj != null) {
                string file_path = Path.build_filename(explorer.current_directory.text, file_obj.name);
                copied_files.append(file_path);
            }
        }

        // Print copied files
        foreach (unowned string e in copied_files) {
            print("Copied file: %s\n", e);
        }
    }

    public void paste_copied_files(FileExplorer explorer) {
        if (copied_files.is_empty() && cut_files.is_empty()) {
            print("No files to paste\n");
            return;
        }

        // Handle cut files first
        if (!cut_files.is_empty()) {
            foreach (var file_path in cut_files) {
                string file_name = Path.get_basename(file_path);
                string destination_path = Path.build_filename(explorer.current_directory.text, file_name);

                try {
                    var source_file = File.new_for_path(file_path);
                    var destination_file = File.new_for_path(destination_path);

                    // Check if source exists
                    if (!source_file.query_exists()) {
                        print("Source file does not exist: %s\n", file_path);
                        continue;
                    }

                    // Check if destination exists
                    if (destination_file.query_exists()) {
                        print("File already exists at destination: %s\n", destination_path);
                        continue;
                    }

                    // Move the file
                    if (source_file.move(destination_file, FileCopyFlags.NONE)) {
                        explorer.action_history.add_action(new FileAction(
                            FileAction.ActionType.MOVE,
                            file_path,
                            destination_path
                        ));
                        print("Moved file: %s to %s\n", file_path, destination_path);
                    }
                } catch (Error e) {
                    print("Error moving file: %s\n", e.message);
                }
            }
            foreach (unowned string e in cut_files) {
                cut_files.remove(e);
            }
            cut_files_changed();
            return;
        }

        // Handle copied files
        foreach (var file_path in copied_files) {
            string file_name = Path.get_basename(file_path);
            string destination_path = Path.build_filename(explorer.current_directory.text, file_name);

            try {
                var source_file = File.new_for_path(file_path);
                var destination_file = File.new_for_path(destination_path);

                // Check if destination exists
                if (destination_file.query_exists()) {
                    print("File already exists at destination: %s\n", destination_path);
                    continue;
                }

                // Copy the file
                source_file.copy(destination_file, FileCopyFlags.NONE, null, null);
                explorer.action_history.add_action(new FileAction(
                    FileAction.ActionType.PASTE,
                    file_path,
                    destination_path
                ));
                print("Copied file: %s to %s\n", file_path, destination_path);
            } catch (Error e) {
                print("Error copying file: %s\n", e.message);
            }
        }

        explorer.refresh_current_directory();
    }

    public void edit_folder_icon(FileExplorer explorer, string folder_path, string new_icon_name) {
        var selection_model = explorer.is_grid_view ? explorer.grid_view.model : explorer.list_view.model as Gtk.MultiSelection;
        if (selection_model == null) return;

        var file_store = selection_model.get_item_type() as GLib.ListStore;
        if (file_store == null) return;

        for (uint i = 0; i < file_store.get_n_items(); i++) {
            var file_obj = file_store.get_item(i) as FileObject;
            if (file_obj != null && file_obj.is_folder && Path.build_filename(explorer.current_directory.text, file_obj.name) == folder_path) {
                // Update the icon name
                file_obj.icon_name = new_icon_name;
                break;
            }
        }

        explorer.refresh_current_directory();
    }

    // Add method to update cut files list
    public void update_cut_files(List<string> files) {
        cut_files = new List<string>();
        foreach (string file in files) {
            cut_files.append(file);
        }
    }

    // Add method to clear cut files
    public void clear_cut_files() {
        cut_files = new List<string>();
        cut_files_changed();
    }

    public bool is_file_cut(string path) {
        return cut_files.find_custom(path, strcmp) != null;
    }

    public void cut_selected_files(FileExplorer explorer) {
        cut_files = new List<string>();
        
        var selection_model = explorer.is_grid_view ? 
            explorer.grid_view.model : 
            explorer.list_view.model as Gtk.MultiSelection;
        
        if (selection_model == null) return;

        var selected = selection_model.get_selection();
        for (uint i = 0; i < selected.get_size(); i++) {
            uint position = selected.get_nth(i);
            var file_obj = selection_model.get_item(position) as FileObject;
            if (file_obj != null) {
                string full_path = Path.build_filename(explorer.current_directory.text, file_obj.name);
                cut_files.append(full_path);
            }
        }
        cut_files_changed();
        explorer.refresh_current_directory();
    }

}