using GtkLayerShell;
using Gtk;

[GtkTemplate (ui = "/com/github/Keke712/fgeronimo/ui/FileExplorer.ui")]
public class FileExplorer : Gtk.Window, ILayerWindow {
    // Dimensions et espacement
    private const int CELL_WIDTH = 120;
    private const int CELL_HEIGHT = 120;
    private const int CELL_SPACING = 6;
    private const int LIST_ITEM_HEIGHT = 40;
    private const int LIST_ITEM_SPACING = 2;

    // Variables
    public string namespace { get; set; }
    public FileActions factions = new FileActions();
    public bool is_grid_view = true; // Affichage par défaut en GridView
    private List<FileObject> dragged_files;
    public ActionHistory action_history;
    private FileMonitor file_monitor;
    private string current_monitored_path;
    private EventListener event_listener;
    private ContextMenu context_menu;

    // GTK Childs
    [GtkChild] public unowned Entry current_directory;
    [GtkChild] public unowned Stack view_stack;      // Ajout du Stack
    [GtkChild] public unowned GridView grid_view;    // GridView pour la vue grille
    [GtkChild] public unowned ListView list_view;    // ListView pour la vue liste
    [GtkChild] public unowned Button back_button;
    [GtkChild] public unowned ListBox important_folders_list;
    [GtkChild] public unowned Button view_mode_button;
    [GtkChild] public unowned Button undo_button;
    [GtkChild] public unowned Box warning_box;
    [GtkChild] public unowned Image warning_icon;
    [GtkChild] public unowned Label warning_label;
    [GtkChild] public unowned Button warning_close_button;

    // Construct
    public FileExplorer (Gtk.Application app) {
        Object (application: app);
        
        // Initialize event listener
        event_listener = new EventListener(this);
        
        // Initialize thumbnail system
        Thumbnail.init();
        
        // Initialiser le FileMonitor avant toute utilisation
        file_monitor = FileMonitor.get_instance();
        
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

        // Initialiser l'historique
        action_history = new ActionHistory();
        action_history.history_changed.connect(() => {
            undo_button.sensitive = action_history.can_undo;
        });
        
        // Connecter le signal du bouton undo
        undo_button.clicked.connect(() => {
            if (action_history.undo_last_action()) {
                _directory(current_directory.text);
            }
        });

        // Subscribe to cut files changes
        factions.cut_files_changed.connect(() => {
            refresh_current_directory();
        });

        // Initialize context menu
        context_menu = new ContextMenu(this);
        
        // Add right-click gesture to both views
        setup_context_menu(grid_view);
        setup_context_menu(list_view);

        warning_close_button.clicked.connect(() => {
            warning_box.hide();
        });

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
        event_listener.handle_key_released(keyval);
    }

    [GtkCallback]
    public bool key_pressed(Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType state) {
        event_listener.handle_key_pressed(keyval);
        return false;
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

    public void navigate_to(string path) {
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
            case "Trash":
                folder_path = Path.build_filename(GLib.Environment.get_user_data_dir(), "Trash/files");
                break;
        }

        if (folder_path != null) {
            navigate_to(folder_path);
        } else {
            show_error_dialog("Folder path not found for %s\n".printf(folder_name));
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
        // Arrêter la surveillance de l'ancien dossier
        if (current_monitored_path != null) {
            file_monitor.unwatch_directory(current_monitored_path, this);
        }

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
                var box = new Gtk.Box(Gtk.Orientation.VERTICAL, CELL_SPACING) {
                    margin_start = CELL_SPACING,
                    margin_end = CELL_SPACING,
                    width_request = CELL_WIDTH,
                    height_request = CELL_HEIGHT
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
                            icon.icon_name = file.icon_name;
                            string full_path = Path.build_filename(current_directory.text, file.name);
                            icon.opacity = factions.is_file_cut(full_path) ? 0.5 : 1.0;
                        } else {
                            string name_lower = file.name.down();
                            string full_path = Path.build_filename(current_directory.text, file.name);
                            
                            // Set default icon first
                            if (name_lower.has_suffix(".jpg") || 
                                name_lower.has_suffix(".jpeg") || 
                                name_lower.has_suffix(".png") || 
                                name_lower.has_suffix(".gif") || 
                                name_lower.has_suffix(".webp")) {
                                icon.icon_name = "image-x-generic";
                                
                                // Request thumbnail asynchronously
                                Thumbnail.request_thumbnail(full_path, (texture) => {
                                    if (texture != null) {
                                        icon.set_from_paintable(texture);
                                    }
                                });
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
                    
                    if (label != null) {
                        label.label = file.name;
                        string full_path = Path.build_filename(current_directory.text, file.name);
                        label.opacity = factions.is_file_cut(full_path) ? 0.5 : 1.0;
                    }

                    // Only set details label if in list view and if it exists
                    if (!is_grid_view && children.length() >= 3) {
                        var details_label = children.nth_data(2) as Gtk.Label;
                        if (details_label != null) {
                            details_label.label = file.date.format("%Y-%m-%d %H:%M");
                            details_label.opacity = file.opacity;
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
                        icon.icon_name = file.icon_name;
                        string full_path = Path.build_filename(current_directory.text, file.name);
                        icon.opacity = factions.is_file_cut(full_path) ? 0.5 : 1.0;
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
                    string full_path = Path.build_filename(current_directory.text, file.name);
                    name_label.opacity = factions.is_file_cut(full_path) ? 0.5 : 1.0;
                }

                if (date_label != null) {
                    date_label.label = file.date.format("%Y-%m-%d %H:%M");
                    date_label.opacity = file.opacity;
                }
            });

            list_view.factory = list_factory;
            list_view.model = selection_model;

            // Change this line
            view_stack.set_visible_child_name("list_view");
        }

        // Commencer à surveiller le nouveau dossier
        current_monitored_path = path;
        file_monitor.watch_directory(path, this);
    }

    public void refresh_current_directory() {
        if (current_directory?.text != null) {
            _directory(current_directory.text);
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
                show_error_dialog("Error: Value does not hold a string\n");
                return false;
            }

            string uri_list = (string)value;
            string[] uris = uri_list.strip().split("\n");

            // Get the target item at the drop coordinates
            FileObject? target_file = null;
            var selection_model = (view == grid_view ? grid_view.model : list_view.model) as Gtk.MultiSelection;
            
            if (view == grid_view) {
                // Convertir les coordonnées globales en coordonnées relatives à la vue
                var adjustment = ((ScrolledWindow)grid_view.parent).vadjustment;
                double scrolled_y = y + adjustment.value;
                
                // Calculer le nombre total d'éléments visibles par ligne
                double visible_width = grid_view.get_width();
                int items_per_row = (int)(visible_width / (CELL_WIDTH + CELL_SPACING));
                if (items_per_row < 1) items_per_row = 1;
                
                // Calculer la position dans la grille
                int col = (int)(x / (CELL_WIDTH + CELL_SPACING));
                int row = (int)(scrolled_y / (CELL_HEIGHT + CELL_SPACING));
                
                // Calculer l'index dans le modèle
                uint position = (uint)(row * items_per_row + col);
                
                // Vérifier si la position est valide
                if (selection_model != null && position < selection_model.get_n_items()) {
                    target_file = selection_model.get_item(position) as FileObject;
                }
            } else {
                // Amélioration pour la ListView
                var adjustment = ((ScrolledWindow)list_view.parent).vadjustment;
                double scrolled_y = y + adjustment.value;
                
                uint position = (uint)(scrolled_y / (LIST_ITEM_HEIGHT + LIST_ITEM_SPACING));
                
                // Remove the redundant selection_model declaration and use the one from above
                if (selection_model != null && position < selection_model.get_n_items()) {
                    target_file = selection_model.get_item(position) as FileObject;
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
                        show_error_dialog("Source file does not exist: %s".printf(source_path));
                        continue;
                    }

                    // Check if destination exists
                    if (destination_file.query_exists()) {
                        show_error_dialog("File already exists at destination: %s".printf(destination_path));
                        continue;
                    }

                    // Try to move the file
                    if (!source_file.move(destination_file, FileCopyFlags.NONE)) {
                        show_error_dialog("Failed to move file: %s".printf(source_path));
                    } else {
                        _directory(current_directory.text);
                        // Record the action with correct paths
                        action_history.add_action(new FileAction(
                            FileAction.ActionType.MOVE,
                            source_path,
                            destination_path
                        ));
                    }
                } catch (GLib.Error e) {
                    show_error_dialog("Error moving file: %s".printf(e.message));
                }
            }

            return true;
        });

        view.add_controller(drag_dest);
    }

    public void show_error_dialog(string message) {
        warning_label.label = message;
        warning_box.show();
    }

    private void setup_context_menu(Gtk.Widget view) {
        var gesture = new Gtk.GestureClick() {
            button = Gdk.BUTTON_SECONDARY
        };
        
        gesture.pressed.connect((n_press, x, y) => {
            context_menu.show_at_pointer(gesture.get_last_event(null));
        });
        
        view.add_controller(gesture);
    }

    // Ajouter dans le destructeur pour nettoyer la surveillance
    ~FileExplorer() {
        if (current_monitored_path != null) {
            file_monitor.unwatch_directory(current_monitored_path, this);
        }
    }

    public string? find_matching_path(string partial_path) {
        // If it's already a complete valid path, return it
        if (FileUtils.test(partial_path, FileTest.EXISTS)) {
            return partial_path;
        }

        // Get the directory and filename parts
        string dir = Path.get_dirname(partial_path);
        string filename = Path.get_basename(partial_path).down();
        
        // If the directory doesn't exist, try relative to current directory
        if (!FileUtils.test(dir, FileTest.EXISTS)) {
            dir = current_directory.text;
            filename = partial_path.down();
        }

        try {
            var directory = Dir.open(dir);
            string? name = null;
            string? best_match = null;

            while ((name = directory.read_name()) != null) {
                string name_lower = name.down();
                if (name_lower.has_prefix(filename)) {
                    string full_path = Path.build_filename(dir, name);
                    best_match = full_path;
                    // If we find an exact match, return it immediately
                    if (name_lower == filename) {
                        return full_path;
                    }
                }
            }
            return best_match;
        } catch (Error e) {
            print("Error searching directory: %s\n", e.message);
            return null;
        }
    }
}