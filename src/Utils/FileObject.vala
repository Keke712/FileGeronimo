public class FileObject : Object {
    public string name { get; set; }
    public bool is_folder { get; set; }
    public DateTime date { get; set; }

    public FileObject(string name = "", bool is_folder = false, DateTime? date = null) {
        this.name = name;
        this.is_folder = is_folder;
        this.date = date ?? new DateTime.now_local();
    }
}