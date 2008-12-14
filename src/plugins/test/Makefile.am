plugindir = $(libdir)/rygel-1.0

plugin_LTLIBRARIES = librygel-test.la

AM_CFLAGS = $(LIBGUPNP_CFLAGS) \
	    $(LIBGUPNP_AV_CFLAGS) \
	    $(LIBDBUS_GLIB_CFLAGS) \
	    $(GEE_CFLAGS) \
	    -I$(top_srcdir)/src/rygel -DDATA_DIR='"$(datadir)"'

BUILT_SOURCES = rygel-test.stamp \
		rygel-test-content-dir.h \
		rygel-test-content-dir.c \
		rygel-test-audio-item.h \
		rygel-test-audio-item.c \
		rygel-test-plugin.h \
		rygel-test-plugin.c

librygel_test_la_SOURCES = rygel-test-content-dir.h \
			   rygel-test-content-dir.c \
                           rygel-test-content-dir.vala \
                           rygel-test-audio-item.h \
                           rygel-test-audio-item.c \
                           rygel-test-audio-item.vala \
                           rygel-test-plugin.h \
                           rygel-test-plugin.c \
                           rygel-test-plugin.vala

rygel-test.stamp: $(filter %.vala,$(librygel_test_la_SOURCES))
	$(VALAC) -C --vapidir=$(top_srcdir)/src/rygel \
	--pkg rygel-1.0 --pkg cstuff \
	--pkg gupnp-1.0 --pkg gupnp-av-1.0 --pkg dbus-glib-1 --pkg gee-1.0 $^
	touch $@

librygel_test_la_LIBADD = $(LIBGUPNP_LIBS) \
			  $(LIBGUPNP_AV_LIBS) \
                          $(LIBDBUS_GLIB_LIBS) \
                          $(GEE_LIBS)
librygel_test_la_LDFLAGS = -shared -fPIC -module -avoid-version

CLEANFILES = $(BUILT_SOURCES)
MAINTAINERCLEANFILES = Makefile.in
