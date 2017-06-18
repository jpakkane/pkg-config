#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

# Fetch Cflags of gtk+-3.0. Prior results to check for regressions.
# pkg-config-0.21 - pkg-config-0.27.1
# -DGSEAL_ENABLE -pthread -I/gtk/include/gtk-3.0 -I/gtk/include/atk-1.0 \
# -I/gtk/include/cairo -I/gtk/include/gdk-pixbuf-2.0 -I/gtk/include/pango-1.0 \
# -I/gtk/include/glib-2.0 -I/gtk/lib/glib-2.0/include -I/gtk/include/pixman-1 \
# -I/gtk/include -I/gtk/include/freetype2

g1result = '-DGSEAL_ENABLE -pthread -I/gtk/include/gtk-3.0 -I/gtk/include/pango-1.0 -I/gtk/include/atk-1.0 -I/gtk/include/cairo -I/gtk/include/pixman-1 -I/gtk/include -I/gtk/include/gdk-pixbuf-2.0 -I/gtk/include -I/gtk/include/pango-1.0 -I/gtk/include/glib-2.0 -I/gtk/lib/glib-2.0/include -I/gtk/include/freetype2 -I/gtk/include'

# Fetch Libs of gtk+-3.0. Prior results to check for regressions.
# pkg-config-0.21 - pkg-config-0.27.1
# -pthread -L/gtk/lib -lgtk-3 -lgdk-3 -latk-1.0 -lgio-2.0 -lpangoft2-1.0 \
# -lpangocairo-1.0 -lgdk_pixbuf-2.0 -lcairo-gobject -lcairo -lpango-1.0 \
# -lfreetype -lfontconfig -lgobject-2.0 -lgmodule-2.0 -lgthread-2.0 -lrt \
# -lglib-2.0
g2result = '-L/gtk/lib -lgtk-3 -lgdk-3 -lpangocairo-1.0 -latk-1.0 -lcairo-gobject -lcairo -lgdk_pixbuf-2.0 -lgio-2.0 -lpangoft2-1.0 -lpango-1.0 -lgobject-2.0 -lgthread-2.0 -pthread -lrt -lgmodule-2.0 -pthread -lrt -lglib-2.0 -lfreetype -lfontconfig'

# Fetch static Libs of gtk+-3.0. Prior results to check for regressions.
# pkg-config-0.21
# -pthread -L/gtk/lib -lgtk-3 -lgdk-3 -latk-1.0 -lgio-2.0 -lresolv \
# -lpangoft2-1.0 -lpangocairo-1.0 -lgdk_pixbuf-2.0 -lcairo-gobject -lcairo \
# -lpixman-1 -lXrender -lX11 -lpthread -lpng12 -lz -lm -lpango-1.0 \
# -lfontconfig -lexpat -lfreetype -lgobject-2.0 -lffi -lgmodule-2.0 -ldl \
# -lgthread-2.0 -lglib-2.0 -lrt
# pkg-config-0.22 - pkg-config-0.27.1
# -pthread -L/gtk/lib -lgtk-3 -lgdk-3 -latk-1.0 -lgio-2.0 -lresolv \
# -lpangoft2-1.0 -lpangocairo-1.0 -lgdk_pixbuf-2.0 -lcairo-gobject -lcairo \
# -lpixman-1 -lXrender -lX11 -lpthread -lxcb -lXau -lpng12 -lz -lm \
# -lpango-1.0 -lfontconfig -lexpat -lfreetype -lgobject-2.0 -lffi \
# -lgmodule-2.0 -ldl -lgthread-2.0 -lglib-2.0 -lrt
g3result = '-L/gtk/lib -lgtk-3 -lgdk-3 -lpangocairo-1.0 -latk-1.0 -lcairo-gobject -lcairo -lz -lpixman-1 -lpng12 -lz -lm -lXrender -lX11 -lpthread -lxcb -lXau -lgdk_pixbuf-2.0 -lm -lpng12 -lz -lm -lgio-2.0 -lz -lresolv -lpangoft2-1.0 -lpango-1.0 -lgobject-2.0 -lffi -lgthread-2.0 -pthread -lrt -lgmodule-2.0 -pthread -lrt -ldl -lglib-2.0 -lrt -lfreetype -lfontconfig -lexpat -lfreetype'

tests = [(0, g1result, '', {'PKG_CONFIG_LIBDIR': '${srcdir}/gtk'}, ['--cflags', 'gtk+-3.0']),
         (0, g1result, '', {'PKG_CONFIG_LIBDIR': '${srcdir}/gtk'}, ['--cflags', '--static', 'gtk+-3.0']),

#if [ "$list_indirect_deps" = no ]; then
#    run_test --libs gtk+-3.0
#fi
#
#if [ "$list_indirect_deps" = yes ]; then
#    run_test --libs gtk+-3.0
#fi
         (0, g3result, '', {'PKG_CONFIG_LIBDIR': '${srcdir}/gtk'}, ['--libs', '--static', 'gtk+-3.0']),
        ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))

