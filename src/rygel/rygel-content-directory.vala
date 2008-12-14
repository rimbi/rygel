/*
 * Copyright (C) 2008 Zeeshan Ali <zeenix@gmail.com>.
 * Copyright (C) 2007 OpenedHand Ltd.
 *
 * Author: Zeeshan Ali <zeenix@gmail.com>
 *         Jorn Baayen <jorn@openedhand.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 */

using GUPnP;

/**
 * Errors used by ContentDirectory and deriving classes.
 */
public errordomain Rygel.ContentDirectoryError {
    NO_SUCH_OBJECT = 701
}

/**
 * Basic implementation of UPnP ContentDirectory service version 2. Most often
 * plugins will provide a child of this class. The inheriting classes should
 * override add_children_metadata and add_metadata virtual methods.
 */
public class Rygel.ContentDirectory: Service {
    public const string UPNP_ID = "urn:upnp-org:serviceId:ContentDirectory";
    public const string UPNP_TYPE =
                    "urn:schemas-upnp-org:service:ContentDirectory:2";
    public const string DESCRIPTION_PATH = "xml/ContentDirectory.xml";

    protected uint32 system_update_id;
    protected string feature_list;
    protected string search_caps;
    protected string sort_caps;

    protected MediaContainer root_container;

    DIDLLiteWriter didl_writer;

    // Public abstract methods derived classes need to implement
    public virtual void add_children_metadata
                            (DIDLLiteWriter didl_writer,
                             string         container_id,
                             string         filter,
                             uint           starting_index,
                             uint           requested_count,
                             string         sort_criteria,
                             out uint       number_returned,
                             out uint       total_matches,
                             out uint       update_id) throws Error {
        throw new ServerError.NOT_IMPLEMENTED ("Not Implemented\n");
    }

    public virtual void add_metadata (DIDLLiteWriter didl_writer,
                                       string         object_id,
                                       string         filter,
                                       string         sort_criteria,
                                       out uint       update_id) throws Error {
        throw new ServerError.NOT_IMPLEMENTED ("Not Implemented\n");
    }

    public virtual void add_root_children_metadata
                                        (DIDLLiteWriter didl_writer,
                                         string         filter,
                                         uint           starting_index,
                                         uint           requested_count,
                                         string         sort_criteria,
                                         out uint       number_returned,
                                         out uint       total_matches,
                                         out uint       update_id)
                                         throws Error {
        throw new ServerError.NOT_IMPLEMENTED ("Not Implemented\n");
    }

    public override void constructed () {
        this.didl_writer = new DIDLLiteWriter ();
        this.setup_root_container ();

        this.system_update_id = 0;
        this.feature_list =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
            "<Features xmlns=\"urn:schemas-upnp-org:av:avs\" " +
            "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" " +
            "xsi:schemaLocation=\"urn:schemas-upnp-org:av:avs" +
            "http://www.upnp.org/schemas/av/avs-v1-20060531.xsd\">" +
            "</Features>";
        this.search_caps = "";
        this.sort_caps = "";

        this.action_invoked["Browse"] += this.browse_cb;

        /* Connect SystemUpdateID related signals */
        this.action_invoked["GetSystemUpdateID"] +=
                                                this.get_system_update_id_cb;
        this.query_variable["SystemUpdateID"] += this.query_system_update_id;

        /* Connect SearchCapabilities related signals */
        this.action_invoked["GetSearchCapabilities"] +=
                                                this.get_search_capabilities_cb;
        this.query_variable["SearchCapabilities"] +=
                                                this.query_search_capabilities;

        /* Connect SortCapabilities related signals */
        this.action_invoked["GetSortCapabilities"] +=
                                                this.get_sort_capabilities_cb;
        this.query_variable["SortCapabilities"] +=
                                                this.query_sort_capabilities;

        /* Connect FeatureList related signals */
        this.action_invoked["GetFeatureList"] += this.get_feature_list_cb;
        this.query_variable["FeatureList"] += this.query_feature_list;
    }

    /* Browse action implementation */
    protected virtual void browse_cb (ContentDirectory content_dir,
                                      ServiceAction    action) {
        string object_id, browse_flag;
        bool browse_metadata;
        string sort_criteria, filter;
        uint starting_index, requested_count;
        uint num_returned, total_matches, update_id;

        /* Handle incoming arguments */
        action.get ("ObjectID", typeof (string), out object_id,
                    "BrowseFlag", typeof (string), out browse_flag,
                    "Filter", typeof (string), out filter,
                    "StartingIndex", typeof (uint), out starting_index,
                    "RequestedCount", typeof (uint), out requested_count,
                    "SortCriteria", typeof (string), out sort_criteria);

        /* BrowseFlag */
        if (browse_flag != null && browse_flag == "BrowseDirectChildren") {
            browse_metadata = false;
        } else if (browse_flag != null && browse_flag == "BrowseMetadata") {
            browse_metadata = true;
        } else {
            action.return_error (402, "Invalid Args");

            return;
        }

        /* ObjectID */
        if (object_id == null) {
            /* Stupid Xbox */
            action.get ("ContainerID", typeof (string), out object_id);
            if (object_id == null) {
                action.return_error (701, "No such object");

                return;
            }
        }

        /* Start DIDL-Lite fragment */
        this.didl_writer.start_didl_lite (null, null, true);

        try {
            if (browse_metadata) {
                // BrowseMetadata
                if (object_id == this.root_container.id) {
                    this.root_container.serialize (didl_writer);
                    update_id = this.system_update_id;
                } else {
                    this.add_metadata (this.didl_writer,
                                       object_id,
                                       filter,
                                       sort_criteria,
                                       out update_id);
                }

                num_returned = 1;
                total_matches = 1;
            } else {
                // BrowseDirectChildren
                if (object_id == this.root_container.id) {
                    this.add_root_children_metadata (this.didl_writer,
                                                     filter,
                                                     starting_index,
                                                     requested_count,
                                                     sort_criteria,
                                                     out num_returned,
                                                     out total_matches,
                                                     out update_id);
                } else {
                    this.add_children_metadata (this.didl_writer,
                                                object_id,
                                                filter,
                                                starting_index,
                                                requested_count,
                                                sort_criteria,
                                                out num_returned,
                                                out total_matches,
                                                out update_id);
                }
            }

            /* End DIDL-Lite fragment */
            this.didl_writer.end_didl_lite ();

            /* Retrieve generated string */
            string didl = this.didl_writer.get_string ();

            if (update_id == uint32.MAX) {
                update_id = this.system_update_id;
            }

            /* Set action return arguments */
            action.set ("Result", typeof (string), didl,
                        "NumberReturned", typeof (uint), num_returned,
                        "TotalMatches", typeof (uint), total_matches,
                        "UpdateID", typeof (uint), update_id);

            action.return ();
        } catch (Error error) {
            action.return_error (error.code, error.message);
        }

        /* Reset the parser state */
        this.didl_writer.reset ();
    }

    /* GetSystemUpdateID action implementation */
    private void get_system_update_id_cb (ContentDirectory content_dir,
                                          ServiceAction    action) {
        /* Set action return arguments */
        action.set ("Id", typeof (uint32), this.system_update_id);

        action.return ();
    }

    /* Query GetSystemUpdateID */
    private void query_system_update_id (ContentDirectory content_dir,
                                         string           variable,
                                         ref GLib.Value   value) {
        /* Set action return arguments */
        value.init (typeof (uint32));
        value.set_uint (this.system_update_id);
    }

    /* action GetSearchCapabilities implementation */
    private void get_search_capabilities_cb (ContentDirectory content_dir,
                                             ServiceAction    action) {
        /* Set action return arguments */
        action.set ("SearchCaps", typeof (string), this.search_caps);

        action.return ();
    }

    /* Query SearchCapabilities */
    private void query_search_capabilities (ContentDirectory content_dir,
                                            string           variable,
                                            ref GLib.Value   value) {
        /* Set action return arguments */
        value.init (typeof (string));
        value.set_string (this.search_caps);
    }

    /* action GetSortCapabilities implementation */
    private void get_sort_capabilities_cb (ContentDirectory content_dir,
                                           ServiceAction    action) {
        /* Set action return arguments */
        action.set ("SortCaps", typeof (string), this.sort_caps);

        action.return ();
    }

    /* Query SortCapabilities */
    private void query_sort_capabilities (ContentDirectory content_dir,
                                          string           variable,
                                          ref GLib.Value   value) {
        /* Set action return arguments */
        value.init (typeof (string));
        value.set_string (this.sort_caps);
    }

    /* action GetFeatureList implementation */
    private void get_feature_list_cb (ContentDirectory content_dir,
                                      ServiceAction    action) {
        /* Set action return arguments */
        action.set ("FeatureList", typeof (string), this.feature_list);

        action.return ();
    }

    /* Query FeatureList */
    private void query_feature_list (ContentDirectory content_dir,
                                     string           variable,
                                     ref GLib.Value   value) {
        /* Set action return arguments */
        value.init (typeof (string));
        value.set_string (this.feature_list);
    }

    private void setup_root_container () {
        string friendly_name = this.root_device.get_friendly_name ();
        this.root_container = new MediaContainer.root (friendly_name, 0);
    }

}

