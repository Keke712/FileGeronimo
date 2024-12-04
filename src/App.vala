public class FGeronimo : Gtk.Application {
    public static FGeronimo instance { get; private set; }
    private List<ILayerWindow> windows = new List<ILayerWindow> ();
    private bool css_loaded = false;
    private Daemon daemon;
    
    public static void main (string[] args) {
        if (FGeronimo.instance != null) {
            instance = FGeronimo.instance;
        } else {
            instance = new FGeronimo ();
        }
        instance.init_types ();
        instance.run (args);
    }

    construct {
        application_id = "com.github.keke712.fgeronimo";
        flags = ApplicationFlags.HANDLES_COMMAND_LINE;
    }
    
    private void init_types () { }

    public override void activate () {
        if (!css_loaded) {
            load_css ();
            css_loaded = true;
        }
        
        // Appliquer la couleur d'accent au démarrage
        var settings = new GLib.Settings("com.github.keke712.fgeronimo");
        string accent_color = settings.get_string("accent-color");
        var accent_rgba = Gdk.RGBA();
        if (accent_rgba.parse(accent_color)) {
            Settings.apply_accent_color(accent_rgba);
        }

        // Appliquer la couleur des dossiers au démarrage
        string folder_color = settings.get_string("folder-color");
        var folder_rgba = Gdk.RGBA();
        if (folder_rgba.parse(folder_color)) {
            Settings.apply_folder_color(folder_rgba);
        }
    
        windows.append (new FileExplorer (this));
    
        foreach (var window in windows) {
            window.present_layer ();
        }
    
        daemon = new Daemon (this);
        daemon.setup_socket_service ();
    }
    
    public void show_inspector () {
        Gtk.Window.set_interactive_debugging (true);
    }
    
    public bool toggle_window (string name) {
        ILayerWindow? w = null;
        foreach (var window in windows) {
            if (window.name.down () == name.down ()) {
                w = window;
                break;
            }
        }
        if (w != null) {
            w.visible = !w.visible;
            return true;
        }
        print(@"Window $name not found.\n");
        return false;
    }
    
    void load_css () {
        Gtk.CssProvider provider = new Gtk.CssProvider ();
        provider.load_from_resource ("com/github/Keke712/fgeronimo/fgeronimo.css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider,
                               Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
    
    public string process_command (string command) {
        string[] args = command.split (" ");
        string response = "";
    
        switch (args[0]) {
        case "-T" :
        case "--toggle-window" :
            if (args.length > 1) {
                string window_name = args[1];
                bool result = toggle_window (window_name);
                response = result ? @"$window_name toggled" : @"Failed to toggle $window_name";
            } else {
                response = "Error: Window name not provided";
            }
            break;
        case "-Q":
        case "--quit":
            this.quit ();
            break;
        case "-I":
        case "--inspector":
            show_inspector ();
            break;
        case "-h":
        case "--help":
            response = print_help ();
            break;
        case "-V":
        case "--version":
            response = get_app_version ();
            break;
        case "-D":
        case "--directory":
            if (args.length > 1) {
                string directory_path = args[1];
                activate(); // Launch the application
                open_directory(directory_path);
                response = "Opening directory: " + directory_path;
            } else {
                response = "Error: Directory path not provided";
            }
            break;
        default:
            response = "Unknown command. Use -h to see help.";
            break;
        }
        return response;
    }

    private void open_directory(string path) {
        foreach (var window in windows) {
            if (window is FileExplorer) {
                var file_explorer = window as FileExplorer;
                if (file_explorer != null) {
                    file_explorer.navigate_to(path);
                }
            }
        }
    }

    private string get_app_version () {
        return "1.1";
    }

    private string print_help () {
        return "Usage: fgeronimo [options]\n"
               + "Options:\n"
               + "  \033[34m-T|--toggle-window\033[0m \033[32m<window>\033[0m  | Toggle visibility of the specified window\n"
               + "  \033[34m-Q|--quit\033[0m                    | Quit the application\n"
               + "  \033[34m-I|--inspector\033[0m               | Open the GTK inspector\n"
               + "  \033[34m-D|--directory\033[0m \033[32m<path>\033[0m  | Open the specified directory at startup\n"
               + "  \033[34m-h|--help\033[0m                    | Show this help message";
    }
    
    public override int command_line (ApplicationCommandLine command_line) {
        string[] args = command_line.get_arguments ();
    
        if (args.length > 1) {
            string command = string.joinv (" ", args[1 : args.length]);
            string response = process_command (command);
            command_line.print (response + "\n");
            return 0;
        }
    
        activate ();
        return 0;
    }

    public override void shutdown() {
        Thumbnail.cleanup();
        base.shutdown();
    }
}