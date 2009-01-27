/*
 * Copyright (C) 2008 Zeeshan Ali <zeenix@gmail.com>.
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
using Gee;

public errordomain Rygel.MediaItemError {
    UNKNOWN_URI_TYPE
}

/**
 * Represents a media (Music, Video and Image) item. Provides basic
 * serialization (to DIDLLiteWriter) implementation.
 */
public class Rygel.MediaItem : MediaObject {
    public static const string IMAGE_CLASS = "object.item.imageItem";
    public static const string VIDEO_CLASS = "object.item.videoItem";
    public static const string AUDIO_CLASS = "object.item.audioItem";
    public static const string MUSIC_CLASS = "object.item.audioItem.musicTrack";

    public string author;
    public string album;
    public string date;
    public string upnp_class;

    // Resource info
    public string uri;
    public string mime_type;

    public long size = -1;       // Size in bytes
    public long duration = -1;   // Duration in seconds
    public int bitrate = -1;     // Bytes/second

    // Audio/Music
    public int sample_freq = -1;
    public int bits_per_sample = -1;
    public int n_audio_channels = -1;
    public int track_number = -1;

    // Image/Video
    public int width = -1;
    public int height = -1;
    public int color_depth = -1;

    protected Rygel.HTTPServer http_server;

    public MediaItem (string     id,
                      string     parent_id,
                      string     title,
                      string     upnp_class,
                      HTTPServer http_server) {
        this.id = id;
        this.parent_id = parent_id;
        this.title = title;
        this.upnp_class = upnp_class;
        this.http_server = http_server;
    }

    public override void serialize (DIDLLiteWriter didl_writer) throws Error {
        didl_writer.start_item (this.id,
                                this.parent_id,
                                null,
                                false);

        /* Add fields */
        didl_writer.add_string ("title",
                                DIDLLiteWriter.NAMESPACE_DC,
                                null,
                                this.title);

        didl_writer.add_string ("class",
                                DIDLLiteWriter.NAMESPACE_UPNP,
                                null,
                                this.upnp_class);

        if (this.author != null && this.author != "") {
            didl_writer.add_string ("creator",
                                    DIDLLiteWriter.NAMESPACE_DC,
                                    null,
                                    this.author);

            if (this.upnp_class.has_prefix (VIDEO_CLASS)) {
                didl_writer.add_string ("author",
                                        DIDLLiteWriter.NAMESPACE_UPNP,
                                        null,
                                        this.author);
            } else if (this.upnp_class.has_prefix (MUSIC_CLASS)) {
                didl_writer.add_string ("artist",
                                        DIDLLiteWriter.NAMESPACE_UPNP,
                                        null,
                                        this.author);
            }
        }

        if (this.track_number >= 0) {
            didl_writer.add_int ("originalTrackNumber",
                                 DIDLLiteWriter.NAMESPACE_UPNP,
                                 null,
                                 this.track_number);
        }

        if (this.album != null && this.album != "") {
            didl_writer.add_string ("album",
                                    DIDLLiteWriter.NAMESPACE_UPNP,
                                    null,
                                    this.album);
        }

        if (this.date != null && this.date != "") {
            didl_writer.add_string ("date",
                                    DIDLLiteWriter.NAMESPACE_DC,
                                    null,
                                    this.date);
        }

        /* Add resource data */
        DIDLLiteResource res = this.get_original_res ();

        /* Now get the transcoded/proxy URIs */
        var res_list = this.get_transcoded_resources (res);
        foreach (DIDLLiteResource trans_res in res_list) {
            didl_writer.add_res (trans_res);
        }

        /* Add the original res in the end */
        if (res.uri != null) {
            didl_writer.add_res (res);
        }

        /* End of item */
        didl_writer.end_item ();
    }

    private string get_protocol_for_uri (string uri) throws Error {
        if (uri.has_prefix ("http")) {
            return "http-get";
        } else if (uri.has_prefix ("file")) {
            return "internal";
        } else if (uri.has_prefix ("rtsp")) {
            // FIXME: Assuming that RTSP is always accompanied with RTP over UDP
            return "rtsp-rtp-udp";
        } else {
            throw new MediaItemError.UNKNOWN_URI_TYPE
                            ("Failed to probe protocol for URI %s", uri);
        }
    }

    // FIXME: We only proxy URIs through our HTTP server for now
    private ArrayList<DIDLLiteResource?>? get_transcoded_resources
                                            (DIDLLiteResource orig_res) {
        if (orig_res.protocol == "http-get")
            return null;

        var resources = new ArrayList<DIDLLiteResource?> ();

        // Copy the original res first
        DIDLLiteResource res = orig_res;

        // Then modify the URI and protocol
        res.uri = this.http_server.create_http_uri_for_item (this);
        res.protocol = "http-get";

        resources.add (res);

        return resources;
    }

    private DIDLLiteResource get_original_res () throws Error {
        DIDLLiteResource res = DIDLLiteResource ();
        res.reset ();

        res.uri = this.uri;
        res.mime_type = this.mime_type;

        res.size = this.size;
        res.duration = this.duration;
        res.bitrate = this.bitrate;

        res.sample_freq = this.sample_freq;
        res.bits_per_sample = this.bits_per_sample;
        res.n_audio_channels = this.n_audio_channels;

        res.width = this.width;
        res.height = this.height;
        res.color_depth = this.color_depth;

        /* Protocol info */
        if (res.uri != null) {
            string protocol = get_protocol_for_uri (res.uri);
            res.protocol = protocol;
        }

        /* DLNA related fields */
        res.dlna_profile = "MP3"; /* FIXME */

        if (this.upnp_class.has_prefix (MediaItem.IMAGE_CLASS)) {
            res.dlna_flags |= DLNAFlags.INTERACTIVE_TRANSFER_MODE;
        } else {
            res.dlna_flags |= DLNAFlags.STREAMING_TRANSFER_MODE;
        }

        if (res.size > 0) {
            res.dlna_operation = DLNAOperation.RANGE;
            res.dlna_flags |= DLNAFlags.BACKGROUND_TRANSFER_MODE;
        }

        return res;
    }
}
