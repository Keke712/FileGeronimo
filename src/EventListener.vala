public class EventListener : Object {
    private FileExplorer explorer;
    private bool ctrl_pressed = false;
    private bool c_pressed = false;
    private bool v_pressed = false;
    private bool x_pressed = false;

    public EventListener(FileExplorer explorer) {
        this.explorer = explorer;
    }

    public void handle_key_released(uint keyval) {
        if (keyval == 65293) { // Enter key
            string entered_path = explorer.current_directory.get_text();
            
            // Try to find a matching path
            string? completed_path = explorer.find_matching_path(entered_path);
            
            if (completed_path != null) {
                try {
                    var file = File.new_for_path(completed_path);
                    if (file.query_exists()) {
                        FileInfo info = file.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                        if (info.get_file_type() == FileType.DIRECTORY) {
                            explorer.navigate_to(completed_path);
                            return;
                        }
                    }
                } catch (Error e) {
                    print("Error checking path: %s\n", e.message);
                }
            }
            
            // If we get here, either no match was found or it wasn't a directory
            // Try to navigate to the entered path as a fallback
            if (FileUtils.test(entered_path, FileTest.IS_DIR)) {
                explorer.navigate_to(entered_path);
            }
        } else if (keyval == 65289) { // Tab key
            handle_tab_completion();
        } else if (keyval == 65507) { // Control key
            ctrl_pressed = false;
        } else if (keyval == 99) { // C key
            c_pressed = false;
        } else if (keyval == 118) { // V key
            v_pressed = false;
        } else if (keyval == 120) { // X key
            x_pressed = false;
        }
    }

    public void handle_key_pressed(uint keyval) {
        if (keyval == 65507) { // Control key
            ctrl_pressed = true;
        } else if (keyval == 99) { // C key
            c_pressed = true;
        } else if (keyval == 118) { // V key
            v_pressed = true;
        } else if (keyval == 120) { // X key
            x_pressed = true;
        }

        if (ctrl_pressed && c_pressed) {
            print("CTRL + C pressed\n");
        } else if (ctrl_pressed && v_pressed) {
            print("CTRL + V pressed\n");
        } else if (ctrl_pressed && x_pressed) {
            print("CTRL + X pressed\n");
        } else if (keyval == 65535) { // Delete key
            move_selected_to_trash();
        }
    }

    private void move_selected_to_trash() {
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
                    file.trash();
                    explorer.action_history.add_action(new FileAction(
                        FileAction.ActionType.DELETE,
                        file_path,
                        ""
                    ));
                } catch (Error e) {
                    print("Error moving file to trash: %s\n", e.message);
                }
            }
        }
        explorer.refresh_current_directory();
    }

    private void handle_tab_completion() {
        string current_text = explorer.current_directory.text;
        
        // Get the directory and partial name to complete
        string directory;
        string partial_name;
        
        if (Path.is_absolute(current_text)) {
            directory = Path.get_dirname(current_text);
            partial_name = Path.get_basename(current_text);
        } else {
            directory = explorer.current_directory.text;
            partial_name = "";
        }
        
        // List all entries in the directory
        try {
            var dir = Dir.open(directory);
            string? name = null;
            string? match = null;
            
            while ((name = dir.read_name()) != null) {
                // Skip hidden files
                if (name.has_prefix(".")) {
                    continue;
                }
                
                // If the name starts with our partial text
                if (name.down().has_prefix(partial_name.down())) {
                    // If we haven't found a match yet, or this one is "better"
                    if (match == null) {
                        match = name;
                    }
                }
            }
            
            // If we found a match, use it
            if (match != null) {
                string new_path;
                if (Path.is_absolute(current_text)) {
                    new_path = Path.build_filename(directory, match);
                } else {
                    new_path = match;
                }
                
                // If it's a directory, add a trailing slash
                string full_path = Path.build_filename(directory, match);
                if (FileUtils.test(full_path, FileTest.IS_DIR)) {
                    new_path += "/";
                }
                
                explorer.current_directory.text = new_path;
                explorer.current_directory.set_position(-1); // Place cursor at end
            }
        } catch (Error e) {
            print("Error during tab completion: %s\n", e.message);
        }
    }
}