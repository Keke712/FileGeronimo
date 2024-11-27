using GtkLayerShell;
using Gtk;

[GtkTemplate (ui = "/com/github/Keke712/fgeronimo/ui/FileExplorer.ui")]
public class FileExplorer : Gtk.Window, ILayerWindow {
    // Variables
    public string namespace { get; set; }
    private FileActions factions = new FileActions();
    private bool is_grid_view = true; // Affichage par défaut en GridView
    private List<FileObject> dragged_files;

    // GTK Childs
    [GtkChild] private unowned Entry current_directory;
    [GtkChild] private unowned Stack view_stack;      // Ajout du Stack
    [GtkChild] private unowned GridView grid_view;    // GridView pour la vue grille
    [GtkChild] private unowned ListView list_view;    // ListView pour la vue liste
    [GtkChild] private unowned Button back_button;
    [GtkChild] private unowned ListBox important_folders_list;
    [GtkChild] private unowned Button view_mode_button;

    // Construct
    public FileExplorer (Gtk.Application app) {
        Object (application: app);
        
        // Configure GridView
        grid_view.set_enable_rubberband(true);
        grid_view.max_columns = 5;  // Fixed number of columns
        grid_view.min_columns = 1;
        grid_view.single_click_activate = false;  // Désactiver l'activation en simple clic

        // Configure ListView
        list_view.set_enable_rubberband(true);
        list_view.single_click_activate = false;

        // Connecter les signaux d'activation
        grid_view.activate.connect(on_item_activated);
        list_view.activate.connect(on_list_item_activated);

        // Make directory to home_dir at startup
        current_directory.text = Environment.get_home_dir();
        _directory(current_directory.text);

        // Connect signals
        back_button.clicked.connect(go_back);
        important_folders_list.row_selected.connect(on_folder_selected);
        view_mode_button.clicked.connect(toggle_view_mode);
        update_view_mode_button();

        // Set initial view
        view_stack.set_visible_child_name("grid_view");

        // Set up drag sources
        setup_drag_source(grid_view);
        setup_drag_source(list_view);

        // Set up drag destinations
        setup_drag_dest(grid_view);
        setup_drag_dest(list_view);

    }

    // Core Layer Methods
    public void init_layer_properties () {
        GtkLayerShell.init_for_window (this);
        GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);

        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);

        GtkLayerShell.set_namespace (this, "FileExplorer");
        GtkLayerShell.auto_exclusive_zone_enable (this);
    }

    public void present_layer () {
        this.present ();
    }

    [GtkCallback]
    public void key_released(uint keyval) {
        if (keyval == 65293) { // Enter key
            string entered_path = current_directory.get_text();
            
            // Convert to absolute path if relative
            File file = File.new_for_path(entered_path);
            string? absolute_path = null;
            
            try {
                if (!Path.is_absolute(entered_path)) {
                    // Handle relative paths by resolving them against current directory
                    File current = File.new_for_path(current_directory.get_text());
                    File resolved = current.resolve_relative_path(entered_path);
                    absolute_path = resolved.get_path();
                } else {
                    absolute_path = file.get_path();
                }

                // Check if path exists and is a directory
                if (absolute_path != null && FileUtils.test(absolute_path, FileTest.IS_DIR)) {
                    navigate_to(absolute_path);
                }
            } catch (GLib.Error e) {
                print("Error resolving path: %s\n", e.message);
            }
        } else if (keyval == 65289) { // Tab key
            handle_tab_completion();
        }
    }

    private void handle_tab_completion() {
        string current_text = current_directory.text;
        
        // Get the directory and partial name to complete
        string directory;
        string partial_name;
        
        if (Path.is_absolute(current_text)) {
            directory = Path.get_dirname(current_text);
            partial_name = Path.get_basename(current_text);
        } else {
            directory = current_directory.text;
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
                
                current_directory.text = new_path;
                current_directory.set_position(-1); // Place cursor at end
            }
        } catch (Error e) {
            print("Error during tab completion: %s\n", e.message);
        }
    }

    // Navigation Methods
    private void on_item_activated(uint position) {
        var model = grid_view.model as Gtk.MultiSelection;  // Change to MultiSelection
        var file = model.get_item(position) as FileObject;

        if (file != null && file.is_folder) {
            string new_path = Path.build_filename(current_directory.text, file.name);
            navigate_to(new_path);
        }
    }

    // Méthode d'activation pour le ListView avec la signature correcte
    private void on_list_item_activated(ListView list_view, uint position) {
        var model = list_view.model as Gtk.MultiSelection;  // Change to MultiSelection
        var file = model.get_item(position) as FileObject;

        if (file != null && file.is_folder) {
            string new_path = Path.build_filename(current_directory.text, file.name);
            navigate_to(new_path);
        }
    }

    private void navigate_to(string path) {
        if (current_directory.text == path) {
            return;
        }

        current_directory.text = path;
        _directory(path);
        
        // Activer le bouton retour puisqu'on peut maintenant revenir en arrière
        back_button.sensitive = (path != "/");
    }

    private void go_back() {
        string current_path = current_directory.text;
        
        // Si on est à la racine ou que le chemin est invalide, on ne fait rien
        if (current_path == "/" || current_path == "") {
            return;
        }

        // Obtenir le chemin parent
        string parent_path = Path.get_dirname(current_path);
        if (parent_path != current_path) {
            current_directory.text = parent_path;
            _directory(parent_path);
            
            // Activer/désactiver le bouton retour en fonction de si on est à la racine
            back_button.sensitive = (parent_path != "/");
        }
    }

    private void on_folder_selected(ListBoxRow? row) {
        if (row == null) return;
        
        // Get the Box that contains the Image and Label
        var box = row.child as Gtk.Box;
        if (box == null) return;

        // Iterate through box children to find the Label
        var label_widget = box.get_first_child();
        while (label_widget != null) {
            if (label_widget is Gtk.Label) {
                break;
            }
            label_widget = label_widget.get_next_sibling();
        }

        var label = label_widget as Gtk.Label;
        if (label == null) return;

        string folder_name = label.label;
        string? folder_path = null;

        switch (folder_name) {
            case "Home":
                folder_path = GLib.Environment.get_home_dir();
                break;
            case "Documents":
                folder_path = GLib.Environment.get_user_special_dir(GLib.UserDirectory.DOCUMENTS);
                break;
            case "Downloads":
                folder_path = GLib.Environment.get_user_special_dir(GLib.UserDirectory.DOWNLOAD);
                break;
            case "Images":
                folder_path = GLib.Environment.get_user_special_dir(GLib.UserDirectory.PICTURES);
                break;
        }

        if (folder_path != null) {
            navigate_to(folder_path);
        } else {
            print("Folder path not found for %s\n", folder_name);
        }
    }

    private void toggle_view_mode() {
        is_grid_view = !is_grid_view;
        update_view_mode_button();
        // Change how we switch views
        view_stack.set_visible_child_name(is_grid_view ? "grid_view" : "list_view");
        _directory(current_directory.text); // Refresh view
    }

    private void update_view_mode_button() {
        view_mode_button.icon_name = is_grid_view ? "view-list-symbolic" : "view-grid-symbolic";
        view_mode_button.tooltip_text = is_grid_view ? "Passer en vue liste" : "Passer en vue grille";
    }

    // Directory Listing Method
    public void _directory(string path) {
        // Obtenir la liste des fichiers
        var list = factions.list_files(path);

        // Créer le modèle de données
        var file_store = new GLib.ListStore(typeof(FileObject));
        foreach (var file in list) {
            file_store.append(file);
        }

        // Créer le modèle de sélection avec sélection multiple
        var selection_model = new Gtk.MultiSelection(file_store);

        if (is_grid_view) {
            // Configuration pour GridView
            var grid_factory = new Gtk.SignalListItemFactory();

            grid_factory.setup.connect((item) => {
                var list_item = item as Gtk.ListItem;
                var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6) {
                    margin_start = 6,
                    margin_end = 6,
                    width_request = 120,
                    height_request = 120
                };
                
                var icon = new Gtk.Image() {
                    pixel_size = 48,
                    halign = Gtk.Align.CENTER,
                    margin_bottom = 6
                };
                
                var label = new Gtk.Label("") {
                    halign = Gtk.Align.CENTER,
                    wrap = true,
                    wrap_mode = Pango.WrapMode.WORD_CHAR,
                    max_width_chars = 12,
                    lines = 2,
                    ellipsize = Pango.EllipsizeMode.END,
                    justify = Gtk.Justification.CENTER
                };
                
                box.append(icon);
                box.append(label);
                list_item.child = box;
            });

            grid_factory.bind.connect((item) => {
                var list_item = item as Gtk.ListItem;
                if (list_item == null || list_item.child == null) return;

                var file = list_item.item as FileObject;
                if (file == null) return;

                var box = list_item.child as Gtk.Box;
                if (box == null) return;

                var children = new List<Gtk.Widget>();
                var child = box.get_first_child();
                while (child != null) {
                    children.append(child);
                    child = child.get_next_sibling();
                }

                if (children.length() >= 2) {
                    var icon = children.nth_data(0) as Gtk.Image;
                    var label = children.nth_data(1) as Gtk.Label;
                    
                    if (icon != null) {
                        if (file.is_folder) {
                            icon.icon_name = "folder";
                        } else {
                            string name_lower = file.name.down();
                            string full_path = Path.build_filename(current_directory.text, file.name);
                            
                            // Try to create thumbnail for images
                            var thumbnail = Thumbnail.create_thumbnail(full_path);
                            if (thumbnail != null) {
                                icon.set_from_paintable(thumbnail);
                            } else {
                                // Use default icons if thumbnail creation failed or for non-image files
                                if (name_lower.has_suffix(".jpg") || 
                                    name_lower.has_suffix(".jpeg") || 
                                    name_lower.has_suffix(".png") || 
                                    name_lower.has_suffix(".gif") || 
                                    name_lower.has_suffix(".webp")) {
                                    icon.icon_name = "image-x-generic";
                                } else if (name_lower.has_suffix(".mp4") || 
                                        name_lower.has_suffix(".mkv") || 
                                        name_lower.has_suffix(".avi") || 
                                        name_lower.has_suffix(".webm")) {
                                    icon.icon_name = "video-x-generic";
                                } else {
                                    icon.icon_name = "text-x-generic";
                                }
                            }
                        }
                    }
                    
                    if (label != null) {
                        label.label = file.name;
                    }

                    // Only set details label if in list view and if it exists
                    if (!is_grid_view && children.length() >= 3) {
                        var details_label = children.nth_data(2) as Gtk.Label;
                        if (details_label != null) {
                            details_label.label = file.date.format("%Y-%m-%d %H:%M");
                        }
                    }
                }
            });

            grid_view.factory = grid_factory;
            grid_view.model = selection_model;

            // Change this line
            view_stack.set_visible_child_name("grid_view");

        } else {
            // Configuration pour ListView
            var list_factory = new Gtk.SignalListItemFactory();

            list_factory.setup.connect((item) => {
                var list_item = item as Gtk.ListItem;

                // Créer une boîte horizontale pour aligner les éléments
                var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6) {
                    margin_start = 6,
                    margin_end = 6,
                    margin_top = 6,
                    margin_bottom = 6
                };

                var icon = new Gtk.Image() {
                    pixel_size = 24
                };

                var name_label = new Gtk.Label("") {
                    hexpand = true,
                    halign = Gtk.Align.START,
                    ellipsize = Pango.EllipsizeMode.END
                };

                var date_label = new Gtk.Label("") {
                    halign = Gtk.Align.END
                };

                box.append(icon);
                box.append(name_label);
                box.append(date_label);

                list_item.child = box;
            });

            list_factory.bind.connect((item) => {
                var list_item = item as Gtk.ListItem;
                if (list_item == null || list_item.child == null) return;

                var file = list_item.item as FileObject;
                if (file == null) return;

                var box = list_item.child as Gtk.Box;
                if (box == null) return;

                var icon = box.get_first_child() as Gtk.Image;
                var name_label = icon?.get_next_sibling() as Gtk.Label;
                var date_label = name_label?.get_next_sibling() as Gtk.Label;

                if (icon != null) {
                    if (file.is_folder) {
                        icon.icon_name = "folder";
                    } else {
                        // Déterminer l'icône en fonction de l'extension du fichier
                        string name_lower = file.name.down();
                        if (name_lower.has_suffix(".jpg") || 
                            name_lower.has_suffix(".jpeg") || 
                            name_lower.has_suffix(".png") || 
                            name_lower.has_suffix(".gif") || 
                            name_lower.has_suffix(".webp")) {
                            icon.icon_name = "image-x-generic";
                        } else if (name_lower.has_suffix(".mp4") || 
                                name_lower.has_suffix(".mkv") || 
                                name_lower.has_suffix(".avi") || 
                                name_lower.has_suffix(".webm")) {
                            icon.icon_name = "video-x-generic";
                        } else {
                            icon.icon_name = "text-x-generic";
                        }
                    }
                }

                if (name_label != null) {
                    name_label.label = file.name;
                }

                if (date_label != null) {
                    date_label.label = file.date.format("%Y-%m-%d %H:%M");
                }
            });

            list_view.factory = list_factory;
            list_view.model = selection_model;

            // Change this line
            view_stack.set_visible_child_name("list_view");
        }
    }

    private void setup_drag_source(Gtk.Widget view) {
        var drag_source = new Gtk.DragSource();
        drag_source.actions = Gdk.DragAction.COPY | Gdk.DragAction.MOVE;

        drag_source.prepare.connect((source, x, y) => {
            var selection_model = (view == grid_view ? grid_view.model : list_view.model) as Gtk.MultiSelection;
            if (selection_model == null) return null;

            dragged_files = new List<FileObject>();
            var selected = selection_model.get_selection();
            
            for (uint i = 0; i < selected.get_size(); i++) {
                uint position = selected.get_nth(i);
                var file_obj = selection_model.get_item(position) as FileObject;
                if (file_obj != null) {
                    dragged_files.append(file_obj);
                }
            }

            if (dragged_files.length() == 0) return null;

            // Create a simple icon for dragging
            string icon_name = dragged_files.length() == 1 ? 
                (dragged_files.data.is_folder ? "folder" : "text-x-generic") : 
                "folder";

            try {
                var icon_theme = Gtk.IconTheme.get_for_display(get_display());
                Gtk.IconPaintable paintable = icon_theme.lookup_icon(
                    icon_name,
                    null,
                    32,
                    1,
                    Gtk.TextDirection.NONE,
                    Gtk.IconLookupFlags.PRELOAD
                );
                
                source.set_icon(paintable, 16, 16);
            } catch (Error e) {
                print("Error setting drag icon: %s\n", e.message);
            }

            var builder = new GLib.StringBuilder();
            foreach (var file_obj in dragged_files) {
                string file_path = Path.build_filename(current_directory.text, file_obj.name);
                builder.append("file://");
                builder.append(file_path);
                builder.append("\n");
            }

            return new Gdk.ContentProvider.for_value(builder.str);
        });

        drag_source.end.connect((source) => {
            dragged_files = null;
        });

        view.add_controller(drag_source);
    }

    private void setup_drag_dest(Gtk.Widget view) {
        Gtk.DropTarget drag_dest = new Gtk.DropTarget(GLib.Type.STRING, Gdk.DragAction.COPY | Gdk.DragAction.MOVE);

        drag_dest.drop.connect((target, value, x, y) => {
            if (value.type() != GLib.Type.STRING) {
                print("Error: Value does not hold a string\n");
                return false;
            }

            string uri_list = (string)value;
            string[] uris = uri_list.strip().split("\n");

            // Get the target item at the drop coordinates
            FileObject? target_file = null;

            if (view == grid_view) {
                var native = view.get_native();
                if (native != null) {
                    double view_x = x;
                    double view_y = y;
                    double dx, dy;
                    native.get_surface_transform(out dx, out dy);
                    view_x -= dx;
                    view_y -= dy;

                    // Get the item at the drop position using modern width/height methods
                    int width = view.get_width();
                    int height = view.get_height();
                    if (view_x >= 0 && view_x < width && view_y >= 0 && view_y < height) {
                        int cell_width = 120;
                        int cell_height = 120;
                        uint col = (uint)(view_x / cell_width);
                        uint row = (uint)(view_y / cell_height);
                        uint position = row * grid_view.max_columns + col;

                        var selection_model = grid_view.model as Gtk.MultiSelection;
                        if (selection_model != null && position < selection_model.get_n_items()) {
                            target_file = selection_model.get_item(position) as FileObject;
                        }
                    }
                }
            } else {
                // Handle ListView drop
                int height = view.get_height();
                if (y >= 0 && y < height) {
                    int item_height = 40;
                    uint position = (uint)(y / item_height);
                    
                    var selection_model = list_view.model as Gtk.MultiSelection;
                    if (selection_model != null && position < selection_model.get_n_items()) {
                        target_file = selection_model.get_item(position) as FileObject;
                    }
                }
            }

            // Set target path based on target file
            string target_path;
            if (target_file != null && target_file.is_folder) {
                target_path = Path.build_filename(current_directory.text, target_file.name);
            } else {
                target_path = current_directory.text;
            }

            // Process the URIs
            foreach (string uri in uris) {
                if (uri == "") continue;
                string source_path = Uri.unescape_string(uri.replace("file://", ""));
                if (source_path == null) continue;

                string file_name = Path.get_basename(source_path);
                string destination_path = Path.build_filename(target_path, file_name);

                try {
                    var source_file = File.new_for_path(source_path);
                    var destination_file = File.new_for_path(destination_path);

                    // Check if source exists
                    if (!source_file.query_exists()) {
                        show_error_dialog("Error", "Source file does not exist: %s".printf(source_path));
                        continue;
                    }

                    // Check if destination exists
                    if (destination_file.query_exists()) {
                        show_error_dialog("Error", "File already exists at destination: %s".printf(destination_path));
                        continue;
                    }

                    // Try to move the file
                    if (!source_file.move(destination_file, FileCopyFlags.NONE)) {
                        show_error_dialog("Error", "Failed to move file: %s".printf(source_path));
                    } else {
                        // Refresh both source and destination directories if they're different
                        _directory(current_directory.text);
                        if (target_path != current_directory.text) {
                            _directory(target_path);
                        }
                    }
                } catch (GLib.Error e) {
                    show_error_dialog("Error", "Error moving file: %s".printf(e.message));
                }
            }

            return true;
        });

        view.add_controller(drag_dest);
    }

    private void show_error_dialog(string title, string message) {
        var dialog = new Gtk.AlertDialog(message);
        // dialog.title = title;
        dialog.buttons = new string[]{ "OK" };
        dialog.show(this);
    }
}