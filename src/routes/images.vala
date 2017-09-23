using VSGI;
using Valum;

public class TimeLapse.ImageRouter : Valum.Router {

    private TimeLapse.Model model;

    public ImageRouter (TimeLapse.Model model) {
        this.model = model;
    }

    construct {
        once ((req, res, next) => {
            return next ();
        });

        get ("/",         view_cb);
        get ("/<int:id>", view_cb);
        put ("/<int:id>", edit_cb);
        post ("/",        create_cb);
    }

    private bool view_cb (Request req, Response res, NextCallback next)
                          throws GLib.Error {
        res.headers.set_content_type ("image/png", null);
        return res.expand_file (File.new_for_path ("/usr/share/pixmaps/debian-logo.png"));
    }

    private bool edit_cb (Request req, Response res, NextCallback next)
                          throws GLib.Error {
        return true;
    }

    private bool create_cb (Request req, Response res, NextCallback next)
                            throws GLib.Error {
        var image = new TimeLapse.Image ();
        model.images.create (image);
        debug ("Created image");

        return res.end ();
    }
}