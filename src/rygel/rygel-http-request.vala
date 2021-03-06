/*
 * Copyright (C) 2008, 2009 Nokia Corporation.
 * Copyright (C) 2006, 2007, 2008 OpenedHand Ltd.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *         Jorn Baayen <jorn.baayen@gmail.com>
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

using Gst;

internal errordomain Rygel.HTTPRequestError {
    UNACCEPTABLE = Soup.KnownStatusCode.NOT_ACCEPTABLE,
    BAD_REQUEST = Soup.KnownStatusCode.BAD_REQUEST,
    NOT_FOUND = Soup.KnownStatusCode.NOT_FOUND
}

/**
 * Responsible for handling HTTP client requests.
 */
internal class Rygel.HTTPRequest : GLib.Object, Rygel.StateMachine {
    public unowned HTTPServer http_server;
    private MediaContainer root_container;
    public Soup.Server server;
    public Soup.Message msg;
    private HashTable<string,string>? query;

    private HTTPResponse response;

    private string item_id;
    private int thumbnail_index;
    public MediaItem item;
    public Thumbnail thumbnail;
    public HTTPSeek byte_range;
    public HTTPSeek time_range;

    private HTTPRequestHandler request_handler;

    private Cancellable cancellable;

    public HTTPRequest (HTTPServer                http_server,
                        Soup.Server               server,
                        Soup.Message              msg,
                        HashTable<string,string>? query) {
        this.http_server = http_server;
        this.root_container = http_server.root_container;
        this.server = server;
        this.msg = msg;
        this.query = query;
        this.thumbnail_index = -1;
    }

    public void run (Cancellable? cancellable) {
        this.cancellable = cancellable;

        this.server.pause_message (this.msg);

        var header = this.msg.request_headers.get (
                                        "getcontentFeatures.dlna.org");

        /* We only entertain 'HEAD' and 'GET' requests */
        if ((this.msg.method != "HEAD" && this.msg.method != "GET") ||
            (header != null && header != "1")) {
            this.handle_error (
                        new HTTPRequestError.BAD_REQUEST ("Invalid Request"));
            return;
        }

        if (this.query != null) {
            this.item_id = this.query.lookup ("itemid");
            var target = this.query.lookup ("transcode");
            if (target != null) {
                var transcoder = this.http_server.get_transcoder (target);
                this.request_handler = new HTTPTranscodeHandler (transcoder);
            }

            var index = this.query.lookup ("thumbnail");
            if (index != null) {
                this.thumbnail_index = index.to_int ();
            }
        }

        if (this.item_id == null) {
            this.handle_error (new HTTPRequestError.NOT_FOUND ("Not Found"));
            return;
        }

        if (this.request_handler == null) {
            this.request_handler = new HTTPIdentityHandler ();
        }

        // Fetch the requested item
        this.root_container.find_object (this.item_id,
                                         null,
                                         this.on_item_found);
    }

    private void on_response_completed (HTTPResponse response) {
        this.end (Soup.KnownStatusCode.NONE);
    }

    private void handle_item_request () {
        try {
            this.byte_range = HTTPSeek.from_byte_range(this.msg);
            this.time_range = HTTPSeek.from_time_range(this.msg);

            // Add headers
            this.request_handler.add_response_headers (this);

            if (this.msg.method == "HEAD") {
                // Only headers requested, no need to send contents
                this.server.unpause_message (this.msg);
                this.end (Soup.KnownStatusCode.OK);
                return;
            }

            this.response = this.request_handler.render_body (this);
            this.response.completed += on_response_completed;
            this.response.run (this.cancellable);
        } catch (Error error) {
            this.handle_error (error);
        }
    }

    private void on_item_found (GLib.Object source_object,
                                AsyncResult res) {
        var container = (MediaContainer) source_object;

        MediaObject media_object;
        try {
            media_object = container.find_object_finish (res);
        } catch (Error err) {
            this.handle_error (err);
            return;
        }

        if (media_object == null || !(media_object is MediaItem)) {
            this.handle_error (new HTTPRequestError.NOT_FOUND (
                                        "requested item '%s' not found",
                                        this.item_id));
            return;
        }

        this.item = (MediaItem) media_object;

        if (this.thumbnail_index >= 0) {
            this.thumbnail = this.item.thumbnails.get (this.thumbnail_index);
        }

        this.handle_item_request ();
    }

    private void handle_error (Error error) {
        warning ("%s", error.message);

        uint status;
        if (error is HTTPRequestError) {
            status = error.code;
        } else {
            status = Soup.KnownStatusCode.NOT_FOUND;
        }

        this.server.unpause_message (this.msg);
        this.end (status);
    }

    public void end (uint status) {
        if (status != Soup.KnownStatusCode.NONE) {
            this.msg.set_status (status);
        }

        this.completed ();
    }
}

