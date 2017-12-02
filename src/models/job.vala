public errordomain Icd.JobError {
    CAMERA
}

public class Icd.Job : GLib.Object, Json.Serializable {

    [Description(nick = "primary_key")]
    public int id { get; construct set; }

    /* In seconds */
    public int interval { get; set; }

    private int _count;
    public int count {
        get {
            return _count;
        }
        set {
            _count = value;
            remaining = count;
        }
    }

    public int remaining { get; set; }

    public bool running { get; set; }

    public signal void changed (int id, string property);

    public string to_string () {
        string str = "{ \"id\": %d, \"interval\": %d, \"count\": %d,
            \"running\": %s}".printf (
            id, interval, count, running.to_string ()
        );
        return str;
    }

    public async void run () throws Icd.JobError {
        Icd.Camera camera;
        Icd.Image image;

        try {
            camera = new Icd.Camera ();
        } catch (Icd.CameraError e) {
            throw new Icd.JobError.CAMERA (e.message);
        }

        var model = Icd.Model.get_default ();

        running = true;
        while (running) {
            for (int i = count - remaining; i < count; i++) {
                var start = get_monotonic_time ();
                var end = start + interval * 1000;
                try {
                    /* take a picture and save the image in the database */
                    image = camera.capture ();
                    model.images.create (image);
                    var snooze = (int)((end - get_monotonic_time ()) / 1000);
                    if (snooze > 0) {
                        yield nap (snooze);
                    } else {
                        warning ("The interval time (%d) for job %d is too short for the camera", interval, id);
                    }
                } catch (GLib.Error e) {
                    critical ("GLib.Error: %s", e.message);
                }

                remaining = count - i - 1;
                model.jobs.update (this);
            }

            running = false;
            model.jobs.delete (id);
        }

        image = null;
    }

	public async void nap (uint interval, int priority = GLib.Priority.DEFAULT) {
	    GLib.Timeout.add (interval, () => {
		    nap.callback ();

		    return false;
		    }, priority);
	    yield;
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
