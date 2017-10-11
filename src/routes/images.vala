using VSGI;
using Valum;
using Valum.ContentNegotiation;

public class TimeLapse.ImageRouter : Valum.Router {

    construct {
        once ((req, res, next) => {
            return next ();
        });

        rule (Method.GET,    "/(<int:id>)?", view_cb);
        rule (Method.PUT,    "/<int:id>",    accept ("application/json", edit_cb));
        rule (Method.POST,   "/",            accept ("application/json", create_cb));
        rule (Method.DELETE, "/(<int:id>)?", delete_cb);
    }

    private bool view_cb (Request req, Response res, NextCallback next, Context context)
                          throws GLib.Error {
        var id = context["id"];
        var model = TimeLapse.Model.get_default ();
        if (id == null) {
            var images = model.images.read_all ();
            var generator = new Json.Generator ();

            if (images.length () > 0) {
                res.headers.set_content_type ("application/json", null);

                var image_array = new Json.Array ();
                foreach (var image in images) {
                    image_array.add_element (Json.gobject_serialize (image));
                }
                var node = new Json.Node.alloc ();
                node.init_array (image_array);
                generator.set_root (node);
                return generator.to_stream (res.body);
            } else {
                /* FIXME Need to return a proper code in the response */
                throw new ClientError.NOT_FOUND (
                    "No images were found");
            }

            //res.headers.set_content_type ("image/png", null);
            //var file = File.new_for_uri ("resource:///static/images/logo.png");
            //return res.expand_file (file);
        } else {
            var image = model.images.read (int.parse (id.get_string ()));
            var generator = new Json.Generator ();
            if (image != null) {
                res.headers.set_content_type ("application/json", null);
                generator.root = Json.gobject_serialize (image);
                generator.pretty = false;
                return generator.to_stream (res.body);
            } else {
                /* FIXME Need to return a proper code in the response */
                throw new ClientError.NOT_FOUND (
                    "No image was found with the ID provided");
            }
        }
    }

    private bool edit_cb (Request req, Response res, NextCallback next, Context context, string content_type)
                          throws GLib.Error {
        var id = context["id"];
        if (id == null) {
            throw new ClientError.NOT_FOUND ("No image ID was provided");
        }

        switch (content_type) {
            case "application/json":
                try {
                    var model = TimeLapse.Model.get_default ();
                    var image = model.images.read (int.parse (id.get_string ()));
                    var parser = new Json.Parser ();
                    parser.load_from_stream (req.body);
                    var node = parser.get_root ();
                    var obj = node.get_object ();
                    obj.foreach_member ((prop, name, prop_node) => {
                        ((Object) image).set_property (name, prop_node.get_value ());
                    });
                    model.images.update (image);
                } catch (GLib.Error e) {
                    throw new ClientError.BAD_REQUEST (
                        "Invalid or malformed JSON was provided");
                }
                break;
            default:
                throw new ClientError.BAD_REQUEST (
                    "Request used incorrect content type, 'application/json' expected");
        }
        return res.end ();
    }

    private bool create_cb (Request req, Response res, NextCallback next, Context context, string content_type)
                            throws GLib.Error {
        switch (content_type) {
            case "application/json":
                try {
                    var parser = new Json.Parser ();
                    parser.load_from_stream (req.body);
                    var image = Json.gobject_deserialize (typeof (TimeLapse.Image),
                                                          parser.get_root ());
                    var model = TimeLapse.Model.get_default ();
                    model.images.create ((TimeLapse.Image) image);
                } catch (GLib.Error e) {
                    throw new ClientError.BAD_REQUEST (
                        "Invalid or malformed JSON was provided");
                }
                break;
            default:
                throw new ClientError.BAD_REQUEST (
                    "Request used incorrect content type, 'application/json' expected");
        }

        return res.end ();
    }

    private bool delete_cb (Request req, Response res, NextCallback next, Context context)
                            throws GLib.Error{
        var id = context["id"];
        var model = TimeLapse.Model.get_default ();
        if (id != null) {
            model.images.delete (int.parse (id.get_string ()));
        } else {
            model.images.delete_all ();
        }

        return res.end ();
    }
}
