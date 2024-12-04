public class FileObject : Object {
    public const string DEFAULT_FOLDER_ICON = "folder-symbolic";
    
    public string name { get; set; }
    public bool is_folder { get; set; }
    public DateTime date { get; set; }
    public string icon_name { get; set; }
    public double opacity { get; set; }

    public FileObject(string name = "", bool is_folder = false, DateTime? date = null, string icon_name = DEFAULT_FOLDER_ICON, double opacity = 1.0) {
        this.name = name;
        this.is_folder = is_folder;
        this.date = date ?? new DateTime.now_local();
        this.icon_name = icon_name;
        this.opacity = opacity;
    }
}