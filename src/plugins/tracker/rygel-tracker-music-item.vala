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

/**
 * Represents Tracker music item.
 */
public class Rygel.TrackerMusicItem : Rygel.TrackerItem {
    private enum Metadata {
        FILE_NAME,
        MIME,
        SIZE,
        DURATION,
        TITLE,
        ARTIST,
        TRACK_NUM,
        ALBUM,
        DATE,
        LAST_KEY
    }

    public TrackerMusicItem (string          id,
                             string          uri,
                             TrackerCategory parent,
                             string[]        metadata) {
        base (id, uri, parent, metadata);
    }

    public static string[] get_metadata_keys () {
        string[] keys = new string[Metadata.LAST_KEY];
        keys[Metadata.FILE_NAME] = "nfo:fileName";
        keys[Metadata.MIME] = "nie:mimeType";
        keys[Metadata.SIZE] = "nie:byteSize";
        keys[Metadata.TITLE] = "nie:title";
        keys[Metadata.DURATION] = "nmm:length";
        keys[Metadata.ARTIST] = "nmm:artistName";
        keys[Metadata.TRACK_NUM] = "nmm:trackNumber";
        keys[Metadata.ALBUM] = "nmm:musicAlbum ?album . ?album nie:title";
        keys[Metadata.DATE] = "dc:date";

        return keys;
    }

    protected override void init_from_metadata (string[] values) {
        if (values[Metadata.TITLE] != "")
            this.title = values[Metadata.TITLE];
        else
            /* If title wasn't provided, use filename instead */
            this.title = values[Metadata.FILE_NAME];

        if (values[Metadata.SIZE] != "")
            this.size = values[Metadata.SIZE].to_int ();

        if (values[Metadata.DURATION] != "")
            this.duration = values[Metadata.DURATION].to_int ();

        if (values[Metadata.TRACK_NUM] != "")
            this.track_number = values[Metadata.TRACK_NUM].to_int ();

        if (values[Metadata.DATE] != "")
            this.date = seconds_to_iso8601 (values[Metadata.DATE]);

        this.mime_type = values[Metadata.MIME];
        this.author = values[Metadata.ARTIST];
        this.album = values[Metadata.ALBUM];
        this.add_uri (uri, null);
    }
}

