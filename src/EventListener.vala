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
                    explorer.show_error_dialog("Error checking path: %s".printf(e.message));
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
        } else if (keyval == 65471) { // F2 key
            print("F2 pressed\n");
        }

        if (ctrl_pressed && c_pressed) {
            explorer.factions.copy_selected_files(explorer);
        } else if (ctrl_pressed && v_pressed) {
            handle_paste();
        } else if (ctrl_pressed && x_pressed) {
            cut_selected_items_opacity();
        } else if (keyval == 65535) { // Delete key
            explorer.factions.move_selected_to_trash(explorer);
        }
    }

    private void cut_selected_items_opacity() {
        explorer.factions.cut_selected_files(explorer);
    }

    public void handle_paste() {
        explorer.factions.paste_copied_files(explorer);
        // clear_cut_files est maintenant géré dans paste_copied_files
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
            explorer.show_error_dialog("Error during tab completion: %s".printf(e.message));
        }
    }
}