#pragma once

#include "defines.hpp"
#include "window.hpp"

#include <vector>
#include <thread>
#include <chrono>
#include <xcb/xcb.h>
#include <deque>

#include "KeybindManager.hpp"
#include "utilities/Workspace.hpp"
#include "config/ConfigManager.hpp"
#include "utilities/Monitor.hpp"
#include "utilities/Util.hpp"
#include "utilities/AnimationUtil.hpp"
#include "utilities/XCBProps.hpp"
#include "ewmh/ewmh.hpp"

class CWindowManager {
public:
    xcb_connection_t*           DisplayConnection = nullptr;
    xcb_screen_t*               Screen = nullptr;
    xcb_drawable_t              Drawable;
    int                         RandREventBase = -1;
    uint32_t                    Values[3];

    // Compositor (see ROADMAP.md's "Bundled compositor" entry for the full
    // plan) - off by default (config's own "enable_compositor", 0 unless a
    // user opts in) and only ever set true once `xcb_composite_
    // redirect_subwindows` has actually succeeded, so every other piece of
    // compositor-only code below can gate itself on this one flag rather
    // than re-checking config/extension presence every time. DamageEventBase
    // works exactly like RandREventBase above - a runtime-determined offset
    // needed to recognize the Damage extension's own notify events, since
    // extension event codes aren't compile-time constants.
    int                         DamageEventBase = -1;
    bool                        CompositingEnabled = false;

    // holds the objects of all active monitors.
    std::vector<SMonitor>       monitors;

    bool                        modKeyDown = false;
    int                         mouseKeyDown = 0;
    Vector2D                    mouseLastPos = Vector2D(0, 0);
    int64_t                     actingOnWindowFloating = 0;

    bool                        scratchpadActive = false;

    uint8_t                     Depth = 32;
    xcb_visualtype_t*           VisualType;
    xcb_colormap_t              Colormap;

    std::deque<CWindow>         windows; // windows never left. It has always been hiding amongst us.
    std::deque<CWindow>         unmappedWindows;
    xcb_drawable_t              LastWindow = -1;
    // Whether LastWindow's focus is attributable to the user themselves
    // deliberately clicking/hovering it, as opposed to the WM or some other
    // window's own request. Tracking *which specific window* the user moved
    // away from (an earlier attempt) broke under real testing: eventEnter
    // fires on every window the pointer crosses en route to its actual
    // target, not just where it settles, so the tracked window kept getting
    // overwritten by incidental pass-through crossings before the real
    // offender's reclaim attempt ever arrived. Tracking only "is the CURRENT
    // focus one the user actually chose" sidesteps that entirely: any
    // self-requested activation is rejected as long as this is true,
    // regardless of who's asking or what noisy history led here, and it's
    // naturally cleared the instant the user interacts with anything else.
    bool                        CurrentFocusIsUserChosen = false;

    // holds the objects representing every open workspace
    std::deque<CWorkspace>      workspaces;
    // holds the IDs of open workspaces, Monitor ID -> workspace ID
    std::deque<int>             activeWorkspaces;
    int                         lastActiveWorkspaceID = 1;
    int                         activeWorkspaceID = 1;

    GThread*                    tickThread; // drives animations, active window name, and periodic config checks

    bool                        mainThreadBusy = false;
    bool                        animationUtilBusy = false;

    xcb_cursor_t                pointerCursor;
    xcb_cursor_context_t*       pointerContext;

    Vector2D                    QueuedPointerWarp = {-1, -1};

    // Quickshell PopupWindows (Settings, Control Center, the calendar
    // flyout, the taskbar-mode launcher, tooltips) that should stay raised
    // above every other window - populated by Events::eventMapNotify (see
    // its own comment for why every Quickshell popup gets treated
    // uniformly rather than trying to single out just Settings/Control
    // Center), reasserted every event-loop tick by reassertAlwaysOnTop()
    // unless the popup's own monitor currently has a fullscreen window,
    // and lazily pruned of dead/unmapped entries the same tick.
    std::vector<xcb_window_t>   alwaysOnTopWindows;
    void                        reassertAlwaysOnTop();

    CWindow*                    getWindowFromDrawable(int64_t);
    void                        addWindowToVectorSafe(CWindow);
    void                        removeWindowFromVectorSafe(int64_t);

    void                        setupManager();
    bool                        handleEvent();
    void                        recieveEvent();
    void                        refreshDirtyWindows();

    void                        setFocusedWindow(xcb_drawable_t, bool userInitiated = false);
    void                        refocusWindowOnClosed();

    void                        calculateNewWindowParams(CWindow*);
    void                        getICCCMSizeHints(CWindow*);
    void                        fixWindowOnClose(CWindow*);
    void                        closeWindowAllChecks(int64_t);

    void                        moveActiveWindowTo(char);
    void                        moveActiveFocusTo(char);
    void                        moveActiveWindowToWorkspace(int);
    void                        moveActiveWindowToRelativeWorkspace(int);
    void                        warpCursorTo(Vector2D);
    void                        toggleWindowFullscrenn(const int&);
    void                        recalcAllDocks();

    void                        changeWorkspaceByID(int);
    void                        changeToLastWorkspace();
    void                        setAllWorkspaceWindowsDirtyByID(int);
    int                         getHighestWorkspaceID();
    CWorkspace*                 getWorkspaceByID(int);
    bool                        isWorkspaceVisible(int workspaceID);

    void                        setAllWindowsDirty();
    void                        setAllFloatingWindowsTop();
    void                        setAWindowTop(xcb_window_t);

    SMonitor*                   getMonitorFromWindow(CWindow*);
    SMonitor*                   getMonitorFromCursor();
    SMonitor*                   getMonitorFromCoord(const Vector2D);

    Vector2D                    getCursorPos();

    // finds a window that's tiled at cursor.
    CWindow*                    findWindowAtCursor();

    CWindow*                    findFirstWindowOnWorkspace(const int&);
    CWindow*                    findPreferredOnScratchpad();

    bool                        shouldBeFloatedOnInit(int64_t);
    void                        doPostCreationChecks(CWindow*);
    void                        getICCCMWMProtocols(CWindow*);

    void                        setupRandrMonitors();
    void                        setupDepth();
    void                        setupColormapAndStuff();

    void                        updateActiveWindowName();

    int                         getWindowsOnWorkspace(const int&);
    CWindow*                    getFullscreenWindowByWorkspace(const int&);

    void                        recalcAllWorkspaces();

    void                        moveWindowToUnmapped(int64_t);
    void                        moveWindowToMapped(int64_t);
    bool                        isWindowUnmapped(int64_t);

    void                        setAllWorkspaceWindowsAboveFullscreen(const int&);
    void                        setAllWorkspaceWindowsUnderFullscreen(const int&);

    void                        handleClientMessage(xcb_client_message_event_t*);

    bool                        shouldBeManaged(const int&);

    void                        changeSplitRatioCurrent(std::string dir);

    void                        processCursorDeltaOnWindowResizeTiled(CWindow*, const Vector2D&);

private:

    // Internal WM functions that don't have to be exposed

    void                        sanityCheckOnWorkspace(int);
    CWindow*                    getNeighborInDir(char dir);
    void                        eatWindow(CWindow* a, CWindow* toEat);
    bool                        canEatWindow(CWindow* a, CWindow* toEat);
    bool                        isNeighbor(CWindow* a, CWindow* b);
    void                        calculateNewTileSetOldTile(CWindow* pWindow);
    void                        calculateNewFloatingWindow(CWindow* pWindow);
    void                        setEffectiveSizePosUsingConfig(CWindow* pWindow);
    void                        cleanupUnusedWorkspaces();
    xcb_visualtype_t*           setupColors(const int&);
    void                        updateRootCursor();
    void                        applyShapeToWindow(CWindow* pWindow);
    SMonitor*                   getMonitorFromWorkspace(const int&);
    void                        recalcEntireWorkspace(const int&);
    void                        fixMasterWorkspaceOnClosed(CWindow* pWindow);
    void                        startWipeAnimOnWorkspace(const int&, const int&);
    void                        focusOnWorkspace(const int&);
    void                        dispatchQueuedWarp();
    CWindow*                    getMasterForWorkspace(const int&);
    void                        processDockHiding();
};

inline std::unique_ptr<CWindowManager> g_pWindowManager = std::make_unique<CWindowManager>();

inline std::map<std::string, xcb_atom_t> ZARISATOMS = {
    ZARISATOM("_NET_SUPPORTED"),
    ZARISATOM("_NET_SUPPORTING_WM_CHECK"),
    ZARISATOM("_NET_WM_NAME"),
    ZARISATOM("_NET_WM_VISIBLE_NAME"),
    ZARISATOM("_NET_WM_MOVERESIZE"),
    ZARISATOM("_NET_WM_STATE_STICKY"),
    ZARISATOM("_NET_WM_STATE_FULLSCREEN"),
    ZARISATOM("_NET_WM_STATE_DEMANDS_ATTENTION"),
    ZARISATOM("_NET_WM_STATE_MODAL"),
    ZARISATOM("_NET_WM_STATE_HIDDEN"),
    ZARISATOM("_NET_WM_STATE_FOCUSED"),
    ZARISATOM("_NET_WM_STATE"),
    ZARISATOM("_NET_WM_WINDOW_TYPE"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_NORMAL"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_DOCK"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_DIALOG"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_UTILITY"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_TOOLBAR"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_SPLASH"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_MENU"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_DROPDOWN_MENU"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_POPUP_MENU"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_TOOLTIP"),
    ZARISATOM("_NET_WM_WINDOW_TYPE_NOTIFICATION"),
    ZARISATOM("_NET_WM_DESKTOP"),
    ZARISATOM("_NET_WM_STRUT_PARTIAL"),
    ZARISATOM("_NET_CLIENT_LIST"),
    ZARISATOM("_NET_CLIENT_LIST_STACKING"),
    ZARISATOM("_NET_CURRENT_DESKTOP"),
    ZARISATOM("_NET_NUMBER_OF_DESKTOPS"),
    ZARISATOM("_NET_DESKTOP_NAMES"),
    ZARISATOM("_NET_DESKTOP_VIEWPORT"),
    ZARISATOM("_NET_ACTIVE_WINDOW"),
    ZARISATOM("_NET_CLOSE_WINDOW"),
    ZARISATOM("_NET_MOVERESIZE_WINDOW"),
    ZARISATOM("_NET_WM_USER_TIME"),
    ZARISATOM("_NET_STARTUP_ID"),
    ZARISATOM("_NET_WORKAREA"),
    ZARISATOM("_NET_WM_ICON"),
    ZARISATOM("WM_PROTOCOLS"),
    ZARISATOM("WM_DELETE_WINDOW"),
    ZARISATOM("UTF8_STRING"),
    ZARISATOM("WM_STATE"),
    ZARISATOM("WM_CLIENT_LEADER"),
    ZARISATOM("WM_TAKE_FOCUS"),
    ZARISATOM("WM_WINDOW_ROLE"),
    ZARISATOM("_NET_REQUEST_FRAME_EXTENTS"),
    ZARISATOM("_NET_FRAME_EXTENTS"),
    ZARISATOM("_MOTIF_WM_HINTS"),
    ZARISATOM("WM_CHANGE_STATE")};
