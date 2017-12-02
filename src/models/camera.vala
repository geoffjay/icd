using GPhoto;

public errordomain Icd.CameraError {
    INITIALIZE,
    CAPTURE,
    CONFIG
}

public class Icd.Camera : GLib.Object, Json.Serializable {

    [Description(nick = "primary_key")]
    public int id { get; construct set; }

    [Description(nick = "unique")]
    public string name { get; set; }

    public bool connected { get; set; }

    private string _settings;
    public string settings {
        get {
            try {
                _settings =  retrieve_settings ();
            } catch (CameraError e) {
                critical ("Error retrieving camera settings: %s", e.message);
            }

            return _settings;
        }
        set {
            _settings = value;
            load_settings (value);
        }
    }

    private GPhoto.Camera camera;
    private GPhoto.Context gp_context;

    public Camera () throws Icd.CameraError {
        try {
            initialize_camera ();
        } catch (Icd.CameraError e) {
            critical (e.message);
            throw e;
        }
    }

    ~Camera () {
        camera.exit (gp_context);
    }

    /**
     * TODO Throw error if connection fails and use that in an HTTP response
     */
    private void initialize_camera () throws Icd.CameraError {
        Result ret;

        ret = GPhoto.Camera.create (out camera);
        if (ret != Result.OK) {
            critical (ret.to_full_string ());
            throw new CameraError.INITIALIZE (
                    "Camera initialization failed: %s".printf (ret.to_full_string ()));
        }

        gp_context = new GPhoto.Context ();
        ret = camera.init (gp_context);
        if (ret != Result.OK) {
            throw new Icd.CameraError.INITIALIZE (
                    "Camera initialization failed: %s".printf (ret.to_full_string ()));
        }
    }

    private string retrieve_settings () throws CameraError {
        Result ret;
        CameraWidget window;
        string name;

        ret = camera.get_config (out window, gp_context);
        if (ret != Result.OK) {
            throw new CameraError.CONFIG (ret.to_full_string ());
        }

        window.get_name (out name);
        debug ("Camera Config (incomplete)");
        debug (" name:           %s", name);
        debug (" child count:    %d", window.count_children ());

        return process_widgets (window, "");
    }

    private void load_settings (string settings) {
    }

    private string process_widgets (CameraWidget widget, string prefix) {
        int n, ret;
        string name, label;
        string use_label;
        string new_prefix;
        CameraWidgetType type;

        widget.get_name (out name);
        widget.get_label (out label);
        widget.get_type (out type);

        if (name.length > 0) {
            use_label = name;
        } else {
            use_label = label;
        }

        n = widget.count_children ();
        new_prefix = "%s/%s".printf (prefix, use_label);

        if ((type != CameraWidgetType.WINDOW) && (type != CameraWidgetType.SECTION)) {
            add_widget (widget, new_prefix);
        }

        for (int i = 0; i < n; i++) {
            CameraWidget child;
            ret = widget.get_child (i, out child);
            if (ret != Result.OK) {
                continue;
            }
            process_widgets (child, new_prefix);
        }

        return "blah blah blah";
    }

    private void add_widget (CameraWidget widget, string name) {
        int ret;
        CameraWidgetType type;
        string label;
        int readonly;
        void *value;

        string category = name.split ("/")[2];
        string subcategory = name.split ("/")[3];

        ret = widget.get_type (out type);
        ret = widget.get_label (out label);
        ret = widget.get_readonly (out readonly);
        ret = widget.get_value (out value);
        if (ret != Result.OK) {
            gp_context.error ("Failed to retrieve values of date widget %s.", name);
        }

        debug ("Label: %s %s", label, category);
        if ((bool)readonly) {
        } else {
            switch (type) {
                case CameraWidgetType.TEXT:
                    string text;
                    if (ret != Result.OK) {
                        gp_context.error ("Failed to retrieve value of text widget %s.", name);
                        break;
                    }
                    text = (string) value;
                    debug ("Type: TEXT");
                    debug ("Current: %s", text);
                    break;
                case CameraWidgetType.RANGE:
                    float[] ary;
                    float f, t, b, s;
                    ret = widget.get_range (out b, out t, out s);
                    if (ret != Result.OK) {
                        gp_context.error ("Failed to retrieve values of range widget %s.", name);
                        break;
                    }
                    ary = (float[]) value;
                    f = ary[0];
                    debug ("Type: RANGE");
                    debug ("Current: %g", f);
                    debug ("Bottom: %g", b);
                    debug ("Top: %g", t);
                    debug ("Step: %g", s);
                    break;
                case CameraWidgetType.TOGGLE:
                    uint8 t;
                    t = (uint8) value;
                    bool state = (t == 1);
                    debug ("Type: TOGGLE");
                    debug ("Current: %d", t);
                    break;
                case CameraWidgetType.DATE:
                    int t = (int)value;
                    GLib.DateTime time = new GLib.DateTime.from_unix_local (t);
                    string tstring = "%s".printf (time.format ("%b %d %Y %H:%M:%S"));

                    debug ("Type: DATE");
                    debug ("Current: %s", tstring);
                    debug ("Printable: ...");
                    debug ("Help: %s\n", "Use 'now' as the current time when setting.");
                    break;
                case CameraWidgetType.MENU:
                    int n = widget.count_choices ();
                    string current = (string) value;

                    debug ("Type: MENU");
                    debug ("Current: %s", current);
                    for (int i = 0; i < n; i++) {
                        string choice;
                        ret = widget.get_choice (i, out choice);
                        if (ret != Result.OK) {
                            continue;
                        }
                        debug ("Choice: %d %s", i, choice);
                    }
                    break;
                case CameraWidgetType.RADIO:
                    int n = widget.count_choices ();
                    string current = (string) value;

                    debug ("Type: RADIO");
                    debug ("Current: %s", current);
                    for (int i = 0; i < n; i++) {
                        string choice;
                        ret = widget.get_choice (i, out choice);
                        if (ret != Result.OK) {
                            continue;
                        }
                        debug ("Choice: %d %s", i, choice);
                    }
                    break;
                case CameraWidgetType.WINDOW:
                    debug ("Type: WINDOW");
                    break;
                case CameraWidgetType.SECTION:
                    debug ("Type: SECTION");
                    break;
                case CameraWidgetType.BUTTON:
                    debug ("Type: BUTTON");
                    break;
            }
        }
    }


    public Icd.Image capture () throws Icd.CameraError {
        Result ret;
        CameraFile file = null;
        CameraFilePath path;
        Icd.Image image;

        uint8 *data;
        ulong data_len = 0;
        string tmpname = "tmpfileXXXXXX";
        int fd = -1;
        long timestamp = 0;
        int width = 0, height = 0;

        ret = camera.capture (CameraCaptureType.IMAGE, out path, gp_context);
        if (ret != Result.OK) {
            critical (ret.to_full_string ());
            throw new Icd.CameraError.CAPTURE (
                    "Camera capture failed: %s".printf (ret.to_full_string ()));
        } else {
            fd = FileUtils.mkstemp (tmpname);
            if (fd == -1) {
                if (errno == Posix.EACCES) {
                    gp_context.error ("Permission denied");
                }
            } else {
                ret = CameraFile.create_from_fd (out file, fd);
            }

            if (file != null) {
                ret = camera.get_file ((string) path.folder,
                                       (string) path.name,
                                       CameraFileType.NORMAL,
                                       file,
                                       gp_context);

                if (ret != Result.OK) {
                    critical (ret.to_full_string ());
                    throw new Icd.CameraError.CAPTURE (
                            "Camera capture failed: %s".printf (ret.to_full_string ()));
                } else {
                    CameraFileInfo info;
                    ret = camera.get_file_info ((string) path.folder,
                                                (string) path.name,
                                                out info,
                                                gp_context);

                    if (ret != Result.OK) {
                        critical (ret.to_full_string ());
                        throw new Icd.CameraError.CAPTURE (
                                "Camera capture failed: %s".printf (ret.to_full_string ()));
                    } else {
                        timestamp = info.file.mtime;
                        width = (int) info.file.width;
                        height = (int) info.file.height;
                    }
                }
            }
        }

        ret = file.get_data_and_size (out data, out data_len);

        /**
         * TODO Throw error if previous data retrieval fails
         */
        if (ret != Result.OK) {
            critical (ret.to_full_string ());
        }

        image = new Icd.Image ();
        /* FIXME Make a real name */
        image.name = "Image";
        image.timestamp = timestamp;
        image.width = width;
        image.height = height;
        image.data.initialize (data_len);

        Posix.memcpy (image.data.data, data, (size_t) data_len);
        free (data);

        FileUtils.close (fd);
        FileUtils.unlink (tmpname);

        return image;
    }

    public Json.Node serialize_property (string property_name,
                                         Value value,
                                         ParamSpec pspec) {
        return default_serialize_property (property_name, value, pspec);
    }

    public bool deserialize_property (string property_name,
                                      out Value value,
                                      ParamSpec pspec,
                                      Json.Node property_node) {
        value = property_node.get_value ();

        return true;
    }

    public unowned ParamSpec? find_property (string name) {
        foreach (var property in list_properties ()) {
            if (property.get_name () == name) {
                return property;
            }
        }
        return null;
    }
}
