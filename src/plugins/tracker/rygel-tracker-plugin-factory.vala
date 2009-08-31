/*
 * Copyright (C) 2009 Zeeshan Ali (Khattak) <zeeshanak@gnome.org>.
 * Copyright (C) 2009 Nokia Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
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

using Rygel;
using Gee;
using CStuff;

private TrackerPluginFactory plugin_factory;

[ModuleInit]
public void module_init (PluginLoader loader) {
    try {
        plugin_factory = new TrackerPluginFactory (loader);
    } catch (DBus.Error error) {
        critical ("Failed to fetch list of external services: %s\n",
                error.message);
    }
}

public class TrackerPluginFactory {
    private const string TRACKER_SERVICE = "org.freedesktop.Tracker1";
    private const string TRACKER_OBJECT = "/org/freedesktop/Tracker1";
    private const string STATS_IFACE = "org.freedesktop.Tracker1.Statistics";

    dynamic DBus.Object statistics;
    PluginLoader        loader;

    public TrackerPluginFactory (PluginLoader loader) throws DBus.Error {
        var connection = DBus.Bus.get (DBus.BusType.SESSION);

        this.statistics = connection.get_object (TRACKER_SERVICE,
                                                 TRACKER_OBJECT,
                                                 STATS_IFACE);
        this.loader = loader;

        statistics.Get (this.get_statistics_cb);
    }

    private void get_statistics_cb (string[][] stats, GLib.Error err) {
        if (err != null) {
            warning ("Failed to get statistics from Tracker: %s\n",
                     err.message);
            warning ("Tracker plugin disabled.\n");

            return;
        }

        this.loader.add_plugin (new TrackerPlugin ());
    }
}

