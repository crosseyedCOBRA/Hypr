#include <stdlib.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <xcb/randr.h>
#include <xcb/xcb.h>
#include <xcb/xcb_ewmh.h>
#include <xcb/xcb_icccm.h>
#include <xcb/xcb_keysyms.h>
#include <xcb/xcb_atom.h>
#include <xcb/xcb_aux.h>
#include <xcb/xinerama.h>
#include <xcb/xcb_event.h>
#include <xcb/xcb_util.h>
#include <xcb/xcb_cursor.h>
#include <xcb/shape.h>
#include <xcb/composite.h>
#include <xcb/damage.h>
#include <xcb/render.h>
#include <xcb/xcb_renderutil.h>

// GLX/GL for milestone 2 of the bundled compositor (see ROADMAP.md) - the
// only place Xlib appears anywhere in this otherwise pure-XCB codebase,
// since glXBindTexImageEXT/glXCreatePixmap and friends are Xlib-only API
// with no complete xcb-glx equivalent. Kept to a dedicated, separate Xlib
// connection (CWindowManager::GLDisplay) purely for GL/GLX calls - the
// existing xcb_connection_t remains the only connection used for every
// other WM responsibility, so this never risks interfering with the main
// event loop.
#include <GL/glx.h>
#include <GL/glxext.h>
// This system's GL/gl.h only statically declares up to roughly GL 1.2/1.4 -
// every GLSL 2.0 shader entry point (glCreateShader, glUseProgram, etc.,
// used by milestone 3's rounded-corner shader) needs its own function
// pointer, resolved once via glXGetProcAddressARB at compositor setup time
// - glext.h supplies the PFNGL*PROC typedefs and GL_*_SHADER/GL_*_STATUS
// constants for that, the same way glxext.h already did for
// glXBindTexImageEXT/glXReleaseTexImageEXT.
#include <GL/glext.h>

#include <glib-2.0/glib.h>

#include <memory>
#include <string>
#include <algorithm>
#include <map>
#include <unordered_map>
#include <regex>
#include <vector>
#include <filesystem>

#include "./helpers/Vector.hpp"
#include "./utilities/Debug.hpp"

#ifndef NDEBUG
#define ISDEBUG true
#else
#define ISDEBUG false
#endif

// hints
#define NONMOVABLE
#define NONCOPYABLE
//

#define EXPOSED_MEMBER(var, type, prefix) \
    private: \
        type m_##prefix##var; \
    public: \
        inline type get##var() { return m_##prefix##var; } \
        void set##var(type value) { m_##prefix##var = value; }


#define EVENT(name) \
    void event##name(xcb_generic_event_t* event);

#define STICKS(a, b) abs((a) - (b)) < 2

#define VECINRECT(vec, x1, y1, x2, y2) (vec.x >= (x1) && vec.x <= (x2) && vec.y >= (y1) && vec.y <= (y2))

#define XCBQUERYCHECK(name, query, errormsg) \
    xcb_generic_error_t* error##name;        \
    const auto name = query;                 \
                                             \
    if (error##name != NULL) {               \
        Debug::log(ERR, errormsg);           \
        free(error##name);                   \
        free(name);                          \
        return;                              \
    }                                        \
    free(error##name);


#define VECTORDELTANONZERO(veca, vecb) (abs(veca.x - vecb.x) > 0.4f || abs(veca.y - vecb.y) > 0.4f)
#define VECTORDELTAMORETHAN(veca, vecb, delta) (abs(veca.x - vecb.x) > (delta) || abs(veca.y - vecb.y) > (delta))

#define PROP(cookie, name, len) const auto cookie = xcb_get_property(DisplayConnection, false, window, name, XCB_GET_PROPERTY_TYPE_ANY, 0, len); \
        const auto cookie##reply = xcb_get_property_reply(DisplayConnection, cookie, NULL)



#define ZARISATOM(name) {name, 0}

#define ALPHA(c) ((double)(((c) >> 24) & 0xff) / 255.0)
#define RED(c) ((double)(((c) >> 16) & 0xff) / 255.0)
#define GREEN(c) ((double)(((c) >> 8) & 0xff) / 255.0)
#define BLUE(c) ((double)(((c)) & 0xff) / 255.0)

#define CONTAINS(s, f) s.find(f) != std::string::npos

#define COLORDELTAOVERX(c, c1, d) (abs(RED(c) - RED(c1)) > d / 255.f || abs(GREEN(c) - GREEN(c1)) > d / 255.f || abs(BLUE(c) - BLUE(c1)) > d / 255.f || abs(ALPHA(c) - ALPHA(c1)) > d / 255.f)

#define _NET_MOVERESIZE_WINDOW_X (1 << 8)
#define _NET_MOVERESIZE_WINDOW_Y (1 << 9)
#define _NET_MOVERESIZE_WINDOW_WIDTH (1 << 10)
#define _NET_MOVERESIZE_WINDOW_HEIGHT (1 << 11)

#define SCRATCHPAD_ID 1337420