/*
 * Copyright (C) 2008 Zeeshan Ali <zeenix@gmail.com>.
 * Copyright (C) 2008 Nokia Corporation.
 *
 * Author: Zeeshan Ali <zeenix@gmail.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

using GUPnP;
using DBus;
using Gee;

/**
 * Represents Tracker category.
 */
public abstract class Rygel.TrackerCategory : Rygel.MediaContainer {
    /* class-wide constants */
    private const string TRACKER_SERVICE = "org.freedesktop.Tracker";
    private const string RESOURCES_PATH = "/org/freedesktop/Tracker/Resources";
    private const string RESOURCES_IFACE = "org.freedesktop.Tracker.Resources";

    public dynamic DBus.Object resource;

    public string category;

    /* UPnP class of items under this container */
    public string child_class;

    Gee.List<AsyncResult> results;

    public TrackerCategory (string         id,
                            MediaContainer parent,
                            string         title,
                            string         category,
                            string         child_class) {
        base (id, parent, title, 0);

        this.category = category;
        this.child_class = child_class;

        try {
            this.create_proxies ();

            /* FIXME: We need to hook to some tracker signals to keep
             *        this field up2date at all times
             */
            this.get_children_count ();

            this.results = new Gee.ArrayList<AsyncResult>();
        } catch (DBus.Error error) {
            critical ("Failed to create to Session bus: %s\n",
                      error.message);
        }
    }

    private void get_children_count () {
        var name = this.category.replace (":", "");
        var query = "SELECT COUNT(?item) " +
                    " AS " + name +
                    " WHERE { ?item a " + this.category + " }";
        debug ("Executing sqarql query: %s", query);
        try {
            this.resource.SparqlQuery (query, on_count_query_cb);
        } catch (GLib.Error error) {
            critical ("error getting items under category '%s': %s",
                      this.category,
                      error.message);

            return;
        }
    }

    private void on_count_query_cb (string[][] search_result,
                                    GLib.Error error) {
        if (error != null) {
            critical ("error getting items under category '%s': %s",
                      this.category,
                      error.message);

            return;
        }

        this.child_count = search_result[0][0].to_int ();
        debug ("Found %u items under %s category",
               this.child_count,
               this.category);
        this.updated ();
    }

    public override void get_children (uint               offset,
                                       uint               max_count,
                                       Cancellable?       cancellable,
                                       AsyncReadyCallback callback) {
        var res = new TrackerSearchResult (this, callback);

        this.results.add (res);

        try {
            this.query_items (res, null, offset, max_count);
        } catch (GLib.Error error) {
            res.error = error;

            res.complete_in_idle ();
        }
    }

    public override Gee.List<MediaObject>? get_children_finish (
                                                         AsyncResult res)
                                                         throws GLib.Error {
        var search_res = (Rygel.TrackerSearchResult) res;

        this.results.remove (search_res);

        if (search_res.error != null) {
            throw search_res.error;
        } else {
            return search_res.data;
        }
    }

    public override void find_object (string             id,
                                      Cancellable?       cancellable,
                                      AsyncReadyCallback callback) {
        var res = new TrackerSearchResult (this, callback);

        this.results.add (res);
        try {
            string uri = this.get_item_uri (id);
            if (uri == null) {
                throw new ContentDirectoryError.NO_SUCH_OBJECT (
                                                    "No such object");
            }

            var filter = "FILTER (?item = <" + uri + ">)";

            this.query_items (res, filter, 0, 0);
        } catch (GLib.Error error) {
            res.error = error;

            res.complete_in_idle ();
        }
    }

    private void query_items (TrackerSearchResult res,
                              string?             filter,
                              uint                offset,
                              uint                max_count)
                              throws GLib.Error {
        var keys = this.get_metadata_keys ();
        var query = "SELECT ?item ";

        for (int i = 0; keys[i] != null; i++) {
            query += "?key" +  i.to_string () + " ";
        }

        query += " WHERE { ?item a " + this.category + " ; ";
        for (int i = 0; keys[i] != null; i++) {
            var variable = "?key" +  i.to_string ();
            query += "OPTIONAL { ?item " + keys[i] + " " + variable + " } ";
        }

        if (filter != null) {
            query += filter;
        }

        query += " } ORDER BY ?item OFFSET " + offset.to_string ();
        if (max_count > 0) {
            query += " LIMIT " + max_count.to_string ();
        }

        debug ("Executing sqarql query: %s", query);
        this.resource.SparqlQuery (query, res.ready);
    }

    public override MediaObject? find_object_finish (AsyncResult res)
                                                     throws GLib.Error {
        var search_res = (Rygel.TrackerSearchResult) res;

        this.results.remove (search_res);

        if (search_res.error != null) {
            throw search_res.error;
        } else {
            return search_res.data[0];
        }
    }

    public bool is_thy_child (string item_id) {
        var parent_id = this.get_item_parent_id (item_id);

        if (parent_id != null && parent_id == this.id) {
            return true;
        } else {
            return false;
        }
    }

    public string? get_item_uri (string item_id) {
        var tokens = item_id.split (":", 2);

        if (tokens[0] != null && tokens[1] != null) {
            return tokens[1];
        } else {
            return null;
        }
    }

    private void create_proxies () throws GLib.Error {
        DBus.Connection connection = DBus.Bus.get (DBus.BusType.SESSION);

        this.resource = connection.get_object (TrackerCategory.TRACKER_SERVICE,
                                             TrackerCategory.RESOURCES_PATH,
                                             TrackerCategory.RESOURCES_IFACE);
    }

    private string? get_item_parent_id (string item_id) {
        var tokens = item_id.split (":", 2);

        if (tokens[0] != null) {
            return tokens[0];
        } else {
            return null;
        }
    }

    protected abstract string[] get_metadata_keys ();
    protected abstract MediaItem? create_item (string uri, string[] metadata);
}

