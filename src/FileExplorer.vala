using GtkLayerShell;
using Gtk;

[GtkTemplate (ui = "/com/github/Keke712/fgeronimo/ui/FileExplorer.ui")]
public class FileExplorer : Gtk.Window, ILayerWindow {
    // Variables
    public string namespace { get; set; }
    private FileActions factions = new FileActions();
    private List<string> directory_history = new List<string>();
    private int history_position = -1;  // Position actuelle dans l'historique
    private const int MAX_HISTORY = 50;  // Taille maximum de l'historique
    private bool is_grid_view = true; // Affichage par défaut en GridView

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
            } catch (Error e) {
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
        // Éviter d'ajouter le même chemin deux fois de suite
        if (current_directory.text == path) {
            return;
        }

        // Ajouter le nouveau chemin à l'historique
        if (directory_history.length() >= MAX_HISTORY) {
            directory_history.remove(directory_history.nth_data(0));  // Utiliser nth_data(0) au lieu de first()
            history_position--;
        }

        // Si on est au milieu de l'historique, supprimer tout ce qui suit
        if (history_position >= 0 && history_position < (int)(directory_history.length() - 1)) {  // Cast en int
            for (int i = (int)(directory_history.length() - 1); i > history_position; i--) {  // Cast en int
                string item_to_remove = directory_history.nth_data(i);
                directory_history.remove(item_to_remove);
            }
        }

        directory_history.append(path);
        history_position = (int)directory_history.length() - 1;

        // Mettre à jour le chemin et l'affichage
        current_directory.text = path;
        _directory(path);

        // Activer/désactiver le bouton retour
        back_button.sensitive = history_position > 0;
    }

    private void go_back() {
        if (history_position > 0) {
            history_position--;
            string previous_path = directory_history.nth_data(history_position);
            
            current_directory.text = previous_path;
            _directory(previous_path);

            // Mettre à jour la sensibilité du bouton retour
            back_button.sensitive = history_position > 0;
            
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
}