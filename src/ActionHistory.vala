public class FileAction {
    public enum ActionType {
        MOVE,
        DELETE,
        RENAME
    }

    public ActionType action_type { get; private set; }
    public string source_path { get; private set; }
    public string destination_path { get; private set; }
    public string? original_name { get; private set; }

    public FileAction(ActionType type, string source, string destination, string? orig_name = null) {
        this.action_type = type;
        this.source_path = source;
        this.destination_path = destination;
        this.original_name = orig_name;
    }
}

public class ActionHistory : Object {
    private Queue<FileAction> history;
    public bool can_undo { get; private set; default = false; }
    public signal void history_changed();

    public ActionHistory() {
        history = new Queue<FileAction>();
    }

    public void add_action(FileAction action) {
        history.push_tail(action);
        can_undo = true;
        history_changed();
    }

    public bool undo_last_action() {
        if (history.is_empty()) {
            return false;
        }

        var action = history.pop_tail();
        bool success = false;

        try {
            switch (action.action_type) {
                case FileAction.ActionType.MOVE:
                    var current = File.new_for_path(action.destination_path);
                    var original = File.new_for_path(action.source_path);
                    success = current.move(original, FileCopyFlags.NONE);
                    break;

                case FileAction.ActionType.DELETE:
                    // Pour l'instant, on ne gère pas l'annulation des suppressions
                    // car il faudrait garder une copie des fichiers supprimés
                    success = false;
                    break;

                case FileAction.ActionType.RENAME:
                    if (action.original_name != null) {
                        var current = File.new_for_path(action.destination_path);
                        var original = File.new_for_path(action.source_path);
                        success = current.move(original, FileCopyFlags.NONE);
                    }
                    break;
            }
        } catch (Error e) {
            print("Error during undo: %s\n", e.message);
            success = false;
        }

        can_undo = !history.is_empty();
        history_changed();
        return success;
    }
}