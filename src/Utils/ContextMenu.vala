public class ContextMenu : Object {
    private FileExplorer explorer;
    private Gtk.PopoverMenu? menu;

    public ContextMenu(FileExplorer explorer) {
        this.explorer = explorer;
        
        // Create menu model
        var menu_model = new Menu();
        
        // First section
        var section1 = new Menu();
        section1.append("Cut", "menu.cut");
        section1.append("Copy", "menu.copy");
        section1.append("Paste", "menu.paste");
        menu_model.append_section(null, section1);
        
        // Second section
        var section2 = new Menu();
        section2.append("Move to Trash", "menu.delete");
        menu_model.append_section(null, section2);
        
        // Create popover menu
        menu = new Gtk.PopoverMenu.from_model(menu_model);
        
        // Connect actions
        var action_group = new SimpleActionGroup();
        
        // Add cut action
        var cut_action = new SimpleAction("cut", null);
        cut_action.activate.connect(() => {
            explorer.factions.cut_selected_files(explorer);
        });
        action_group.add_action(cut_action);
        
        // Add copy action
        var copy_action = new SimpleAction("copy", null);
        copy_action.activate.connect(() => {
            explorer.factions.copy_selected_files(explorer);
        });
        action_group.add_action(copy_action);
        
        // Add paste action
        var paste_action = new SimpleAction("paste", null);
        paste_action.activate.connect(() => {
            explorer.factions.paste_copied_files(explorer);
        });
        action_group.add_action(paste_action);
        
        // Add delete action
        var delete_action = new SimpleAction("delete", null);
        delete_action.activate.connect(() => {
            explorer.factions.move_selected_to_trash(explorer);
        });
        action_group.add_action(delete_action);
        
        // Insert action group
        menu.insert_action_group("menu", action_group);
    }

    public void show_at_pointer(Gdk.Event event) {
        if (menu == null) {
            print("Error: Context menu is null\n");
            return;
        }

        var rect = Gdk.Rectangle();
        var x = 0.0;
        var y = 0.0;
        event.get_position(out x, out y);
        
        // Fix the type conversion using (int) cast on the entire expression
        rect.x = (int)(x - x/4);
        rect.y = (int) y;
        rect.width = 0;  // Changed from 1 to 0
        rect.height = 0; // Changed from 1 to 0
        
        // Set parent before showing
        if (menu.get_parent() == null) {
            menu.set_parent(explorer);
        }
        
        menu.set_has_arrow(false);  // Add this line to remove the arrow
        menu.set_pointing_to(rect);
        menu.popup();
    }
}