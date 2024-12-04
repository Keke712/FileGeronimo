using Gtk;

[GtkTemplate (ui = "/com/github/Keke712/fgeronimo/ui/Settings.ui")]
public class Settings : Gtk.Window {
    // UI Elements from template
    [GtkChild] private unowned ListBox sidebar;
    [GtkChild] private unowned Stack content_stack;
    [GtkChild] private unowned DropDown theme_dropdown;
    [GtkChild] private unowned ColorDialogButton accent_color;
    [GtkChild] private unowned ColorDialogButton folder_color;
    [GtkChild] private unowned CheckButton custom_css_enabled;
    [GtkChild] private unowned TextView custom_css_view;

    private GLib.Settings gsettings;
    private static Settings? instance;
    private static Gtk.CssProvider? accent_provider = null;
    private bool is_destroyed = false;

    public static Settings get_instance() {
        if (instance == null || instance.is_destroyed) {
            instance = new Settings();
            instance.close_request.connect(() => {
                instance.is_destroyed = true;
                return false;
            });
        }
        return instance;
    }

    private Settings() {
        Object();

        // Initialize GSettings
        gsettings = new GLib.Settings("com.github.keke712.fgeronimo");

        // Connect signals
        sidebar.row_selected.connect(on_sidebar_selection_changed);
        theme_dropdown.notify["selected"].connect(on_theme_changed);
        accent_color.notify["rgba"].connect(() => {
            Gdk.RGBA color = accent_color.get_rgba();  // Correctly get the RGBA value
            on_accent_color_changed(color);            // Then pass it to the handler
        });
        folder_color.notify["rgba"].connect(() => {
            Gdk.RGBA color = folder_color.get_rgba();
            gsettings.set_string("folder-color", color.to_string());
            apply_folder_color(color);
        });
        custom_css_enabled.toggled.connect(on_custom_css_enabled_changed);

        // Load initial settings
        load_settings();
        apply_accent_color_to_ui();
    }

    private void load_settings() {
        // Load theme setting
        string theme = gsettings.get_string("theme");
        theme_dropdown.selected = theme == "system" ? 0 : (theme == "light" ? 1 : 2);

        // Load accent color
        string color = gsettings.get_string("accent-color");
        Gdk.RGBA rgba = Gdk.RGBA();
        rgba.parse(color);
        accent_color.rgba = rgba;

        // Load folder color
        color = gsettings.get_string("folder-color");
        rgba = Gdk.RGBA();
        rgba.parse(color);
        folder_color.rgba = rgba;

        // Load custom CSS settings
        custom_css_enabled.active = gsettings.get_boolean("custom-css-enabled");
        custom_css_view.buffer.text = gsettings.get_string("custom-css");
    }

    private void on_sidebar_selection_changed(ListBoxRow? row) {
        if (row == null) return;

        switch (row.get_index()) {
            case 0:
                content_stack.visible_child_name = "general";
                break;
            case 1:
                content_stack.visible_child_name = "appearance";
                break;
            case 2:
                content_stack.visible_child_name = "shortcuts";
                break;
        }
    }

    private void on_theme_changed() {
        string[] themes = { "system", "light", "dark" };
        string theme = themes[theme_dropdown.selected];
        gsettings.set_string("theme", theme);
        apply_theme(theme);
    }

    private void on_accent_color_changed(Gdk.RGBA color) {
        string color_str = color.to_string();
        gsettings.set_string("accent-color", color_str);
        Settings.apply_accent_color(color); // Utiliser la méthode statique
        apply_accent_color_to_ui(); // Apply accent color to UI elements
    }

    public static void apply_accent_color(Gdk.RGBA color) {
        // Create CSS with the accent color and hover variant
        var css = """
            @define-color accent_color rgb(%d, %d, %d);
            @define-color accent_bg_color rgb(%d, %d, %d);
            @define-color accent_hover_color rgba(%d, %d, %d, 0.1);

            .view.grid-view child:selected,
            .view.list-view row:selected,
            .sidebar row:selected {
                background-color: @accent_bg_color;
            }

            .view.grid-view child:hover:not(:selected),
            .view.list-view row:hover:not(:selected),
            .sidebar row:hover:not(:selected) {
                background-color: @accent_hover_color;
            }
        """.printf(
            (int)(color.red * 255),
            (int)(color.green * 255),
            (int)(color.blue * 255),
            (int)(color.red * 255),
            (int)(color.green * 255),
            (int)(color.blue * 255),
            (int)(color.red * 255),
            (int)(color.green * 255),
            (int)(color.blue * 255)
        );

        // Remove existing provider if it exists
        if (accent_provider != null) {
            Gtk.StyleContext.remove_provider_for_display(
                Gdk.Display.get_default(),
                accent_provider
            );
        }

        // Create new provider
        accent_provider = new Gtk.CssProvider();
        accent_provider.load_from_data(css.data);

        // Add the new provider
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            accent_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    public static void apply_folder_color(Gdk.RGBA color) {
        var css = """
            .folder-icon {
                color: rgb(%d, %d, %d);
            }
        """.printf(
            (int)(color.red * 255),
            (int)(color.green * 255),
            (int)(color.blue * 255)
        );

        var provider = new Gtk.CssProvider();
        provider.load_from_data(css.data);

        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }

    private void on_custom_css_enabled_changed() {
        gsettings.set_boolean("custom-css-enabled", custom_css_enabled.active);
        custom_css_view.sensitive = custom_css_enabled.active;
    }

    private void apply_theme(string theme) {
        var style_manager = Adw.StyleManager.get_default();
        switch (theme) {
            case "light":
                style_manager.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
                break;
            case "dark":
                style_manager.color_scheme = Adw.ColorScheme.FORCE_DARK;
                break;
            default: // system
                style_manager.color_scheme = Adw.ColorScheme.DEFAULT;
                break;
        }
    }

    private void apply_custom_css(string css) {
        if (!custom_css_enabled.active) return;

        var provider = new Gtk.CssProvider();
        
        provider.load_from_data(css.data);
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        
    }

    private void apply_accent_color_to_ui() {
        Gdk.RGBA color = accent_color.get_rgba();
        string css = """
            .sidebar row:selected {
                background-color: rgb(%d, %d, %d);
                color: white;
            }
        """.printf(
            (int)(color.red * 255),
            (int)(color.green * 255),
            (int)(color.blue * 255)
        );

        var provider = new Gtk.CssProvider();
        provider.load_from_data(css.data);

        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        sidebar.add_css_class("sidebar");
    }
}
