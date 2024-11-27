public class FileObject : Object {
    private string _name;
    private bool _is_folder;
    private DateTime _date;

    public string name {
        get { return _name; }
        set { _name = value; }
    }

    public bool is_folder {
        get { return _is_folder; }
        set { _is_folder = value; }
    }

    public DateTime date {
        get { return _date; }
        set { _date = value; }
    }

    // Default constructor
    public FileObject() {
        _name = "";
        _is_folder = false;
        _date = new DateTime.now_local();
    }
}