#include "windowManager.hpp"
#include "./events/events.hpp"
#include <string.h>

xcb_visualtype_t* CWindowManager::setupColors(const int& desiredDepth) {
    auto depthIter = xcb_screen_allowed_depths_iterator(Screen);
    if (depthIter.data) {
        for (; depthIter.rem; xcb_depth_next(&depthIter)) {
            if (desiredDepth == 0 || desiredDepth == depthIter.data->depth) {
                for (auto it = xcb_depth_visuals_iterator(depthIter.data); it.rem; xcb_visualtype_next(&it)) {
                    return it.data;
                }
            }
        }
        if (desiredDepth > 0) {
            return setupColors(0);
        }
    }
    return nullptr;
}

void CWindowManager::setupDepth() {
    Depth = 24;
    VisualType = setupColors(Depth);
}

void CWindowManager::updateRootCursor() {
    if (xcb_cursor_context_new(DisplayConnection, Screen, &pointerContext) < 0) {
        Debug::log(ERR, "Creating a cursor context failed!");
        return;
    }

    pointerCursor = xcb_cursor_load_cursor(pointerContext, "left_ptr");

    Debug::log(LOG, "Cursor created with ID " + std::to_string(pointerCursor));

    // Set the cursor
    uint32_t values[1] = { pointerCursor };
    xcb_change_window_attributes(DisplayConnection, Screen->root, XCB_CW_CURSOR, values);
}

void CWindowManager::setupColormapAndStuff() {
    VisualType = xcb_aux_find_visual_by_attrs(Screen, -1, 32); // Transparency by default

    Depth = xcb_aux_get_depth_of_visual(Screen, VisualType->visual_id);
    Colormap = xcb_generate_id(DisplayConnection);
    const auto COOKIE = xcb_create_colormap(DisplayConnection, XCB_COLORMAP_ALLOC_NONE, Colormap, Screen->root, VisualType->visual_id);

    const auto XERR = xcb_request_check(DisplayConnection, COOKIE);

    if (XERR != NULL) {
        Debug::log(ERR, "Error in setupColormapAndStuff! Code: " + std::to_string(XERR->error_code));
    }

    free(XERR);
}

void CWindowManager::setupRandrMonitors() {

    XCBQUERYCHECK(RANDRVER, xcb_randr_query_version_reply(
        DisplayConnection, xcb_randr_query_version(DisplayConnection, XCB_RANDR_MAJOR_VERSION, XCB_RANDR_MINOR_VERSION), &errorRANDRVER), "RandR query failed!" );

        
    free(RANDRVER);

    Debug::log(LOG, "Setting up RandR! Query: v1.5.");

    XCBQUERYCHECK(MONITORS, xcb_randr_get_monitors_reply(DisplayConnection, xcb_randr_get_monitors(DisplayConnection, Screen->root, true), &errorMONITORS), "Couldn't get monitors. " + std::to_string(errorMONITORS->error_code));

    const auto MONITORNUM = xcb_randr_get_monitors_monitors_length(MONITORS);

    Debug::log(LOG, "Found " + std::to_string(MONITORNUM) + " Monitor(s)!");

    if (MONITORNUM < 1) {
        // TODO: RandR 1.4 maybe for people with ancient hardware?
        Debug::log(ERR, "RandR returned an invalid amount of monitors. Falling back to 1 monitor.");
        return;
    }

    for (xcb_randr_monitor_info_iterator_t iterator = xcb_randr_get_monitors_monitors_iterator(MONITORS); iterator.rem; xcb_randr_monitor_info_next(&iterator)) {
        const auto MONITORINFO = iterator.data;

        // basically an XCBQUERYCHECK but with continue; as its not fatal
        xcb_generic_error_t* error;
        const auto ATOMNAME = xcb_get_atom_name_reply(DisplayConnection, xcb_get_atom_name(DisplayConnection, MONITORINFO->name), &error);
        if (error != NULL) {
            Debug::log(ERR, "Failed to get monitor info...");
            free(error);
            free(ATOMNAME);
            continue;
        }
        free(error);

        monitors.push_back(SMonitor());

        const auto NAMELEN = xcb_get_atom_name_name_length(ATOMNAME);
        const auto NAME = xcb_get_atom_name_name(ATOMNAME);

        free(ATOMNAME);

        for (int j = 0; j < NAMELEN; ++j) {
            monitors[monitors.size() - 1].szName += NAME[j];
        }

        monitors[monitors.size() - 1].vecPosition = Vector2D(MONITORINFO->x, MONITORINFO->y);
        monitors[monitors.size() - 1].vecSize = Vector2D(MONITORINFO->width, MONITORINFO->height);

        monitors[monitors.size() - 1].primary = MONITORINFO->primary;

        monitors[monitors.size() - 1].ID = monitors.size() - 1;

        Debug::log(NONE, "Monitor " + monitors[monitors.size() - 1].szName + ": " + std::to_string(monitors[monitors.size() - 1].vecSize.x) + "x" + std::to_string(monitors[monitors.size() - 1].vecSize.y) +
                             ", at " + std::to_string(monitors[monitors.size() - 1].vecPosition.x) + "," + std::to_string(monitors[monitors.size() - 1].vecPosition.y) + ", ID: " + std::to_string(monitors[monitors.size() - 1].ID));
    }

    free(MONITORS);

    xcb_flush(DisplayConnection);

    if (monitors.size() == 0) {
        // RandR failed!
        Debug::log(WARN, "RandR failed!");
        monitors.clear();

#define TESTING_MON_AMOUNT 2
        for (int i = 0; i < TESTING_MON_AMOUNT /* Testing on 3 monitors, RandR shouldnt fail on a real desktop */; ++i) {
            monitors.push_back(SMonitor());
            monitors[i].vecPosition = Vector2D(i * Screen->width_in_pixels / TESTING_MON_AMOUNT, 0);
            monitors[i].vecSize = Vector2D(Screen->width_in_pixels / TESTING_MON_AMOUNT, Screen->height_in_pixels);
            monitors[i].ID = i;
            monitors[i].szName = "Screen" + std::to_string(i);
        }
    }
}

void CWindowManager::setupManager() {
    setupColormapAndStuff();
    EWMH::setupInitEWMH();

    // ---- RANDR ----- //
    setupRandrMonitors();

    // Select for screen-change events exactly once, here at startup - not inside
    // setupRandrMonitors() itself, which also gets called again from the RandR
    // change handler to re-detect monitors. RRSelectInput synchronously fires an
    // immediate ScreenChangeNotify reflecting current state, so re-selecting from
    // inside the handler that responds to that very event created an infinite
    // self-triggering loop (notify -> handler -> re-select -> new notify -> ...).
    // Every other client watching for RandR changes (Quickshell/Qt included) kept
    // reacting to that flood even after our own "suspicious event" cutoff gave up
    // on it, which is what was actually behind windows never finishing init.
    const auto RANDREXTENSION = xcb_get_extension_data(DisplayConnection, &xcb_randr_id);
    if (!RANDREXTENSION->present)
        Debug::log(ERR, "RandR extension missing");
    else {
        xcb_randr_select_input(DisplayConnection, Screen->root, XCB_RANDR_NOTIFY_MASK_SCREEN_CHANGE);
        RandREventBase = RANDREXTENSION->first_event;
        Debug::log(LOG, "RandR first event base found at " + std::to_string(RandREventBase) + ".");
    }

    Debug::log(LOG, "RandR done.");

    //
    //

    Values[0] = XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_STRUCTURE_NOTIFY | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY | XCB_EVENT_MASK_PROPERTY_CHANGE;
    const auto SUBREDIRECTCOOKIE = xcb_change_window_attributes_checked(DisplayConnection, Screen->root,
                                         XCB_CW_EVENT_MASK, Values);

    // SubstructureRedirect can only be selected by one client at a time - X11
    // itself enforces this (BadAccess), not anything checked here. XCB doesn't
    // refuse the *connection* just because another WM already holds it, so
    // without this check a second ZarisWM instance would run as a second,
    // real window manager silently fighting the first one over every window
    // (confirmed live: this actually happens, briefly, if the binary is ever
    // run while a session is already up).
    if (const auto SUBREDIRECTERROR = xcb_request_check(DisplayConnection, SUBREDIRECTCOOKIE); SUBREDIRECTERROR != NULL) {
        Debug::log(CRIT, "Failed to select SubstructureRedirect on the root window (X error code " + std::to_string(SUBREDIRECTERROR->error_code) + ") - is another window manager already running?");
        free(SUBREDIRECTERROR);
        exit(1);
    }

    Debug::log(LOG, "Root done.");

    ConfigManager::init();

    Debug::log(LOG, "Config done.");

    // ---- COMPOSITOR (optional, off by default) ---- //
    // See ROADMAP.md's "Bundled compositor" entry for the full plan and
    // milestone breakdown - this is milestone 1 only: redirect + damage
    // tracking, no redraw step yet. Gated behind config so building/
    // running this binary is a complete no-op for anyone who hasn't
    // explicitly opted in - nothing here should ever run on a real user's
    // session until the feature is actually finished.
    if (ConfigManager::getInt("enable_compositor")) {
        const auto COMPOSITEEXTENSION = xcb_get_extension_data(DisplayConnection, &xcb_composite_id);
        const auto DAMAGEEXTENSION = xcb_get_extension_data(DisplayConnection, &xcb_damage_id);

        if (!COMPOSITEEXTENSION || !COMPOSITEEXTENSION->present) {
            Debug::log(ERR, "Composite extension missing - compositor stays disabled.");
        } else if (!DAMAGEEXTENSION || !DAMAGEEXTENSION->present) {
            Debug::log(ERR, "Damage extension missing - compositor stays disabled.");
        } else {
            DamageEventBase = DAMAGEEXTENSION->first_event;

            // Manual mode: WE decide when/what to paint, matching every real
            // compositor - the alternative (automatic) just re-implements
            // the no-compositor default and isn't useful here. This can
            // legitimately fail (BadAccess) if another compositor already
            // has the root redirected, same class of failure the
            // SubstructureRedirect check above guards - unlike that one,
            // failing here isn't fatal, since compositing is still an
            // optional add-on layer at this stage, not core WM function.
            const auto REDIRECTCOOKIE = xcb_composite_redirect_subwindows_checked(
                DisplayConnection, Screen->root, XCB_COMPOSITE_REDIRECT_MANUAL);

            if (const auto REDIRECTERROR = xcb_request_check(DisplayConnection, REDIRECTCOOKIE); REDIRECTERROR != NULL) {
                Debug::log(ERR, "Failed to redirect subwindows for compositing (X error code " +
                                    std::to_string(REDIRECTERROR->error_code) +
                                    ") - is another compositor already running? Compositor stays disabled.");
                free(REDIRECTERROR);
            } else {
                CompositingEnabled = true;
                Debug::log(LOG, "Compositor enabled: subwindows redirected, Damage event base at " +
                                     std::to_string(DamageEventBase) + ".");

                // Milestone 1b: the root Picture every window gets painted
                // onto. xcb_render_util_query_formats caches its reply
                // internally (one round trip, ever), so calling it again
                // from compositorRepaint() per-window is cheap. Deliberately
                // NOT VisualType here - that's the 32-bit ARGB visual the WM
                // itself picked for the windows *it* creates (for alpha
                // support), not the root window's own visual, which the X
                // server chose independently (typically the screen's plain
                // default-depth visual). A Picture's format must match its
                // drawable's real depth, so using the wrong one here made
                // CreatePicture silently fail (unchecked) and every
                // subsequent Composite onto that bad Picture ID fail with
                // BadPicture - caught via a checked probe while debugging.
                const auto FORMATS = xcb_render_util_query_formats(DisplayConnection);
                const auto ROOTVISUALFORMAT = FORMATS ? xcb_render_util_find_visual_format(FORMATS, Screen->root_visual) : nullptr;

                if (!ROOTVISUALFORMAT) {
                    Debug::log(ERR, "Could not find a PictFormat for the root visual - compositor stays disabled.");
                    CompositingEnabled = false;
                } else {
                    RootPictFormat = ROOTVISUALFORMAT->format;
                    RootPicture    = xcb_generate_id(DisplayConnection);
                    const auto ROOTPICCOOKIE = xcb_render_create_picture_checked(DisplayConnection, RootPicture, Screen->root, RootPictFormat, 0, NULL);

                    if (const auto ROOTPICERROR = xcb_request_check(DisplayConnection, ROOTPICCOOKIE); ROOTPICERROR != NULL) {
                        Debug::log(ERR, "Failed to create the root Picture (X error code " + std::to_string(ROOTPICERROR->error_code) +
                                             ") - compositor stays disabled.");
                        free(ROOTPICERROR);
                        CompositingEnabled = false;
                    }
                }

                // Milestone 2: an optional upgrade on top of the XRender
                // path above, not a replacement for it - see GLReady's own
                // comment in windowManager.hpp. Only attempted once the
                // XRender fallback itself is confirmed working.
                if (CompositingEnabled)
                    compositorSetupGL();
            }
        }
    }

    Debug::log(LOG, "Compositor setup done.");

    // Add workspaces to the monitors
    for (long unsigned int i = 0; i < monitors.size(); ++i) {
        CWorkspace protoWorkspace;
        protoWorkspace.setID(i + 1);
        protoWorkspace.setMonitor(i);
        protoWorkspace.setHasFullscreenWindow(false);
        workspaces.push_back(protoWorkspace);
        activeWorkspaces.push_back(workspaces[i].getID());
    }

    Debug::log(LOG, "Workspace protos done.");
    //

    // ---- INIT THE THREAD FOR ANIM & CONFIG ---- //

    // start its' update thread
    Events::setThread();

    Debug::log(LOG, "Thread (Parent) done.");

    updateRootCursor();

    CWorkspace scratchpad;
    scratchpad.setID(SCRATCHPAD_ID);
    for (long unsigned int i = 0; i < monitors.size(); ++i) {
        if (monitors[i].primary)
            scratchpad.setMonitor(monitors[i].ID);
    }
    workspaces.push_back(scratchpad);

    Debug::log(LOG, "Finished setup!");

    // TODO: EWMH
}

bool CWindowManager::handleEvent() {
    if (xcb_connection_has_error(DisplayConnection))
        return false;

    xcb_flush(DisplayConnection);
    
    // recieve the event. Blocks.
    recieveEvent();

    // refresh and apply the parameters of all dirty windows.
    refreshDirtyWindows();

    // Keep Settings/Control Center/other Quickshell popups above every
    // other window, except a fullscreen one (see reassertAlwaysOnTop's own
    // comment and Events::eventMapNotify for how these get tracked).
    reassertAlwaysOnTop();

    // Sanity checks
    for (const auto active : activeWorkspaces) {
        sanityCheckOnWorkspace(active);
    }

    // hide docks/panels if fullscreen
    processDockHiding();

    // remove unused workspaces
    cleanupUnusedWorkspaces();

    // Process the queued warp
    dispatchQueuedWarp();

    // Update last window name
    updateActiveWindowName();

    // Update EWMH workspace info
    EWMH::updateDesktops();

    xcb_flush(DisplayConnection);

    // Restore thread state
    mainThreadBusy = false;

    return true;
}

void CWindowManager::recieveEvent() {
    const auto ev = xcb_wait_for_event(DisplayConnection);
    if (ev != NULL) {
        while (animationUtilBusy) {
            ;  // wait for it to finish
        }

        for (auto& e : Events::ignoredEvents) {
            if (e == ev->sequence) {
                Debug::log(LOG, "Ignoring event type " + std::to_string(ev->response_type & ~0x80) + ".");
                free(ev);
                return;
            }
        }
                
        if (Events::ignoredEvents.size() > 20)
            Events::ignoredEvents.pop_front();

        // Set thread state, halt animations until done.
        mainThreadBusy = true;

        // Milestone 6: any real (non-ignored) event might plausibly change
        // what's on screen (a window mapping/unmapping/moving/resizing, a
        // focus change repainting a border, etc.) - marking dirty here,
        // once, for every event rather than hunting down and separately
        // flagging each individual visually-relevant event type is a
        // deliberate simplicity/safety tradeoff: it costs an occasional
        // repaint that turns out not to have been strictly necessary (e.g.
        // a plain mouse-motion event over empty desktop), but can never
        // miss a real visual change and leave stale content on screen,
        // which would be a far worse bug than one redundant frame.
        CompositorDirty = true;

        const uint8_t TYPE = XCB_EVENT_RESPONSE_TYPE(ev);
        const auto EVENTCODE = ev->response_type & ~0x80;

        switch (EVENTCODE) {
            case XCB_ENTER_NOTIFY:
                Events::eventEnter(ev);
                Debug::log(LOG, "Event dispatched ENTER");
                break;
            case XCB_LEAVE_NOTIFY:
                Events::eventLeave(ev);
                Debug::log(LOG, "Event dispatched LEAVE");
                break;
            case XCB_DESTROY_NOTIFY:
                Events::eventDestroy(ev);
                Debug::log(LOG, "Event dispatched DESTROY");
                break;
            case XCB_UNMAP_NOTIFY:
                Events::eventUnmapWindow(ev);
                Debug::log(LOG, "Event dispatched UNMAP");
                break;
            case XCB_MAP_REQUEST:
                Events::eventMapWindow(ev);
                Debug::log(LOG, "Event dispatched MAP");
                break;
            case XCB_MAP_NOTIFY:
                Events::eventMapNotify(ev);
                Debug::log(LOG, "Event dispatched MAP_NOTIFY");
                break;
            case XCB_BUTTON_PRESS:
                Events::eventButtonPress(ev);
                Debug::log(LOG, "Event dispatched BUTTON_PRESS");
                break;
            case XCB_BUTTON_RELEASE:
                Events::eventButtonRelease(ev);
                Debug::log(LOG, "Event dispatched BUTTON_RELEASE");
                break;
            case XCB_MOTION_NOTIFY:
                Events::eventMotionNotify(ev);
                // Debug::log(LOG, "Event dispatched MOTION_NOTIFY"); // Spam!!
                break;
            case XCB_EXPOSE:
                Events::eventExpose(ev);
                Debug::log(LOG, "Event dispatched EXPOSE");
                break;
            case XCB_KEY_PRESS:
                Events::eventKeyPress(ev);
                Debug::log(LOG, "Event dispatched KEY_PRESS");
                break;
            case XCB_CLIENT_MESSAGE:
                Events::eventClientMessage(ev);
                Debug::log(LOG, "Event dispatched CLIENT_MESSAGE");
                break;
            case XCB_CONFIGURE_REQUEST:
                Events::eventConfigure(ev);
                Debug::log(LOG, "Event dispatched CONFIGURE");
                break;

            default:

                if ((EVENTCODE != 14) && (EVENTCODE != 13) && (EVENTCODE != 0) && (EVENTCODE != 22) && (TYPE - RandREventBase != XCB_RANDR_SCREEN_CHANGE_NOTIFY) && (TYPE - DamageEventBase != XCB_DAMAGE_NOTIFY))
                    Debug::log(WARN, "Unknown event: " + std::to_string(ev->response_type & ~0x80));
                break;
        }

        if ((int)TYPE - RandREventBase == XCB_RANDR_SCREEN_CHANGE_NOTIFY && RandREventBase > 0) {
            Events::eventRandRScreenChange(ev);
            Debug::log(LOG, "Event dispatched RANDR_SCREEN_CHANGE");
        }

        // Same runtime-offset dispatch pattern as RandR's own screen-change
        // notify above - Damage is an extension event, so its code isn't a
        // compile-time constant the switch above can match directly.
        // CompositingEnabled-gated, same as everywhere else this feature
        // touches, so this is unreachable when the compositor is off.
        if (CompositingEnabled && (int)TYPE - DamageEventBase == XCB_DAMAGE_NOTIFY && DamageEventBase > 0) {
            Events::eventDamageNotify(ev);
        }

        free(ev);
    }
}

void CWindowManager::processDockHiding() {
    for (auto& w : windows) {
        if (!w.getDock())
            continue;

        // get the dock's monitor
        const auto& MON = monitors[w.getMonitor()];

        // get the dock's current workspace
        auto *const WORK = getWorkspaceByID(activeWorkspaces[MON.ID]);

        if (!WORK)
            continue; // weird if happens

        if (WORK->getHasFullscreenWindow() && !w.getDockHidden()) {
            const auto COOKIE = xcb_unmap_window(DisplayConnection, w.getDrawable());
            Events::ignoredEvents.push_back(COOKIE.sequence);
            w.setDockHidden(true);
        }
            
        else if (!WORK->getHasFullscreenWindow() && w.getDockHidden()) {
            xcb_map_window(DisplayConnection, w.getDrawable());
            w.setDockHidden(false);
        }
    }
}

void CWindowManager::cleanupUnusedWorkspaces() {
    std::deque<CWorkspace> temp = workspaces;

    workspaces.clear();

    for (auto& work : temp) {
        if (!isWorkspaceVisible(work.getID())) {
            // check if it has any children
            bool hasChildren = getWindowsOnWorkspace(work.getID()) > 0;

            if (hasChildren) {
                // Has windows opened on it.
                workspaces.push_back(work);
            }
        } else {
            // Foreground workspace
            workspaces.push_back(work);
        }
    }
}

void CWindowManager::refreshDirtyWindows() {
    const auto START = std::chrono::high_resolution_clock::now();
    for(auto& window : windows) {
        if (window.getDirty()) {
            window.setDirty(false);

            // Check if the window isn't a node or has the noInterventions prop
            if (window.getChildNodeAID() != 0 || window.getNoInterventions() || window.getDock()) {
                // Docks skip the tiling/animation-oriented logic below (none
                // of it applies to them - they're not tiled, don't animate,
                // don't have a meaningful "workspace visibility" the way a
                // regular window does), but still need their shape applied
                // for rounding - applyShapeToWindow's own check already
                // excludes non-dock noInterventions windows, so this only
                // actually does anything for docks.
                if (window.getDock())
                    applyShapeToWindow(&window);
                continue;
            }
                
            setEffectiveSizePosUsingConfig(&window);

            const auto PWORKSPACE = getWorkspaceByID(window.getWorkspaceID());

            // Fullscreen flag
            bool bHasFullscreenWindow = PWORKSPACE ? PWORKSPACE->getHasFullscreenWindow() : false;

            // first and foremost, let's check if the window isn't on a hidden workspace
            // or an animated workspace
            if (PWORKSPACE && (!isWorkspaceVisible(window.getWorkspaceID())
                || PWORKSPACE->getAnimationInProgress()) && !window.getPinned()) {

                const auto MONITOR = getMonitorFromWindow(&window);

                Values[0] = (int)(window.getFullscreen() ? MONITOR->vecPosition.x : window.getRealPosition().x) + (int)PWORKSPACE->getCurrentOffset().x;
                Values[1] = (int)(window.getFullscreen() ? MONITOR->vecPosition.y : window.getRealPosition().y) + (int)PWORKSPACE->getCurrentOffset().y;

                if (bHasFullscreenWindow && !window.getFullscreen() && (window.getUnderFullscreen() || !window.getIsFloating())) {
                    Values[0] = 150000;
                    Values[1] = 150000;
                }

                if (VECTORDELTANONZERO(window.getLastUpdatePosition(), Vector2D(Values[0], Values[1]))) {
                    xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y, Values);
                    window.setLastUpdatePosition(Vector2D(Values[0], Values[1]));
                }

                // Set the size JIC.
                Values[0] = window.getFullscreen() ? MONITOR->vecSize.x : (int)window.getEffectiveSize().x;
                Values[1] = window.getFullscreen() ? MONITOR->vecSize.y : (int)window.getEffectiveSize().y;
                if (VECTORDELTANONZERO(window.getLastUpdateSize(), Vector2D(Values[0], Values[1]))) {
                    xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, Values);
                    window.setLastUpdateSize(Vector2D(Values[0], Values[1]));
                }

                applyShapeToWindow(&window);

                continue;
            }

            // or that it is not a non-fullscreen window in a fullscreen workspace thats under
            if (bHasFullscreenWindow && !window.getFullscreen() && (window.getUnderFullscreen() || !window.getIsFloating()) && !window.getPinned()) {
                Values[0] = 150000;
                Values[1] = 150000;
                if (VECTORDELTANONZERO(window.getLastUpdatePosition(), Vector2D(Values[0], Values[1]))) {
                    xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y, Values);
                    window.setLastUpdatePosition(Vector2D(Values[0], Values[1]));
                }

                continue;
            }

            // Fullscreen window. No border, all screen.
            // also do this when "layout:no_gaps_when_only" is set, but with a twist to enable the bar
            if (window.getFullscreen() || (ConfigManager::getInt("layout:no_gaps_when_only") && getWindowsOnWorkspace(window.getWorkspaceID()) == 1)) {
                Values[0] = 0;
                xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_BORDER_WIDTH, Values);

                const auto MONITOR = getMonitorFromWindow(&window);

                Values[0] = window.getFullscreen() ? (int)MONITOR->vecSize.x : MONITOR->vecSize.x - MONITOR->vecReservedTopLeft.x - MONITOR->vecReservedBottomRight.x;
                Values[1] = window.getFullscreen() ? (int) MONITOR->vecSize.y : MONITOR->vecSize.y - MONITOR->vecReservedTopLeft.y - MONITOR->vecReservedBottomRight.y;
                window.setEffectiveSize(Vector2D(Values[0], Values[1]));

                Values[0] = window.getFullscreen() ? (int)MONITOR->vecPosition.x : MONITOR->vecPosition.x + MONITOR->vecReservedTopLeft.x;
                Values[1] = window.getFullscreen() ? (int)MONITOR->vecPosition.y : MONITOR->vecPosition.y + MONITOR->vecReservedTopLeft.y;
                window.setEffectivePosition(Vector2D(Values[0], Values[1]));

                Values[0] = (int)window.getRealPosition().x;
                Values[1] = (int)window.getRealPosition().y;
                if (VECTORDELTANONZERO(window.getLastUpdatePosition(), Vector2D(Values[0], Values[1]))) {
                    const auto COOKIE = xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y, Values);
                    window.setLastUpdatePosition(Vector2D(Values[0], Values[1]));

                    Events::ignoredEvents.push_back(COOKIE.sequence);
                }
            } else {
                // Update the position because the border makes the window jump
                // I have added the bordersize vec2d before in the setEffectiveSizePosUsingConfig function.
                Values[0] = (int)window.getRealPosition().x - ConfigManager::getInt("border_size");
                Values[1] = (int)window.getRealPosition().y - ConfigManager::getInt("border_size");
                if (VECTORDELTANONZERO(window.getLastUpdatePosition(), Vector2D(Values[0], Values[1]))) {
                    const auto COOKIE = xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y, Values);
                    window.setLastUpdatePosition(Vector2D(Values[0], Values[1]));

                    Events::ignoredEvents.push_back(COOKIE.sequence);
                }

                Values[0] = (int)ConfigManager::getInt("border_size");
                xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_BORDER_WIDTH, Values);

                Values[0] = window.getRealBorderColor().getAsUint32();
                xcb_change_window_attributes(DisplayConnection, window.getDrawable(), XCB_CW_BORDER_PIXEL, Values);
            }

            // If it isn't animated or we have non-cheap animations, update the real size
            if (!window.getIsAnimated() || ConfigManager::getInt("animations:cheap") == 0) {
                Values[0] = (int)window.getRealSize().x;
                Values[1] = (int)window.getRealSize().y;
                if (VECTORDELTANONZERO(window.getLastUpdateSize(), Vector2D(Values[0], Values[1]))) {
                    const auto COOKIE = xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, Values);
                    window.setLastUpdateSize(Vector2D(Values[0], Values[1]));

                    Events::ignoredEvents.push_back(COOKIE.sequence);
                }
                window.setFirstAnimFrame(true);
            }

            if (ConfigManager::getInt("animations:cheap") == 1 && window.getFirstAnimFrame() && window.getIsAnimated()) {
                // first frame, fix the size if smaller
                window.setFirstAnimFrame(false);
                if (window.getRealSize().x < window.getEffectiveSize().x || window.getRealSize().y < window.getEffectiveSize().y) {
                    Values[0] = (int)window.getEffectiveSize().x;
                    Values[1] = (int)window.getEffectiveSize().y;
                    if (VECTORDELTANONZERO(window.getLastUpdateSize(), Vector2D(Values[0], Values[1]))) {
                        const auto COOKIE = xcb_configure_window(DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, Values);
                        window.setLastUpdateSize(Vector2D(Values[0], Values[1]));

                        Events::ignoredEvents.push_back(COOKIE.sequence);
                    }
                }
            }

            applyShapeToWindow(&window);

            // EWMH
            EWMH::updateWindow(window.getDrawable());
        }
    }

    Debug::log(LOG, "Refreshed dirty windows in " + std::to_string(std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::high_resolution_clock::now() - START).count()) + "us.");
}

void CWindowManager::setFocusedWindow(xcb_drawable_t window, bool userInitiated) {
    if (window && window != Screen->root) {
        const auto PNEWFOCUS = g_pWindowManager->getWindowFromDrawable(window);

        if (PNEWFOCUS && PNEWFOCUS->getNoInterventions()) {
            Debug::log(LOG, "Not setting focus to a non-interventions window.");
            return;
        }

        Debug::log(LOG, "Setting focus to " + std::to_string(window));

        xcb_ungrab_pointer(DisplayConnection, XCB_CURRENT_TIME);

        // border color
        if (const auto PLASTWIN = getWindowFromDrawable(LastWindow); PLASTWIN) {
            PLASTWIN->setEffectiveBorderColor(CFloatingColor(ConfigManager::getInt("col.inactive_border")));
        }
        if (const auto PLASTWIN = getWindowFromDrawable(window); PLASTWIN) {
		    PLASTWIN->setEffectiveBorderColor(CFloatingColor(ConfigManager::getInt("col.active_border")));
        }

        if (const auto PWINDOW = g_pWindowManager->getWindowFromDrawable(window); PWINDOW) {
            // Apply rounded corners, does all the checks inside.
            // The border changed so let's not make it rectangular maybe
            applyShapeToWindow(PWINDOW);
        }

        const auto LASTWINID = LastWindow;

        // A genuine user interaction (click/hover) always confirms the user's choice,
        // even if the window already happened to have focus for some other reason -
        // e.g. it was just auto-focused at creation (non-user-initiated), and the user
        // then deliberately hovers into it, confirming they actually want it. That
        // must upgrade it to user-chosen, not be treated as a no-op. A non-user-
        // initiated call, on the other hand, should only clear the flag if it's an
        // actual change of target - a redundant programmatic reclaim of the window
        // that already has focus must not silently erase existing protection for
        // whatever comes next.
        if (userInitiated)
            CurrentFocusIsUserChosen = true;
        else if (LASTWINID != window)
            CurrentFocusIsUserChosen = false;

        LastWindow = window;

        if (PNEWFOCUS) {
            applyShapeToWindow(g_pWindowManager->getWindowFromDrawable(window));

            // Transients
            PNEWFOCUS->bringTopRecursiveTransients();
        }

        // set focus in X11
        xcb_set_input_focus(DisplayConnection, XCB_INPUT_FOCUS_POINTER_ROOT, window, XCB_CURRENT_TIME);

        // EWMH
        EWMH::updateCurrentWindow(window);

        EWMH::updateWindow(window);
        EWMH::updateWindow(LASTWINID);
    }
}

// TODO: make this executed less. It's too often imo.
void CWindowManager::sanityCheckOnWorkspace(int workspaceID) {
    for (auto& w : windows) {
        if (w.getWorkspaceID() == workspaceID) {
            
            // Check #1: Parent has 2 identical children (happens!)
            if (w.getDrawable() < 0) {
                const auto CHILDA = w.getChildNodeAID();
                const auto CHILDB = w.getChildNodeBID();

                if (CHILDA == CHILDB) {
                    // Fix. Remove this parent, replace with child.
                    Debug::log(LOG, "Sanity check A triggered for window ID " + std::to_string(w.getDrawable()));

                    const auto PCHILD = getWindowFromDrawable(CHILDA);

                    if (!PCHILD){
                        // Means both children are 0 (dead)
                        removeWindowFromVectorSafe(w.getDrawable());
                        continue;
                    }

                    PCHILD->setPosition(w.getPosition());
                    PCHILD->setSize(w.getSize());

                    // make the sibling replace the parent
                    PCHILD->setParentNodeID(w.getParentNodeID());

                    if (w.getParentNodeID() != 0 && getWindowFromDrawable(w.getParentNodeID())) {
                        if (getWindowFromDrawable(w.getParentNodeID())->getChildNodeAID() == w.getDrawable()) {
                            getWindowFromDrawable(w.getParentNodeID())->setChildNodeAID(w.getDrawable());
                        } else {
                            getWindowFromDrawable(w.getParentNodeID())->setChildNodeBID(w.getDrawable());
                        }
                    }

                    // Make the sibling eat the closed window
                    PCHILD->setDirtyRecursive(true);
                    PCHILD->recalcSizePosRecursive();

                    // Remove the parent
                    removeWindowFromVectorSafe(w.getDrawable());

                    if (findWindowAtCursor())
                        setFocusedWindow(findWindowAtCursor()->getDrawable());  // Set focus. :)

                    Debug::log(LOG, "Sanity check A finished successfully.");
                }
            }

            // Hypothetical check #2: Check if children are present and tiled. (for nodes)
            // I have not found this occurring but I have had some issues with... stuff.
            if (w.getDrawable() < 0) {
                const auto CHILDA = getWindowFromDrawable(w.getChildNodeAID());
                const auto CHILDB = getWindowFromDrawable(w.getChildNodeBID());

                if (CHILDA && CHILDB) {
                    
                    if (CHILDA->getIsFloating()) {
                        g_pWindowManager->fixWindowOnClose(CHILDA);
                        g_pWindowManager->calculateNewWindowParams(CHILDA);

                        Debug::log(LOG, "Found an invalid tiled window, ID: " + std::to_string(CHILDA->getDrawable()) + ", untiling it.");
                    }

                    if (CHILDB->getIsFloating()) {
                        g_pWindowManager->fixWindowOnClose(CHILDB);
                        g_pWindowManager->calculateNewWindowParams(CHILDB);

                        Debug::log(LOG, "Found an invalid tiled window, ID: " + std::to_string(CHILDB->getDrawable()) + ", untiling it.");
                    }

                } else {
                    Debug::log(ERR, "Malformed node ID " + std::to_string(w.getDrawable()) + " with 2 children but one or both are nullptr.");

                    // fix it
                    if (!CHILDA && !CHILDB) {
                        closeWindowAllChecks(w.getDrawable());
                        Debug::log(ERR, "Node fixed, both nullptr.");
                        continue;
                    }

                    const auto PNULLCHILD = CHILDA ? CHILDB : CHILDA;
                    const auto PSIBLING = CHILDA ? CHILDA : CHILDB;

                    const auto PPARENT = getWindowFromDrawable(w.getDrawable());

                    if (!PPARENT)
                        return;  // ????????

                    if (!PSIBLING) {
                        Debug::log(ERR, "No sibling found in fixing malformed node! (Corrupted tree...?)");
                        return;
                    }

                    // FIX TREE ----
                    // make the sibling replace the parent
                    PSIBLING->setPosition(PPARENT->getPosition());
                    PSIBLING->setSize(PPARENT->getSize());
                    PSIBLING->setParentNodeID(PPARENT->getParentNodeID());

                    if (PPARENT->getParentNodeID() != 0 && getWindowFromDrawable(PPARENT->getParentNodeID())) {
                        if (getWindowFromDrawable(PPARENT->getParentNodeID())->getChildNodeAID() == PPARENT->getDrawable()) {
                            getWindowFromDrawable(PPARENT->getParentNodeID())->setChildNodeAID(PSIBLING->getDrawable());
                        } else {
                            getWindowFromDrawable(PPARENT->getParentNodeID())->setChildNodeBID(PSIBLING->getDrawable());
                        }
                    }
                    // TREE FIXED ----
                    Debug::log(ERR, "Tree fixed.");

                    // Fix master stuff
                    getMasterForWorkspace(PSIBLING->getWorkspaceID());

                    // recalc the workspace
                    if (ConfigManager::getInt("layout") == LAYOUT_MASTER)
                        recalcEntireWorkspace(PSIBLING->getWorkspaceID());
                    else {
                        PSIBLING->recalcSizePosRecursive();
                        PSIBLING->setDirtyRecursive(true);
                    }

                    // Remove the parent
                    removeWindowFromVectorSafe(PPARENT->getDrawable());

                    if (findWindowAtCursor())
                        setFocusedWindow(findWindowAtCursor()->getDrawable());  // Set focus. :)


                    Debug::log(ERR, "Node fixed, one nullptr.");
                }
            }
        }
    }
}

CWindow* CWindowManager::getWindowFromDrawable(int64_t window) {
    if (!window)
        return nullptr;

    for (auto& w : windows) {
        if (w.getDrawable() == window) {
            return &w;
        }
    }

    for (auto& w : unmappedWindows) {
        if (w.getDrawable() == window) {
            return &w;
        }
    }

    return nullptr;
}

void CWindowManager::addWindowToVectorSafe(CWindow window) {
    for (auto& w : windows) {
        if (w.getDrawable() == window.getDrawable())
            return; // Do not add if already present.
    }

    // See ROADMAP.md's compositor plan - every window needs its own Damage
    // object once compositing is on, tracking which regions of it need
    // repainting. Guarded by CompositingEnabled, so this is a complete
    // no-op (as always) while the feature is off.
    if (CompositingEnabled && window.getDrawable() && !window.getDamageObject()) {
        const xcb_damage_damage_t DAMAGEID = xcb_generate_id(DisplayConnection);
        xcb_damage_create(DisplayConnection, DAMAGEID, window.getDrawable(), XCB_DAMAGE_REPORT_LEVEL_NON_EMPTY);
        window.setDamageObject(DAMAGEID);
        Debug::log(LOG, "Created Damage object " + std::to_string(DAMAGEID) + " for window " + std::to_string(window.getDrawable()));
    }

    windows.push_back(window);
}

void CWindowManager::removeWindowFromVectorSafe(int64_t window) {

    if (!window)
        return;

    std::deque<CWindow> temp = windows;

    windows.clear();
    
    for(auto p : temp) {
        if (p.getDrawable() != window) {
            windows.push_back(p);
            continue;
        }
    }
}

void CWindowManager::applyShapeToWindow(CWindow* pWindow) {
    if (!pWindow)
        return;

    // Milestone 3: once the GL compositor path is actually painting frames
    // (GLReady), corner rounding moves entirely to an anti-aliased SDF test
    // in the fragment shader (see compositorRepaintGL()) - forcing this to
    // 0 here means the hard XShape clip this whole function otherwise
    // builds degenerates to a plain rectangle for the *rounding* portion
    // specifically. Everything else this function does (the border's own
    // shape, and the animation-in-progress off-monitor clipping rectangles
    // further down) is untouched and still applies exactly as before -
    // only the ROUNDING-driven arcs are affected, since the whole point is
    // to stop the client's own drawing being clipped at the corners at
    // all, so the shader has real (uncut) pixel data to round smoothly
    // instead of re-rounding an already-hard-cut source.
    const auto ROUNDING = pWindow->getFullscreen() || GLReady || (ConfigManager::getInt("layout:no_gaps_when_only") && getWindowsOnWorkspace(pWindow->getWorkspaceID()) == 1) ? 0 : ConfigManager::getInt("rounding");

    const auto SHAPEQUERY = xcb_get_extension_data(DisplayConnection, &xcb_shape_id);

    // Dock-type windows (bars/the app dock) are noInterventions, which used to
    // skip shaping entirely - meaning their QML side had to fake rounding with
    // its own decorative Rectangle inset by a margin, which (with no
    // compositor running to actually blend alpha) rendered as a plain opaque
    // black square peeking out around/behind the "rounded" content instead of
    // true transparency. Letting docks through here and having their QML draw
    // a plain full-bleed rectangle instead fixes that at the root: the real
    // window shape is what's rounded, not just something drawn inside it.
    if (!SHAPEQUERY || !SHAPEQUERY->present || (pWindow->getNoInterventions() && !pWindow->getDock()))
        return;

    Debug::log(LOG, "Applying shape to " + std::to_string(pWindow->getDrawable()));

    // Prepare values

    const auto MONITOR = getMonitorFromWindow(pWindow);

    if (!MONITOR) {
        Debug::log(ERR, "No monitor for " + std::to_string(pWindow->getDrawable()) + "??");
        return;
    }

    // getRealSize() is only ever kept up to date by the tiling/animation
    // system (see updateAnimations()) - dock-type windows skip that
    // entirely (refreshDirtyWindows() continues past them before reaching
    // it), so getRealSize() for a dock just sits at its unset default
    // (0,0) forever. Their actual current size lives in EffectiveSize
    // instead, which IS kept correct for them (set at creation in
    // remapFloatingWindow, and on every resize in eventConfigure).
    // Without this, shape application "runs" (logged) but computes a
    // mask for a zero-sized window, so it has no visible effect at all.
    const uint16_t W = pWindow->getFullscreen() ? MONITOR->vecSize.x : (pWindow->getDock() ? pWindow->getEffectiveSize().x : pWindow->getRealSize().x);
    const uint16_t H = pWindow->getFullscreen() ? MONITOR->vecSize.y : (pWindow->getDock() ? pWindow->getEffectiveSize().y : pWindow->getRealSize().y);
    // Docks get rounding (above) but never a border - they're not a regular
    // focusable window, and border_size would also expand the shape mask's
    // bounding box beyond the dock's own real geometry for no reason.
    const uint16_t BORDER = pWindow->getFullscreen() || pWindow->getDock() || (ConfigManager::getInt("layout:no_gaps_when_only") && getWindowsOnWorkspace(pWindow->getWorkspaceID()) == 1) ? 0 : ConfigManager::getInt("border_size");
    const uint16_t TOTALW = W + 2 * BORDER;
    const uint16_t TOTALH = H + 2 * BORDER;

    const auto RADIUS = ROUNDING + BORDER;
    const auto DIAMETER = RADIUS == 0 ? 0 : RADIUS * 2 - 1;

    const xcb_arc_t BOUNDINGARCS[] = {
        {-1, -1, DIAMETER, DIAMETER, 0, 360 << 6},
        {-1, TOTALH - DIAMETER, DIAMETER, DIAMETER, 0, 360 << 6},
        {TOTALW - DIAMETER, -1, DIAMETER, DIAMETER, 0, 360 << 6},
        {TOTALW - DIAMETER, TOTALH - DIAMETER, DIAMETER, DIAMETER, 0, 360 << 6},
    };
    const xcb_rectangle_t BOUNDINGRECTS[] = {
        {RADIUS, 0, TOTALW - DIAMETER, TOTALH},
        {0, RADIUS, TOTALW, TOTALH - DIAMETER},
    };

    const auto DIAMETERC = ROUNDING == 0 ? 0 : 2 * ROUNDING - 1;

    xcb_arc_t CLIPPINGARCS[] = {
        {-1, -1, DIAMETERC, DIAMETERC, 0, 360 << 6},
        {-1, H - DIAMETERC, DIAMETERC, DIAMETERC, 0, 360 << 6},
        {W - DIAMETERC, -1, DIAMETERC, DIAMETERC, 0, 360 << 6},
        {W - DIAMETERC, H - DIAMETERC, DIAMETERC, DIAMETERC, 0, 360 << 6},
    };
    xcb_rectangle_t CLIPPINGRECTS[] = {
        {ROUNDING, 0, W - DIAMETERC, H},
        {0, ROUNDING, W, H - DIAMETERC},
    };

    // Values done
    
    // XCB

    const xcb_pixmap_t PIXMAP1 = xcb_generate_id(DisplayConnection);
    const xcb_pixmap_t PIXMAP2 = xcb_generate_id(DisplayConnection);

    const xcb_gcontext_t BLACK = xcb_generate_id(DisplayConnection);
    const xcb_gcontext_t WHITE = xcb_generate_id(DisplayConnection);

    xcb_create_pixmap(DisplayConnection, 1, PIXMAP1, pWindow->getDrawable(), TOTALW, TOTALH);
    xcb_create_pixmap(DisplayConnection, 1, PIXMAP2, pWindow->getDrawable(), W, H);

    Values[0] = 0;
    Values[1] = 0;
    xcb_create_gc(DisplayConnection, BLACK, PIXMAP1, XCB_GC_FOREGROUND, Values);
    Values[0] = 1;
    xcb_create_gc(DisplayConnection, WHITE, PIXMAP1, XCB_GC_FOREGROUND, Values);

    // XCB done

    // Draw

    xcb_rectangle_t BOUNDINGRECT = {0, 0, W + 2 * BORDER, H + 2 * BORDER};
    xcb_poly_fill_rectangle(DisplayConnection, PIXMAP1, BLACK, 1, &BOUNDINGRECT);
    xcb_poly_fill_rectangle(DisplayConnection, PIXMAP1, WHITE, 2, BOUNDINGRECTS);
    xcb_poly_fill_arc(DisplayConnection, PIXMAP1, WHITE, 4, BOUNDINGARCS);

    xcb_rectangle_t CLIPPINGRECT = {0, 0, W, H};
    xcb_poly_fill_rectangle(DisplayConnection, PIXMAP2, BLACK, 1, &CLIPPINGRECT);
    xcb_poly_fill_rectangle(DisplayConnection, PIXMAP2, WHITE, 2, CLIPPINGRECTS);
    xcb_poly_fill_arc(DisplayConnection, PIXMAP2, WHITE, 4, CLIPPINGARCS);

    const auto WORKSPACE = getWorkspaceByID(pWindow->getWorkspaceID());

    if (!WORKSPACE) {
        Debug::log(ERR, "No workspace for " + std::to_string(pWindow->getDrawable()) + "??");
        return;
    }

    if (WORKSPACE->getAnimationInProgress()) {
        // if it's animated we draw 2 more black rects to clip it. (if it goes out of the monitor)

        if (W + (pWindow->getRealPosition().x + WORKSPACE->getCurrentOffset().x - MONITOR->vecPosition.x) > MONITOR->vecSize.x) {
            // clip right
            xcb_rectangle_t rect[] = {{MONITOR->vecSize.x - (pWindow->getRealPosition().x + WORKSPACE->getCurrentOffset().x - MONITOR->vecPosition.x), -100, W + 100, H + 100}};
            xcb_poly_fill_rectangle(DisplayConnection, PIXMAP1, BLACK, 1, rect);
            xcb_poly_fill_rectangle(DisplayConnection, PIXMAP2, BLACK, 1, rect);
        }

        if (pWindow->getRealPosition().x + WORKSPACE->getCurrentOffset().x - MONITOR->vecPosition.x < 0) {
            // clip left
            xcb_rectangle_t rect[] = {{-100, -100, - (pWindow->getRealPosition().x  + WORKSPACE->getCurrentOffset().x - MONITOR->vecPosition.x), H + 100}};
            xcb_poly_fill_rectangle(DisplayConnection, PIXMAP1, BLACK, 1, rect);
            xcb_poly_fill_rectangle(DisplayConnection, PIXMAP2, BLACK, 1, rect);
        }
    }

    // Draw done

    // Shape

    xcb_shape_mask(DisplayConnection, XCB_SHAPE_SO_SET, XCB_SHAPE_SK_BOUNDING, pWindow->getDrawable(), -BORDER, -BORDER, PIXMAP1);
    xcb_shape_mask(DisplayConnection, XCB_SHAPE_SO_SET, XCB_SHAPE_SK_CLIP, pWindow->getDrawable(), 0, 0, PIXMAP2);

    // Shape done

    // Cleanup

    xcb_free_pixmap(DisplayConnection, PIXMAP1);
    xcb_free_pixmap(DisplayConnection, PIXMAP2);
}

void CWindowManager::setEffectiveSizePosUsingConfig(CWindow* pWindow) {
    if (!pWindow || pWindow->getIsFloating())
        return;

    const auto MONITOR = getMonitorFromWindow(pWindow);

    // set some flags.
    const bool DISPLAYLEFT          = STICKS(pWindow->getPosition().x, MONITOR->vecPosition.x);
    const bool DISPLAYRIGHT         = STICKS(pWindow->getPosition().x + pWindow->getSize().x, MONITOR->vecPosition.x + MONITOR->vecSize.x);
    const bool DISPLAYTOP           = STICKS(pWindow->getPosition().y, MONITOR->vecPosition.y);
    const bool DISPLAYBOTTOM        = STICKS(pWindow->getPosition().y + pWindow->getSize().y, MONITOR->vecPosition.y + MONITOR->vecSize.y);

    const auto BORDERSIZE = ConfigManager::getInt("border_size");
    const auto GAPSOUT = ConfigManager::getInt("gaps_out");
    const auto GAPSIN = ConfigManager::getInt("gaps_in");

    auto TEMPEFFECTIVESIZE = pWindow->getSize();
    auto TEMPEFFECTIVEPOS  = pWindow->getPosition();

    const auto OFFSETTOPLEFT = Vector2D(DISPLAYLEFT ? GAPSOUT + MONITOR->vecReservedTopLeft.x : GAPSIN,
                                        DISPLAYTOP ? GAPSOUT + MONITOR->vecReservedTopLeft.y : GAPSIN);

    const auto OFFSETBOTTOMRIGHT = Vector2D(DISPLAYRIGHT ? GAPSOUT + MONITOR->vecReservedBottomRight.x : GAPSIN,
                                            DISPLAYBOTTOM ? GAPSOUT + MONITOR->vecReservedBottomRight.y : GAPSIN);

    TEMPEFFECTIVEPOS = TEMPEFFECTIVEPOS + Vector2D(BORDERSIZE, BORDERSIZE);
    TEMPEFFECTIVESIZE = TEMPEFFECTIVESIZE - (Vector2D(BORDERSIZE, BORDERSIZE) * 2);

    // do gaps, set top left
    TEMPEFFECTIVEPOS = TEMPEFFECTIVEPOS + OFFSETTOPLEFT;
    // fix to old size bottom right
    TEMPEFFECTIVESIZE = TEMPEFFECTIVESIZE - OFFSETTOPLEFT;
    // set bottom right
    TEMPEFFECTIVESIZE = TEMPEFFECTIVESIZE - OFFSETBOTTOMRIGHT;

    if (pWindow->getIsPseudotiled()) {
        float scale = 1;

        // adjust if doesnt fit
        if (pWindow->getPseudoSize().x > TEMPEFFECTIVESIZE.x || pWindow->getPseudoSize().y > TEMPEFFECTIVESIZE.y) {
            
            if (pWindow->getPseudoSize().x > TEMPEFFECTIVESIZE.x) {
                scale = TEMPEFFECTIVESIZE.x / pWindow->getPseudoSize().x;
            }

            if (pWindow->getPseudoSize().y * scale > TEMPEFFECTIVESIZE.y) {
                scale = TEMPEFFECTIVESIZE.y / pWindow->getPseudoSize().y;
            }

            auto DELTA = TEMPEFFECTIVESIZE - pWindow->getPseudoSize() * scale;
            TEMPEFFECTIVESIZE = pWindow->getPseudoSize() * scale;
            TEMPEFFECTIVEPOS = TEMPEFFECTIVEPOS + DELTA / 2.f;  // center
        } else {
            auto DELTA = TEMPEFFECTIVESIZE - pWindow->getPseudoSize();
            TEMPEFFECTIVEPOS = TEMPEFFECTIVEPOS + DELTA / 2.f;  // center
            TEMPEFFECTIVESIZE = pWindow->getPseudoSize();
        }
    }

    if (pWindow->getWorkspaceID() == SCRATCHPAD_ID) {
        TEMPEFFECTIVEPOS = TEMPEFFECTIVEPOS + ((TEMPEFFECTIVESIZE - TEMPEFFECTIVESIZE * 0.75f) * 0.5f);
        TEMPEFFECTIVESIZE = TEMPEFFECTIVESIZE * 0.75f;

        setAWindowTop(pWindow->getDrawable());
    }

    if (pWindow->getFullscreen()) {
        TEMPEFFECTIVEPOS = MONITOR->vecPosition;
        TEMPEFFECTIVESIZE = MONITOR->vecSize;
    }

    pWindow->setEffectivePosition(TEMPEFFECTIVEPOS);
    pWindow->setEffectiveSize(TEMPEFFECTIVESIZE);
}

CWindow* CWindowManager::findWindowAtCursor() {
    Vector2D cursorPos = getCursorPos();

    if (!getMonitorFromCursor())
        return nullptr;

    const auto WORKSPACE = activeWorkspaces[getMonitorFromCursor()->ID];

    for (auto& window : windows) {
        if (window.getWorkspaceID() == WORKSPACE && !window.getIsFloating() && window.getDrawable() > 0 && window.getConstructed() && window.getWorkspaceID() != SCRATCHPAD_ID) {

            if (cursorPos.x >= window.getPosition().x 
                && cursorPos.x <= window.getPosition().x + window.getSize().x
                && cursorPos.y >= window.getPosition().y
                && cursorPos.y <= window.getPosition().y + window.getSize().y) {

                return &window;
            }
        }
    }

    return nullptr;
}

CWindow* CWindowManager::findFirstWindowOnWorkspace(const int& work) {
    for (auto& w : windows) {
        if (w.getWorkspaceID() == work && !w.getIsFloating() && !w.getNoInterventions() && w.getDrawable() > 0) {
            return &w;
        }
    }

    return nullptr;
}

CWindow* CWindowManager::findPreferredOnScratchpad() {
    Vector2D topSize;
    CWindow* pTop = nullptr;

    for (auto& w : windows) {
        if (w.getWorkspaceID() == SCRATCHPAD_ID && w.getDrawable() > 0 && w.getConstructed()) {
            if (w.getSize().x * w.getSize().y > topSize.x * topSize.y) {
                topSize = w.getSize();
                pTop = &w;
            }
        }
    }

    return pTop;
}

void CWindowManager::calculateNewTileSetOldTile(CWindow* pWindow) {
    
    // Get the parent and both children, one of which will be pWindow
    const auto PPARENT = getWindowFromDrawable(pWindow->getParentNodeID());

    auto PMONITOR = getMonitorFromWindow(pWindow);
    if (!PMONITOR) {
        Debug::log(ERR, "Monitor was nullptr! (calculateNewTileSetOldTile) using 0.");
        PMONITOR = &monitors[0];

        if (monitors.size() == 0) {
            Debug::log(ERR, "Not continuing. Monitors size 0.");
            return;
        } 
    }

    if (!PPARENT) {
        // New window on this workspace.
        // Open a fullscreen window.

        pWindow->setSize(Vector2D(PMONITOR->vecSize.x, PMONITOR->vecSize.y));
        pWindow->setPosition(Vector2D(PMONITOR->vecPosition.x, PMONITOR->vecPosition.y));

        return;
    }


    switch (ConfigManager::getInt("layout"))
    {
    case LAYOUT_DWINDLE:
        {
            // Get the sibling
            const auto PSIBLING = getWindowFromDrawable(PPARENT->getChildNodeAID() == pWindow->getDrawable() ? PPARENT->getChildNodeBID() : PPARENT->getChildNodeAID());

            // Should NEVER be null
            if (PSIBLING) {
                const auto PLASTSIZE = PPARENT->getSize();
                const auto PLASTPOS = PPARENT->getPosition();
                if (PLASTSIZE.x > PLASTSIZE.y) {
                    PSIBLING->setPosition(Vector2D(PLASTPOS.x, PLASTPOS.y));
                    PSIBLING->setSize(Vector2D(PLASTSIZE.x / 2.f, PLASTSIZE.y));
                    pWindow->setSize(Vector2D(PLASTSIZE.x / 2.f, PLASTSIZE.y));
                    pWindow->setPosition(Vector2D(PLASTPOS.x + PLASTSIZE.x / 2.f, PLASTPOS.y));
                } else {
                    PSIBLING->setPosition(Vector2D(PLASTPOS.x, PLASTPOS.y));
                    PSIBLING->setSize(Vector2D(PLASTSIZE.x, PLASTSIZE.y / 2.f));
                    pWindow->setSize(Vector2D(PLASTSIZE.x, PLASTSIZE.y / 2.f));
                    pWindow->setPosition(Vector2D(PLASTPOS.x, PLASTPOS.y + PLASTSIZE.y / 2.f));
                }

                PSIBLING->setDirty(true);
            } else {
                Debug::log(ERR, "Sibling node was null?? pWindow x,y,w,h: " + std::to_string(pWindow->getPosition().x) + " " + std::to_string(pWindow->getPosition().y) + " " + std::to_string(pWindow->getSize().x) + " " + std::to_string(pWindow->getSize().y));
            }
        }
        break;
    
    case LAYOUT_MASTER:
        {
            recalcEntireWorkspace(pWindow->getWorkspaceID());
        }
        break;
    }
}

int CWindowManager::getWindowsOnWorkspace(const int& workspace) {
    int number = 0;
    for (auto& w : windows) {
        if (w.getWorkspaceID() == workspace && w.getDrawable() > 0 && !w.getDock()) {
            ++number;
        }
    }

    return number;
}

SMonitor* CWindowManager::getMonitorFromWorkspace(const int& workspace) {
    int monitorID = -1;
    for (auto& work : workspaces) {
        if (work.getID() == workspace) {
            monitorID = work.getMonitor();
            break;
        }
    }

    for (auto& monitor : monitors) {
        if (monitor.ID == monitorID) {
            return &monitor;
        }
    }

    return nullptr;
}

void CWindowManager::recalcEntireWorkspace(const int& workspace) {

    switch (ConfigManager::getInt("layout"))
    {
    case LAYOUT_MASTER:
        {
            // Get the monitor
            const auto PMONITOR = getMonitorFromWorkspace(workspace);

            // first, calc the size
            CWindow* pMaster = nullptr;
            for (auto& w : windows) {
                if (w.getWorkspaceID() == workspace && w.getMaster() && !w.getDead() && !w.getIsFloating() && !w.getDock()) {
                    pMaster = &w;
                    break;
                }
            }

            CWindow* pMasterContainer = nullptr;
            for (auto& w : windows) {
                if (w.getWorkspaceID() == workspace && w.getParentNodeID() == 0 && !w.getIsFloating() && !w.getDock()) {
                    pMasterContainer = &w;
                    break;
                }
            }

            if (!pMaster) {
                Debug::log(ERR, "No master found on workspace???");
                return;
            }

            // set the xy for master
            float splitRatio = 1;
            if (pMasterContainer)
                splitRatio = pMasterContainer->getSplitRatio();

            pMaster->setPosition(Vector2D(0, 0) + PMONITOR->vecPosition);
            pMaster->setSize(Vector2D(PMONITOR->vecSize.x / 2 * splitRatio, PMONITOR->vecSize.y));

            // get children sorted
            std::vector<CWindow*> children;
            for (auto& w : windows) {
                if (w.getWorkspaceID() == workspace && !w.getMaster() && w.getDrawable() > 0 && !w.getDead() && !w.getDock())
                    children.push_back(&w);
            }
            std::sort(children.begin(), children.end(), [](CWindow*& a, CWindow*& b) {
                return a->getMasterChildIndex() < b->getMasterChildIndex();
            });

            // if no children, master full
            if (children.size() == 0) {
                pMaster->setPosition(Vector2D(0, 0) + PMONITOR->vecPosition);
                pMaster->setSize(Vector2D(PMONITOR->vecSize.x, PMONITOR->vecSize.y));
            }

            // Children sorted, set xy
            int yoff = 0;
            for (const auto& child : children) {
                child->setPosition(Vector2D(PMONITOR->vecSize.x / 2 * splitRatio, yoff) + PMONITOR->vecPosition);
                child->setSize(Vector2D(PMONITOR->vecSize.x / 2 * (2 - splitRatio), PMONITOR->vecSize.y / children.size()));

                yoff += PMONITOR->vecSize.y / children.size();
            }

            // done
            setAllWorkspaceWindowsDirtyByID(workspace);
        }
        break;

    case LAYOUT_DWINDLE:
        {
            // get the master on the workspace
            CWindow* pMasterWindow = nullptr;
            for (auto& w : windows) {
                if (w.getWorkspaceID() == workspace && w.getParentNodeID() == 0 && !w.getIsFloating() && !w.getDock()) {
                    pMasterWindow = &w;
                    break;
                }
            }

            if (!pMasterWindow)
                return;

            const auto PMONITOR = getMonitorFromWorkspace(workspace);

            if (!PMONITOR)
                return;

            Debug::log(LOG, "Recalc for workspace " + std::to_string(workspace));

            pMasterWindow->setSize(PMONITOR->vecSize);
            pMasterWindow->setPosition(PMONITOR->vecPosition);

            pMasterWindow->recalcSizePosRecursive();
            setAllWorkspaceWindowsDirtyByID(workspace);
        }
        break;
    
    default:
        break;
    }
    
}

void CWindowManager::calculateNewFloatingWindow(CWindow* pWindow) {
    if (!pWindow)
        return;

    if (!pWindow->getNoInterventions() && !pWindow->getDock()) {
        pWindow->setPosition(pWindow->getEffectivePosition() + Vector2D(3,3));
        pWindow->setSize(pWindow->getEffectiveSize() - Vector2D(6, 6));

        // min size
        pWindow->setSize(Vector2D(std::clamp(pWindow->getSize().x, (double)40, (double)99999),
                                  std::clamp(pWindow->getSize().y, (double)40, (double)99999)));

        pWindow->setEffectivePosition(pWindow->getPosition() + Vector2D(10, 10));
        pWindow->setEffectiveSize(pWindow->getSize());

        pWindow->setRealPosition(pWindow->getPosition());
        pWindow->setRealSize(pWindow->getSize());
    }

    Values[0] = XCB_STACK_MODE_ABOVE;
    xcb_configure_window(DisplayConnection, pWindow->getDrawable(), XCB_CONFIG_WINDOW_STACK_MODE, Values);
}

void CWindowManager::calculateNewWindowParams(CWindow* pWindow) {
    // And set old one's if needed.
    if (!pWindow)
        return;

    if (!pWindow->getIsFloating()) {
        calculateNewTileSetOldTile(pWindow);
    } else {
        calculateNewFloatingWindow(pWindow);
    }

    setEffectiveSizePosUsingConfig(pWindow);

    pWindow->setDirty(true);
}

bool CWindowManager::isNeighbor(CWindow* a, CWindow* b) {

    if (a->getWorkspaceID() != b->getWorkspaceID())
        return false; // Different workspaces

    const auto POSA = a->getPosition();
    const auto POSB = b->getPosition();
    const auto SIZEA = a->getSize();
    const auto SIZEB = b->getSize();

    if (POSA.x != 0) {
        if (STICKS(POSA.x, (POSB.x + SIZEB.x))) {
            return true;
        }
    }
    if (POSA.y != 0) {
        if (STICKS(POSA.y, (POSB.y + SIZEB.y))) {
            return true;
        }
    }

    if (POSB.x != 0) {
        if (STICKS(POSB.x, (POSA.x + SIZEA.x))) {
            return true;
        }
    }
    if (POSB.y != 0) {
        if (STICKS(POSB.y, (POSA.y + SIZEA.y))) {
            return true;
        }
    }

    return false;
}

bool CWindowManager::canEatWindow(CWindow* a, CWindow* toEat) {
    // Pos is min of both.
    const auto POSAFTEREAT = Vector2D(std::min(a->getPosition().x, toEat->getPosition().x), std::min(a->getPosition().y, toEat->getPosition().y));

    // Size is pos + size max - pos
    const auto OPPCORNERA = Vector2D(POSAFTEREAT) + a->getSize();
    const auto OPPCORNERB = toEat->getPosition() + toEat->getSize();

    const auto SIZEAFTEREAT = Vector2D(std::max(OPPCORNERA.x, OPPCORNERB.x), std::max(OPPCORNERA.y, OPPCORNERB.y)) - POSAFTEREAT;

    const auto doOverlap = [&](CWindow* b) {
        const auto RIGHT1 = Vector2D(POSAFTEREAT.x + SIZEAFTEREAT.x, POSAFTEREAT.y + SIZEAFTEREAT.y);
        const auto RIGHT2 = b->getPosition() + b->getSize();
        const auto LEFT1 = POSAFTEREAT;
        const auto LEFT2 = b->getPosition();

        return !(LEFT1.x >= RIGHT2.x || LEFT2.x >= RIGHT1.x || LEFT1.y >= RIGHT2.y || LEFT2.y >= RIGHT1.y);
    };

    for (auto& w : windows) {
        if (w.getDrawable() == a->getDrawable() || w.getDrawable() == toEat->getDrawable() || w.getWorkspaceID() != toEat->getWorkspaceID()
            || w.getIsFloating() || getMonitorFromWindow(&w) != getMonitorFromWindow(toEat))
            continue;

        if (doOverlap(&w))
            return false;
    }

    return true;
}

void CWindowManager::eatWindow(CWindow* a, CWindow* toEat) {

    // Size is pos + size max - pos
    const auto OPPCORNERA = a->getPosition() + a->getSize();
    const auto OPPCORNERB = toEat->getPosition() + toEat->getSize();

    // Pos is min of both.
    a->setPosition(Vector2D(std::min(a->getPosition().x, toEat->getPosition().x), std::min(a->getPosition().y, toEat->getPosition().y)));

    a->setSize(Vector2D(std::max(OPPCORNERA.x, OPPCORNERB.x), std::max(OPPCORNERA.y, OPPCORNERB.y)) - a->getPosition());
}

void CWindowManager::closeWindowAllChecks(int64_t id) {
    // fix last window if tile
    const auto CLOSEDWINDOW = g_pWindowManager->getWindowFromDrawable(id);

    if (!CLOSEDWINDOW)
        return; // It's not in the vec, ignore. (weird)

    CLOSEDWINDOW->setDead(true);

    if (CLOSEDWINDOW->getWorkspaceID() != SCRATCHPAD_ID && scratchpadActive)
        scratchpadActive = false;

    if (const auto WORKSPACE = getWorkspaceByID(CLOSEDWINDOW->getWorkspaceID()); WORKSPACE && CLOSEDWINDOW->getFullscreen())
        WORKSPACE->setHasFullscreenWindow(false);

    if (!CLOSEDWINDOW->getIsFloating())
        g_pWindowManager->fixWindowOnClose(CLOSEDWINDOW);
    
    const bool WASDOCK = CLOSEDWINDOW->getDock();

    // Mirror image of addWindowToVectorSafe()'s own Damage creation - free
    // the X resource before this window's own tracking entry is gone,
    // since nothing else ever gets a chance to clean it up otherwise.
    if (g_pWindowManager->CompositingEnabled && CLOSEDWINDOW->getDamageObject()) {
        xcb_damage_destroy(g_pWindowManager->DisplayConnection, CLOSEDWINDOW->getDamageObject());
        CLOSEDWINDOW->setDamageObject(0);
    }

    // delete off of the arr
    g_pWindowManager->removeWindowFromVectorSafe(id);

    // Fix docks
    if (WASDOCK)
        g_pWindowManager->recalcAllDocks();
}

CWindow* CWindowManager::getMasterForWorkspace(const int& work) {
    CWindow* pMaster = nullptr;
    for (auto& w : windows) {
        if (w.getWorkspaceID() == work && w.getMaster()) {
            pMaster = &w;
            break;
        }
    }

    if (!pMaster) {
        Debug::log(ERR, "No master found on workspace? Setting automatically");
        for (auto& w : windows) {
            if (w.getWorkspaceID() == work && !w.getDock() && !w.getIsFloating()) {
                pMaster = &w;
                w.setMaster(true);
                break;
            }
        }
    }

    return pMaster;
}

void CWindowManager::fixMasterWorkspaceOnClosed(CWindow* pWindow) {

    getMasterForWorkspace(pWindow->getWorkspaceID()); // to fix if no master

    // get children sorted
    std::vector<CWindow*> children;
    for (auto& w : windows) {
        if (w.getWorkspaceID() == pWindow->getWorkspaceID() && !w.getMaster() && w.getDrawable() > 0 && w.getDrawable() != pWindow->getDrawable() && !w.getDock())
            children.push_back(&w);
    }
    std::sort(children.begin(), children.end(), [](CWindow*& a, CWindow*& b) {
        return a->getMasterChildIndex() < b->getMasterChildIndex();
    });

    // If closed window was master, set a new master.
    if (pWindow->getMaster()) {
        if (children.size() > 0) {
            children[0]->setMaster(true);
        }
    } else {
        // else fix the indices
        for (long unsigned int i = pWindow->getMasterChildIndex() - 1; i < children.size(); ++i) {
            // masterChildIndex = 1 for the first child
            children[i]->setMasterChildIndex(i);
        }
    }
}

void CWindowManager::fixWindowOnClose(CWindow* pClosedWindow) {
    if (!pClosedWindow)
        return;

    // Get the parent and both children, one of which will be pWindow
    const auto PPARENT = getWindowFromDrawable(pClosedWindow->getParentNodeID());

    if (!PPARENT) 
        return; // if there was no parent, we do not need to update anything. it was a fullscreen window, the only one on a given workspace.

    // Get the sibling
    const auto PSIBLING = getWindowFromDrawable(PPARENT->getChildNodeAID() == pClosedWindow->getDrawable() ? PPARENT->getChildNodeBID() : PPARENT->getChildNodeAID());

    if (!PSIBLING) {
        Debug::log(ERR, "No sibling found in fixOnClose! (Corrupted tree...?)");
        return;
    }

    // used by master layout
    pClosedWindow->setDead(true);

    // FIX TREE ----
    // make the sibling replace the parent
    PSIBLING->setPosition(PPARENT->getPosition());
    PSIBLING->setSize(PPARENT->getSize());
    PSIBLING->setParentNodeID(PPARENT->getParentNodeID());

    if (PPARENT->getParentNodeID() != 0
        && getWindowFromDrawable(PPARENT->getParentNodeID())) {
            if (getWindowFromDrawable(PPARENT->getParentNodeID())->getChildNodeAID() == PPARENT->getDrawable()) {
                getWindowFromDrawable(PPARENT->getParentNodeID())->setChildNodeAID(PSIBLING->getDrawable());
            } else {
                getWindowFromDrawable(PPARENT->getParentNodeID())->setChildNodeBID(PSIBLING->getDrawable());
            }
    }
    // TREE FIXED ----

    // Fix master stuff
    const auto WORKSPACE = pClosedWindow->getWorkspaceID();
    fixMasterWorkspaceOnClosed(pClosedWindow);

    // recalc the workspace
    if (ConfigManager::getInt("layout") == LAYOUT_MASTER)
        recalcEntireWorkspace(WORKSPACE);
    else {
        PSIBLING->recalcSizePosRecursive();
        PSIBLING->setDirtyRecursive(true);
    }
        
    // Remove the parent
    removeWindowFromVectorSafe(PPARENT->getDrawable());

    if (findWindowAtCursor())
        setFocusedWindow(findWindowAtCursor()->getDrawable());  // Set focus. :)
}

CWindow* CWindowManager::getNeighborInDir(char dir) {

    const auto CURRENTWINDOW = getWindowFromDrawable(LastWindow);

    if (!CURRENTWINDOW)
        return nullptr;

    const auto POSA = CURRENTWINDOW->getPosition();
    const auto SIZEA = CURRENTWINDOW->getSize();

    auto longestIntersect = -1;
    CWindow* longestIntersectWindow = nullptr;

    for (auto& w : windows) {
        if (w.getDrawable() == CURRENTWINDOW->getDrawable() || w.getDrawable() < 1 || w.getIsFloating() || !isWorkspaceVisible(w.getWorkspaceID()))
            continue;

        const auto POSB = w.getPosition();
        const auto SIZEB = w.getSize();

        switch (dir) {
            case 'l':
                if (STICKS(POSA.x, POSB.x + SIZEB.x)) {
                    const auto INTERSECTLEN = std::max((double)0, std::min(POSA.y + SIZEA.y, POSB.y + SIZEB.y) - std::max(POSA.y, POSB.y));
                    if (INTERSECTLEN > longestIntersect) {
                        longestIntersect = INTERSECTLEN;
                        longestIntersectWindow = &w;
                    }       
                }
                break;
            case 'r':
                if (STICKS(POSA.x + SIZEA.x, POSB.x)) {
                    const auto INTERSECTLEN = std::max((double)0, std::min(POSA.y + SIZEA.y, POSB.y + SIZEB.y) - std::max(POSA.y, POSB.y));
                    if (INTERSECTLEN > longestIntersect) {
                        longestIntersect = INTERSECTLEN;
                        longestIntersectWindow = &w;
                    }
                }
                break;
            case 't':
            case 'u':
                if (STICKS(POSA.y, POSB.y + SIZEB.y)) {
                    const auto INTERSECTLEN = std::max((double)0, std::min(POSA.x + SIZEA.x, POSB.x + SIZEB.x) - std::max(POSA.x, POSB.x));
                    if (INTERSECTLEN > longestIntersect) {
                        longestIntersect = INTERSECTLEN;
                        longestIntersectWindow = &w;
                    }
                }
                break;
            case 'b':
            case 'd':
                if (STICKS(POSA.y + SIZEA.y, POSB.y)) {
                    const auto INTERSECTLEN = std::max((double)0, std::min(POSA.x + SIZEA.x, POSB.x + SIZEB.x) - std::max(POSA.x, POSB.x));
                    if (INTERSECTLEN > longestIntersect) {
                        longestIntersect = INTERSECTLEN;
                        longestIntersectWindow = &w;
                    }
                }
                break;
        }
    }

    if (longestIntersect != -1)
        return longestIntersectWindow;

    return nullptr;
}

void CWindowManager::warpCursorTo(Vector2D to) {
    const auto POINTERCOOKIE = xcb_query_pointer(DisplayConnection, Screen->root);

    xcb_query_pointer_reply_t* pointerreply = xcb_query_pointer_reply(DisplayConnection, POINTERCOOKIE, NULL);
    if (!pointerreply) {
        Debug::log(ERR, "Couldn't query pointer.");
        free(pointerreply);
        return;
    }

    xcb_warp_pointer(DisplayConnection, XCB_NONE, Screen->root, 0, 0, Screen->width_in_pixels, Screen->height_in_pixels, (int)to.x, (int)to.y);
    free(pointerreply);
}

void CWindowManager::moveActiveWindowToRelativeWorkspace(int relativenum) {
    if (activeWorkspaceID + relativenum < 1) return;
    moveActiveWindowToWorkspace(activeWorkspaceID + relativenum);
}

void CWindowManager::moveActiveWindowToWorkspace(int workspace) {

    auto PWINDOW = getWindowFromDrawable(LastWindow);

    if (!PWINDOW)
        return;

    if (PWINDOW->getWorkspaceID() == workspace)
        return;

    Debug::log(LOG, "Moving active window to " + std::to_string(workspace));

    const auto SAVEDDEFAULTSIZE = PWINDOW->getDefaultSize();
    const auto SAVEDFLOATSTATUS = PWINDOW->getIsFloating();
    const auto SAVEDDRAWABLE    = PWINDOW->getDrawable();

    // remove current workspace's fullscreen status if fullscreen
    if (PWINDOW->getFullscreen()) {
        const auto PWORKSPACE = getWorkspaceByID(PWINDOW->getWorkspaceID());
        if (PWORKSPACE) {
            PWORKSPACE->setHasFullscreenWindow(false);
        }
    }

    fixWindowOnClose(PWINDOW);
    // deque reallocated
    LastWindow = SAVEDDRAWABLE;
    PWINDOW = getWindowFromDrawable(LastWindow);
    PWINDOW->setDead(false);

    const auto WORKSPACE = getWorkspaceByID(PWINDOW->getWorkspaceID());

    auto workspacesBefore = activeWorkspaces;

    if (WORKSPACE && PWINDOW->getFullscreen())
        WORKSPACE->setHasFullscreenWindow(false);

    changeWorkspaceByID(workspace);

    // Find new mon
    int NEWMONITOR = 0;
    for (long unsigned int i = 0; i < activeWorkspaces.size(); ++i) {
        if (workspace == SCRATCHPAD_ID) {
            if (monitors[i].ID == ConfigManager::getInt("scratchpad_mon"))
                NEWMONITOR = i;
        }
        else if (activeWorkspaces[i] == workspace) {
            NEWMONITOR = i;
        }
    }

    // Find the first window on the new workspace
    xcb_drawable_t newLastWindow = 0;
    for (auto& w : windows) {
        if (w.getDrawable() > 0 && w.getWorkspaceID() == workspace && !w.getIsFloating()) {
            newLastWindow = w.getDrawable();
            break;
        }
    }

    const auto LASTFOCUS = LastWindow;

    if (newLastWindow) {
        setFocusedWindow(newLastWindow);
    }

    PWINDOW->setConstructed(false);

    if (SAVEDFLOATSTATUS && workspace != SCRATCHPAD_ID)
        Events::remapFloatingWindow(PWINDOW->getDrawable(), NEWMONITOR);
    else
        Events::remapWindow(PWINDOW->getDrawable(), false, NEWMONITOR);

    PWINDOW->setConstructed(true);

    // fix for scratchpad
    PWINDOW->setWorkspaceID(workspace);

    // fix fullscreen status
    const auto PWORKSPACE = getWorkspaceByID(workspace);
    if (PWORKSPACE) {
        // Should NEVER be false but let's be sure
        PWORKSPACE->setHasFullscreenWindow(PWINDOW->getFullscreen());
    }

    PWINDOW->setDefaultSize(SAVEDDEFAULTSIZE);

    if (workspace == SCRATCHPAD_ID) {
        for (int i = 0; i < activeWorkspaces.size(); ++i) {
            changeWorkspaceByID(workspacesBefore[i]);
        }

        changeWorkspaceByID(WORKSPACE->getID());
        setFocusedWindow(LASTFOCUS);
    }

    QueuedPointerWarp = Vector2D(-1,-1);
}

void CWindowManager::moveActiveWindowTo(char dir) {
    const auto CURRENTWINDOW = getWindowFromDrawable(LastWindow);

    if (!CURRENTWINDOW)
        return;

    const auto neighbor = getNeighborInDir(dir);

    if (!neighbor)
        return;

    // swap their stuff and mark dirty
    const auto TEMP_SIZEA = CURRENTWINDOW->getSize();
    const auto TEMP_POSA = CURRENTWINDOW->getPosition();

    CURRENTWINDOW->setSize(neighbor->getSize());
    CURRENTWINDOW->setPosition(neighbor->getPosition());

    neighbor->setSize(TEMP_SIZEA);
    neighbor->setPosition(TEMP_POSA);

    CURRENTWINDOW->setDirty(true);
    neighbor->setDirty(true);

    // Fix the tree
    if (CURRENTWINDOW->getParentNodeID() != 0) {
        const auto PPARENT = getWindowFromDrawable(CURRENTWINDOW->getParentNodeID());
        if (!PPARENT) {
            Debug::log(ERR, "No parent node ID despite non-null???");
            return;
        }

        if (PPARENT->getChildNodeAID() == CURRENTWINDOW->getDrawable())
            PPARENT->setChildNodeAID(neighbor->getDrawable());
        else
            PPARENT->setChildNodeBID(neighbor->getDrawable());
    }

    if (neighbor->getParentNodeID() != 0) {
        const auto PPARENT = getWindowFromDrawable(neighbor->getParentNodeID());
        if (!PPARENT) {
            Debug::log(ERR, "No parent node ID despite non-null???");
            return;
        }

        if (PPARENT->getChildNodeAID() == neighbor->getDrawable())
            PPARENT->setChildNodeAID(CURRENTWINDOW->getDrawable());
        else
            PPARENT->setChildNodeBID(CURRENTWINDOW->getDrawable());
    }

    const auto PARENTC = CURRENTWINDOW->getParentNodeID();

    CURRENTWINDOW->setParentNodeID(neighbor->getParentNodeID());
    neighbor->setParentNodeID(PARENTC);

    // Fix the master layout
    const auto SMASTER = CURRENTWINDOW->getMaster();
    const auto SINDEX  = CURRENTWINDOW->getMasterChildIndex();
    
    CURRENTWINDOW->setMasterChildIndex(neighbor->getMasterChildIndex());
    CURRENTWINDOW->setMaster(neighbor->getMaster());

    neighbor->setMaster(SMASTER);
    neighbor->setMasterChildIndex(SINDEX);
        

    // finish by moving the cursor to the new current window
    QueuedPointerWarp = Vector2D(CURRENTWINDOW->getPosition() + CURRENTWINDOW->getSize() / 2.f);
}

CWindow* CWindowManager::getFullscreenWindowByWorkspace(const int& id) {
    for (auto& window : windows) {
        if (window.getWorkspaceID() == id && window.getFullscreen() && window.getDrawable() > 0)
            return &window;
    }

    return nullptr;
}

void CWindowManager::moveActiveFocusTo(char dir) {
    const auto CURRENTWINDOW = getWindowFromDrawable(LastWindow);

    if (!CURRENTWINDOW)
        return;

    const auto PWORKSPACE = getWorkspaceByID(CURRENTWINDOW->getWorkspaceID());

    if (!PWORKSPACE)
        return;

    const auto NEIGHBOR = PWORKSPACE->getHasFullscreenWindow() ? getFullscreenWindowByWorkspace(PWORKSPACE->getID()) : getNeighborInDir(dir);

    if (!NEIGHBOR)
        return;

    // move the focus
    setFocusedWindow(NEIGHBOR->getDrawable());

    // finish by moving the cursor to the neighbor window
    QueuedPointerWarp = Vector2D(NEIGHBOR->getPosition() + (NEIGHBOR->getSize() / 2.f));
}

void CWindowManager::changeWorkspaceByID(int ID) {
    auto MONITOR = getMonitorFromCursor();

    if (!MONITOR) {
        Debug::log(ERR, "Monitor was nullptr! (changeWorkspaceByID) Using monitor 0.");
        MONITOR = &monitors[0];
    }

    // Don't change if already opened
    if (isWorkspaceVisible(ID)) {
        Debug::log(LOG, "Workspace visible, only focus.");
        focusOnWorkspace(ID);
        return;
    }
        

    // mark old workspace dirty
    setAllWorkspaceWindowsDirtyByID(activeWorkspaces[MONITOR->ID]);

    // save old workspace for animation
    auto OLDWORKSPACE = activeWorkspaces[MONITOR->ID];
    lastActiveWorkspaceID = OLDWORKSPACE;

    for (auto& workspace : workspaces) {
        if (workspace.getID() == ID) {
            Debug::log(LOG, "Workspace open, bringing to active.");

            // set workspaces dirty
            setAllWorkspaceWindowsDirtyByID(ID);

            // pull the workspace onto the currently focused monitor (global workspace pool)
            const bool MOVEDMONITORS = workspace.getMonitor() != MONITOR->ID;
            workspace.setMonitor(MONITOR->ID);
            activeWorkspaces[MONITOR->ID] = workspace.getID();

            if (MOVEDMONITORS)
                recalcEntireWorkspace(ID);

            // if not fullscreen set the focus to any window on that workspace
            // if fullscreen, set to the fullscreen window
            focusOnWorkspace(ID);

            activeWorkspaceID = ID;

            // Wipe animation
            startWipeAnimOnWorkspace(OLDWORKSPACE, ID);
            
            return;
        }
    }

    Debug::log(LOG, "New workspace, creating.");

    // If we are here it means the workspace is new. Let's create it.
    CWorkspace newWorkspace;
    newWorkspace.setID(ID);
    newWorkspace.setMonitor(MONITOR->ID);
    workspaces.push_back(newWorkspace);
    activeWorkspaces[MONITOR->ID] = workspaces[workspaces.size() - 1].getID();
    LastWindow = -1;

    activeWorkspaceID = ID;

    // Wipe animation
    startWipeAnimOnWorkspace(OLDWORKSPACE, ID);

    Debug::log(LOG, "New workspace created.");

    if (getMonitorFromCursor() && MONITOR->ID != getMonitorFromCursor()->ID)
        QueuedPointerWarp = Vector2D(MONITOR->vecPosition + MONITOR->vecSize / 2.f);

    // no need for the new dirty, it's empty
}

void CWindowManager::changeToLastWorkspace() {
    changeWorkspaceByID(lastActiveWorkspaceID);
}

void CWindowManager::focusOnWorkspace(const int& work) {
    const auto PWORKSPACE = getWorkspaceByID(work);
    const auto PMONITOR = getMonitorFromWorkspace(work);

    Debug::log(LOG, "Focusing on workspace " + std::to_string(work));

    if (!PMONITOR) {
        Debug::log(ERR, "Orphaned workspace at focusOnWorkspace ???");
        return;
    }

    if (PWORKSPACE) {
        if (!PWORKSPACE->getHasFullscreenWindow()) {
            Debug::log(LOG, "No fullscreen window");
            bool shouldHopToScreen = true;
            for (auto& window : windows) {
                if (window.getWorkspaceID() == work && window.getDrawable() > 0) {
                    setFocusedWindow(window.getDrawable());

                    Debug::log(LOG, "Queueing the warp");

                    const auto PMONITORFROMCURSOR = getMonitorFromCursor();

                    if (PMONITORFROMCURSOR)
                        Debug::log(LOG, "Monitor from cursor: " + std::to_string(PMONITORFROMCURSOR->ID));

                    if (PMONITORFROMCURSOR && PMONITORFROMCURSOR->ID != PMONITOR->ID)
                        QueuedPointerWarp = Vector2D(window.getPosition() + window.getSize() / 2.f);

                    shouldHopToScreen = false;
                    Debug::log(LOG, "No hopping to new workspace");
                    break;
                }
            }

            Debug::log(LOG, "Queueing a hop if needed.");

            if (shouldHopToScreen)
                QueuedPointerWarp = Vector2D(PMONITOR->vecPosition + PMONITOR->vecSize / 2.f);
        } else {
            const auto PFULLWINDOW = getFullscreenWindowByWorkspace(work);
            if (PFULLWINDOW) {
                Debug::log(LOG, "Fullscreen window id " + std::to_string(PFULLWINDOW->getDrawable()));
                setFocusedWindow(PFULLWINDOW->getDrawable());
                
                if (getMonitorFromCursor() && getMonitorFromCursor()->ID != PMONITOR->ID)
                    QueuedPointerWarp = Vector2D(PFULLWINDOW->getPosition() + PFULLWINDOW->getSize() / 2.f);
            }
        }
    }
}

void CWindowManager::setAllWindowsDirty() {
    for (auto& window : windows) {
        window.setDirty(true);
    }
}

void CWindowManager::setAllWorkspaceWindowsDirtyByID(int ID) {
    int workspaceID = -1;
    for (auto& workspace : workspaces) {
        if (workspace.getID() == ID) {
            workspaceID = workspace.getID();
            break;
        }
    }

    if (workspaceID == -1)
        return;

    for (auto& window : windows) {
        if (window.getWorkspaceID() == workspaceID)
            window.setDirty(true);
    }
}

int CWindowManager::getHighestWorkspaceID() {
    int max = -1;
    for (auto& workspace : workspaces) {
        if (workspace.getID() > max) {
            max = workspace.getID();
        }
    }

    return max;
}

CWorkspace* CWindowManager::getWorkspaceByID(int ID) {
    for (auto& workspace : workspaces) {
        if (workspace.getID() == ID) {
            return &workspace;
        }
    }

    return nullptr;
}

SMonitor* CWindowManager::getMonitorFromWindow(CWindow* pWindow) {
    return &monitors[pWindow->getMonitor()];
}

SMonitor* CWindowManager::getMonitorFromCursor() {
    const auto CURSORPOS = getCursorPos();

    for (auto& monitor : monitors) {
        if (VECINRECT(CURSORPOS, monitor.vecPosition.x, monitor.vecPosition.y, monitor.vecPosition.x + monitor.vecSize.x, monitor.vecPosition.y + monitor.vecSize.y))
            return &monitor;
    }

    // should never happen tho, I'm using >= and the cursor cant get outside the screens, i hope.
    return nullptr;
}

Vector2D CWindowManager::getCursorPos() {
    const auto POINTERCOOKIE = xcb_query_pointer(DisplayConnection, Screen->root);

    xcb_query_pointer_reply_t* pointerreply = xcb_query_pointer_reply(DisplayConnection, POINTERCOOKIE, NULL);
    if (!pointerreply) {
        Debug::log(ERR, "Couldn't query pointer.");
        free(pointerreply);
        return Vector2D(0,0);
    }

    const auto CURSORPOS = Vector2D(pointerreply->root_x, pointerreply->root_y);
    free(pointerreply);

    return CURSORPOS;
}

bool CWindowManager::isWorkspaceVisible(int workspaceID) {

    if (workspaceID == SCRATCHPAD_ID)
        return scratchpadActive;

    for (auto& workspace : activeWorkspaces) {
        if (workspace == workspaceID)
            return true;
    }

    return false;
}

void CWindowManager::setAllFloatingWindowsTop() {
    for (auto& window : windows) {
        if (window.getIsFloating() && !window.getTransient()) {
            Values[0] = XCB_STACK_MODE_ABOVE;
            xcb_configure_window(g_pWindowManager->DisplayConnection, window.getDrawable(), XCB_CONFIG_WINDOW_STACK_MODE, Values);

            window.bringTopRecursiveTransients();
        } else {
            window.bringTopRecursiveTransients();
        }
    }
}

void CWindowManager::setAWindowTop(xcb_window_t window) {
    Values[0] = XCB_STACK_MODE_ABOVE;
    const auto COOKIE = xcb_configure_window(g_pWindowManager->DisplayConnection, window, XCB_CONFIG_WINDOW_STACK_MODE, Values);
    Events::ignoredEvents.push_back(COOKIE.sequence);
}

void CWindowManager::reassertAlwaysOnTop() {
    if (alwaysOnTopWindows.empty())
        return;

    for (auto it = alwaysOnTopWindows.begin(); it != alwaysOnTopWindows.end();) {
        const auto ATTRSREPLY = xcb_get_window_attributes_reply(DisplayConnection, xcb_get_window_attributes(DisplayConnection, *it), NULL);

        if (!ATTRSREPLY || ATTRSREPLY->map_state != XCB_MAP_STATE_VIEWABLE) {
            if (ATTRSREPLY)
                free(ATTRSREPLY);
            it = alwaysOnTopWindows.erase(it);
            continue;
        }

        free(ATTRSREPLY);

        // Skip raising this popup if a fullscreen window (a game) is
        // currently active on the same monitor it lives on - per explicit
        // request, always-on-top shouldn't fight a fullscreen window for
        // the top of the stack. Popups always open attached to a specific
        // bar, so their geometry never spans more than one monitor.
        const auto GEOMREPLY = xcb_get_geometry_reply(DisplayConnection, xcb_get_geometry(DisplayConnection, *it), NULL);
        bool coveredByFullscreen = false;

        if (GEOMREPLY) {
            if (const auto MONITOR = getMonitorFromCoord(Vector2D(GEOMREPLY->x, GEOMREPLY->y)); MONITOR) {
                if (const auto WORKSPACE = getWorkspaceByID(activeWorkspaces[MONITOR->ID]); WORKSPACE && WORKSPACE->getHasFullscreenWindow())
                    coveredByFullscreen = true;
            }

            free(GEOMREPLY);
        }

        if (!coveredByFullscreen)
            setAWindowTop(*it);

        ++it;
    }
}

void CWindowManager::compositorRepaint() {
    if (!CompositingEnabled)
        return;

    // Milestone 6: skip the repaint entirely on an idle tick. CompositorDirty
    // gets set from recieveEvent() on literally any real event (see that
    // function's own comment on why broadly, rather than hunting down
    // every visually-relevant event type individually) - but window-move/
    // resize *animations* don't necessarily generate a fresh X event every
    // single tick on their own (the position is interpolated and pushed
    // via xcb_configure_window from AnimationUtil::move(), which doesn't
    // itself route back through recieveEvent()), so an animation actively
    // in progress needs its own explicit check here or it would visually
    // freeze mid-slide the moment CompositorDirty happened to already be
    // false for that tick.
    if (!CompositorDirty) {
        bool anyAnimating = false;

        for (auto& w : windows) {
            if (w.getIsAnimated()) {
                anyAnimating = true;
                break;
            }
        }

        if (!anyAnimating)
            return;
    }

    CompositorDirty = false;

    // Milestone 2's GL path when it's actually up, otherwise milestone 1b's
    // plain XRender path - see the member declarations in windowManager.hpp
    // for why both are kept rather than the GL path fully replacing the
    // other.
    if (GLReady)
        compositorRepaintGL();
    else
        compositorRepaintXRender();
}

void CWindowManager::compositorRepaintXRender() {
    // Ground-truth, real-time stacking order straight from the X server,
    // bottom-to-top - not our own `windows` deque, which isn't guaranteed to
    // mirror true X11 stacking order and doesn't track override-redirect
    // popups (the Bar, Settings, etc.) at all.
    const auto TREEREPLY = xcb_query_tree_reply(DisplayConnection, xcb_query_tree(DisplayConnection, Screen->root), NULL);

    if (!TREEREPLY)
        return;

    const auto CHILDREN   = xcb_query_tree_children(TREEREPLY);
    const int  CHILDCOUNT = xcb_query_tree_children_length(TREEREPLY);

    // Cached internally after the first call (see setupManager()) - this is
    // not a fresh round trip every tick.
    const auto FORMATS = xcb_render_util_query_formats(DisplayConnection);

    for (int i = 0; i < CHILDCOUNT; ++i) {
        const xcb_window_t WIN = CHILDREN[i];

        const auto ATTRSREPLY = xcb_get_window_attributes_reply(DisplayConnection, xcb_get_window_attributes(DisplayConnection, WIN), NULL);

        if (!ATTRSREPLY)
            continue;

        if (ATTRSREPLY->map_state != XCB_MAP_STATE_VIEWABLE) {
            free(ATTRSREPLY);
            continue;
        }

        const auto VISUALFORMAT = FORMATS ? xcb_render_util_find_visual_format(FORMATS, ATTRSREPLY->visual) : nullptr;

        free(ATTRSREPLY);

        if (!VISUALFORMAT)
            continue;

        const auto GEOMREPLY = xcb_get_geometry_reply(DisplayConnection, xcb_get_geometry(DisplayConnection, WIN), NULL);

        if (!GEOMREPLY)
            continue;

        // Re-fetched fresh every repaint instead of cached long-term: a
        // Picture tied to a stale pixmap shows garbage the moment the X
        // server reallocates the backing pixmap on resize. A real cache
        // (only re-fetching on Damage/Configure) is Milestone 6's job, once
        // there's an actual performance problem to justify the complexity.
        const xcb_pixmap_t PIXMAP = xcb_generate_id(DisplayConnection);
        xcb_composite_name_window_pixmap(DisplayConnection, WIN, PIXMAP);

        const xcb_render_picture_t PICTURE = xcb_generate_id(DisplayConnection);
        xcb_render_create_picture(DisplayConnection, PICTURE, PIXMAP, VISUALFORMAT->format, 0, NULL);

        // PICT_OP_SRC (overwrite), not OVER (alpha blend): every window is
        // treated as fully opaque for now, which looks identical to OVER
        // for the opaque case that covers virtually everything today. Real
        // blending only starts to matter once later milestones (shadows,
        // blur) introduce genuine translucent content.
        xcb_render_composite(DisplayConnection, XCB_RENDER_PICT_OP_SRC, PICTURE, XCB_NONE, RootPicture, 0, 0, 0, 0,
                              GEOMREPLY->x, GEOMREPLY->y, GEOMREPLY->width, GEOMREPLY->height);

        xcb_render_free_picture(DisplayConnection, PICTURE);
        xcb_free_pixmap(DisplayConnection, PIXMAP);

        free(GEOMREPLY);
    }

    free(TREEREPLY);

    xcb_flush(DisplayConnection);
}

// Xlib's own default error handler prints the error and then calls exit() -
// fine for a simple Xlib app, fatal for a WM, where a GL/GLX mistake taking
// down the entire desktop session is a much bigger deal than XCB's own
// calls ever risk (XCB never crashes the process on a protocol error by
// itself). Installed process-wide (Xlib only supports one global handler,
// there's no per-Display variant) the moment Xlib enters the picture at
// all, so any future GLX mistake here logs and degrades instead of killing
// the whole WM - the same "never let compositing break the desktop"
// principle every other compositor-only code path already follows.
static int zarisXlibErrorHandler(Display* display, XErrorEvent* error) {
    char errorText[256];
    XGetErrorText(display, error->error_code, errorText, sizeof(errorText));
    Debug::log(ERR, "Xlib error (compositor GL path): " + std::string(errorText) + " (request code " +
                         std::to_string(error->request_code) + ", minor " + std::to_string(error->minor_code) + ")");
    return 0;
}

// Milestone 3: an anti-aliased rounded-rectangle test, done per-fragment
// against the window's own local pixel position rather than the old
// milestone-1b/2 hard XShape clip (see applyShapeToWindow()'s own updated
// comment - that clip is skipped entirely once GLReady, specifically so
// the client's real, uncut rectangular content reaches this shader intact).
// GLSL 1.10 (OpenGL 2.0) targeted deliberately, since it's the one version
// guaranteed to exist alongside the legacy/fixed-function immediate-mode
// vertex submission (glBegin/glVertex2f) the rest of this compositor still
// uses - gl_MultiTexCoord1 carries each vertex's own LOCAL pixel position
// (0,0 to window width,height) so the fragment shader can compute distance
// to the nearest rounded corner without needing gl_FragCoord's own screen-
// space/window-space orientation quirks. The rounded-box signed-distance
// formula itself (roundedBoxSDF below) is a standard, widely-published
// graphics technique (popularized by Inigo Quilez's own distance-function
// articles), not anything specific to any particular compositor's own
// source - written here from the general technique, matching this
// project's own licensing note in ROADMAP.md about not porting picom's
// actual shader code.
static const char* ZARIS_GL_VERTEX_SHADER = R"glsl(
varying vec2 vTexCoord;
varying vec2 vLocalPos;
void main() {
    vTexCoord = gl_MultiTexCoord0.xy;
    vLocalPos = gl_MultiTexCoord1.xy;
    gl_Position = ftransform();
}
)glsl";

static const char* ZARIS_GL_FRAGMENT_SHADER = R"glsl(
uniform sampler2D tex;
uniform vec2 winSize;
uniform float radius;
varying vec2 vTexCoord;
varying vec2 vLocalPos;

float roundedBoxSDF(vec2 p, vec2 halfSize, float r) {
    vec2 d = abs(p - halfSize) - halfSize + vec2(r, r);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2(0.0, 0.0))) - r;
}

void main() {
    vec4 texColor = texture2D(tex, vTexCoord);
    float dist = roundedBoxSDF(vLocalPos, winSize * 0.5, radius);
    float alpha = 1.0 - smoothstep(-1.0, 1.0, dist);
    // texColor.rgb arrives already premultiplied by texColor.a - Quickshell/
    // Qt's own ARGB32 rendering (and X11/XRender's ARGB32 convention more
    // generally) both use premultiplied alpha, confirmed live this
    // milestone via a direct pixel readback of the real Bar's own redirected
    // pixmap at a reduced backgroundOpacity (a near-black, heavily-darkened
    // RGB at low alpha - exactly what premultiplication produces, not raw
    // "straight" alpha). Multiplying by the corner-rounding `alpha` too
    // extends that same premultiplication to cover this second, independent
    // alpha source, so the two compose correctly together - see
    // glBlendFunc's own comment in compositorRepaintGL() for the matching
    // half of this fix.
    gl_FragColor = vec4(texColor.rgb * alpha, texColor.a * alpha);
}
)glsl";

// Milestone 4's drop shadow: the same rounded-box SDF as above (distance
// to the window's own true rounded-rect boundary - winSize/radius here
// are the window's real size/corner radius, not the larger shadow quad's
// own), just with no texture sampling and a much wider smoothstep band
// (`blur`) standing in for a soft Gaussian falloff - shares the same
// vertex shader (ZARIS_GL_VERTEX_SHADER), so vLocalPos already means the
// same thing here: local pixel position relative to the window's own
// top-left corner, just extending beyond (0,0)-(winSize) out into the
// shadow's own wider margin (see compositorRepaintGL()'s shadow quad).
static const char* ZARIS_GL_SHADOW_FRAGMENT_SHADER = R"glsl(
uniform vec2 winSize;
uniform float radius;
uniform float blur;
uniform vec4 shadowColor;
varying vec2 vLocalPos;

float roundedBoxSDF(vec2 p, vec2 halfSize, float r) {
    vec2 d = abs(p - halfSize) - halfSize + vec2(r, r);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2(0.0, 0.0))) - r;
}

void main() {
    float dist = roundedBoxSDF(vLocalPos, winSize * 0.5, radius);
    float alpha = 1.0 - smoothstep(-blur, blur, dist);
    // Premultiplied output, matching the window shader's own fix (see its
    // comment) and the blend func in compositorRepaintGL() - shadowColor.rgb
    // is a plain, non-premultiplied uniform here, so it needs multiplying
    // by the *total* alpha (shadowColor.a * alpha) itself, not just by
    // `alpha` alone the way the window shader multiplies its already-
    // premultiplied texColor.rgb by `alpha` alone.
    float totalAlpha = shadowColor.a * alpha;
    gl_FragColor = vec4(shadowColor.rgb * totalAlpha, totalAlpha);
}
)glsl";

// Milestone 5: dual-kawase background blur - a real, if modest (3 levels
// rather than the 5-6 a full implementation might use, an explicit
// scoping choice, not an oversight - see this milestone's own ROADMAP.md
// writeup), implementation of the technique popularized by Marius
// Bjørge's "Bandwidth-Efficient Rendering" (ARM, 2015): alternating
// downsample/upsample passes through a small chain of progressively
// halved-resolution render targets, each pass sampling a specific
// 4-or-8-tap offset pattern rather than a naive box blur, approximating a
// much larger real Gaussian blur far more cheaply than actually computing
// one. A standard, widely-reproduced public technique (used by KWin,
// Godot, and plenty of independent tutorials/blog posts, not picom-
// specific) - written here from the general public description of the
// algorithm, per this file's own licensing note on not porting any
// specific compositor's actual shader source. `halfpixel` is half a
// source texel's size in the destination's own normalized [0,1] texture
// space - the specific offset pattern (as opposed to a plain box blur's
// evenly-spaced grid) is what gives dual-kawase its characteristic soft,
// natural-looking falloff at a fraction of a real Gaussian's cost.
static const char* ZARIS_GL_BLUR_DOWNSAMPLE_FRAGMENT_SHADER = R"glsl(
uniform sampler2D tex;
uniform vec2 halfpixel;
varying vec2 vTexCoord;

void main() {
    vec4 sum = texture2D(tex, vTexCoord) * 4.0;
    sum += texture2D(tex, vTexCoord - halfpixel);
    sum += texture2D(tex, vTexCoord + halfpixel);
    sum += texture2D(tex, vTexCoord + vec2(halfpixel.x, -halfpixel.y));
    sum += texture2D(tex, vTexCoord - vec2(halfpixel.x, -halfpixel.y));
    gl_FragColor = sum / 8.0;
}
)glsl";

static const char* ZARIS_GL_BLUR_UPSAMPLE_FRAGMENT_SHADER = R"glsl(
uniform sampler2D tex;
uniform vec2 halfpixel;
varying vec2 vTexCoord;

void main() {
    vec4 sum = texture2D(tex, vTexCoord + vec2(-halfpixel.x * 2.0, 0.0));
    sum += texture2D(tex, vTexCoord + vec2(-halfpixel.x, halfpixel.y)) * 2.0;
    sum += texture2D(tex, vTexCoord + vec2(0.0, halfpixel.y * 2.0));
    sum += texture2D(tex, vTexCoord + vec2(halfpixel.x, halfpixel.y)) * 2.0;
    sum += texture2D(tex, vTexCoord + vec2(halfpixel.x * 2.0, 0.0));
    sum += texture2D(tex, vTexCoord + vec2(halfpixel.x, -halfpixel.y)) * 2.0;
    sum += texture2D(tex, vTexCoord + vec2(0.0, -halfpixel.y * 2.0));
    sum += texture2D(tex, vTexCoord + vec2(-halfpixel.x, -halfpixel.y)) * 2.0;
    gl_FragColor = sum / 12.0;
}
)glsl";

// Returns 0 (and logs why) on failure rather than throwing/aborting -
// compositorSetupGL() treats that as just another reason GLReady should
// stay false, same as every other setup step.
static GLuint compileShader(GLenum type, const char* source) {
    const GLuint SHADER = g_pWindowManager->glCreateShaderFn(type);
    g_pWindowManager->glShaderSourceFn(SHADER, 1, &source, NULL);
    g_pWindowManager->glCompileShaderFn(SHADER);

    GLint success = GL_FALSE;
    g_pWindowManager->glGetShaderivFn(SHADER, GL_COMPILE_STATUS, &success);

    if (!success) {
        char log[512];
        g_pWindowManager->glGetShaderInfoLogFn(SHADER, sizeof(log), NULL, log);
        Debug::log(ERR, "compositorSetupGL: shader compile failed: " + std::string(log));
        g_pWindowManager->glDeleteShaderFn(SHADER);
        return 0;
    }

    return SHADER;
}

void CWindowManager::compositorSetupGL() {
    // Every early-return below leaves GLReady false, which means
    // compositorRepaint() keeps using the already-proven XRender path -
    // a GL setup failure here is a graceful step down, not a broken
    // compositor. GLDisplay is deliberately a brand new, independent Xlib
    // connection (not sharing DisplayConnection) so nothing here can affect
    // the WM's own main event loop even if something below goes wrong.
    XSetErrorHandler(zarisXlibErrorHandler);

    GLDisplay = XOpenDisplay(NULL);

    if (!GLDisplay) {
        Debug::log(ERR, "compositorSetupGL: XOpenDisplay failed - GL compositing stays disabled.");
        return;
    }

    const int SCREENNUM = DefaultScreen(GLDisplay);

    int glxMajor = 0, glxMinor = 0;
    if (!glXQueryVersion(GLDisplay, &glxMajor, &glxMinor) || (glxMajor < 1) || (glxMajor == 1 && glxMinor < 3)) {
        Debug::log(ERR, "compositorSetupGL: GLX 1.3+ required, got " + std::to_string(glxMajor) + "." + std::to_string(glxMinor) +
                             " - GL compositing stays disabled.");
        return;
    }

    const std::string GLXEXTENSIONS = glXQueryExtensionsString(GLDisplay, SCREENNUM);
    if (GLXEXTENSIONS.find("GLX_EXT_texture_from_pixmap") == std::string::npos) {
        Debug::log(ERR, "compositorSetupGL: GLX_EXT_texture_from_pixmap not advertised - GL compositing stays disabled.");
        return;
    }

    glXBindTexImageEXTFn    = (PFNGLXBINDTEXIMAGEEXTPROC)glXGetProcAddressARB((const GLubyte*)"glXBindTexImageEXT");
    glXReleaseTexImageEXTFn = (PFNGLXRELEASETEXIMAGEEXTPROC)glXGetProcAddressARB((const GLubyte*)"glXReleaseTexImageEXT");

    if (!glXBindTexImageEXTFn || !glXReleaseTexImageEXTFn) {
        Debug::log(ERR, "compositorSetupGL: could not resolve glXBindTexImageEXT/glXReleaseTexImageEXT - GL compositing stays disabled.");
        return;
    }

    // Milestone 3's shader entry points - see their own declarations in
    // windowManager.hpp for why these need resolving manually at all.
    glCreateShaderFn       = (PFNGLCREATESHADERPROC)glXGetProcAddressARB((const GLubyte*)"glCreateShader");
    glShaderSourceFn       = (PFNGLSHADERSOURCEPROC)glXGetProcAddressARB((const GLubyte*)"glShaderSource");
    glCompileShaderFn      = (PFNGLCOMPILESHADERPROC)glXGetProcAddressARB((const GLubyte*)"glCompileShader");
    glGetShaderivFn        = (PFNGLGETSHADERIVPROC)glXGetProcAddressARB((const GLubyte*)"glGetShaderiv");
    glGetShaderInfoLogFn   = (PFNGLGETSHADERINFOLOGPROC)glXGetProcAddressARB((const GLubyte*)"glGetShaderInfoLog");
    glDeleteShaderFn       = (PFNGLDELETESHADERPROC)glXGetProcAddressARB((const GLubyte*)"glDeleteShader");
    glCreateProgramFn      = (PFNGLCREATEPROGRAMPROC)glXGetProcAddressARB((const GLubyte*)"glCreateProgram");
    glAttachShaderFn       = (PFNGLATTACHSHADERPROC)glXGetProcAddressARB((const GLubyte*)"glAttachShader");
    glLinkProgramFn        = (PFNGLLINKPROGRAMPROC)glXGetProcAddressARB((const GLubyte*)"glLinkProgram");
    glGetProgramivFn       = (PFNGLGETPROGRAMIVPROC)glXGetProcAddressARB((const GLubyte*)"glGetProgramiv");
    glGetProgramInfoLogFn  = (PFNGLGETPROGRAMINFOLOGPROC)glXGetProcAddressARB((const GLubyte*)"glGetProgramInfoLog");
    glDeleteProgramFn      = (PFNGLDELETEPROGRAMPROC)glXGetProcAddressARB((const GLubyte*)"glDeleteProgram");
    glUseProgramFn         = (PFNGLUSEPROGRAMPROC)glXGetProcAddressARB((const GLubyte*)"glUseProgram");
    glGetUniformLocationFn = (PFNGLGETUNIFORMLOCATIONPROC)glXGetProcAddressARB((const GLubyte*)"glGetUniformLocation");
    glUniform1iFn          = (PFNGLUNIFORM1IPROC)glXGetProcAddressARB((const GLubyte*)"glUniform1i");
    glUniform1fFn          = (PFNGLUNIFORM1FPROC)glXGetProcAddressARB((const GLubyte*)"glUniform1f");
    glUniform2fFn          = (PFNGLUNIFORM2FPROC)glXGetProcAddressARB((const GLubyte*)"glUniform2f");
    glUniform4fFn          = (PFNGLUNIFORM4FPROC)glXGetProcAddressARB((const GLubyte*)"glUniform4f");

    if (!glCreateShaderFn || !glShaderSourceFn || !glCompileShaderFn || !glGetShaderivFn || !glGetShaderInfoLogFn ||
        !glDeleteShaderFn || !glCreateProgramFn || !glAttachShaderFn || !glLinkProgramFn || !glGetProgramivFn ||
        !glGetProgramInfoLogFn || !glDeleteProgramFn || !glUseProgramFn || !glGetUniformLocationFn || !glUniform1iFn ||
        !glUniform1fFn || !glUniform2fFn || !glUniform4fFn) {
        Debug::log(ERR, "compositorSetupGL: could not resolve one or more GLSL 2.0 entry points - GL compositing stays disabled.");
        return;
    }

    // Milestone 5's FBO entry points, for the blur render-to-texture chain.
    glGenFramebuffersFn        = (PFNGLGENFRAMEBUFFERSPROC)glXGetProcAddressARB((const GLubyte*)"glGenFramebuffers");
    glBindFramebufferFn        = (PFNGLBINDFRAMEBUFFERPROC)glXGetProcAddressARB((const GLubyte*)"glBindFramebuffer");
    glFramebufferTexture2DFn   = (PFNGLFRAMEBUFFERTEXTURE2DPROC)glXGetProcAddressARB((const GLubyte*)"glFramebufferTexture2D");
    glCheckFramebufferStatusFn = (PFNGLCHECKFRAMEBUFFERSTATUSPROC)glXGetProcAddressARB((const GLubyte*)"glCheckFramebufferStatus");
    glDeleteFramebuffersFn     = (PFNGLDELETEFRAMEBUFFERSPROC)glXGetProcAddressARB((const GLubyte*)"glDeleteFramebuffers");

    if (!glGenFramebuffersFn || !glBindFramebufferFn || !glFramebufferTexture2DFn || !glCheckFramebufferStatusFn || !glDeleteFramebuffersFn) {
        Debug::log(ERR, "compositorSetupGL: could not resolve one or more FBO entry points - GL compositing stays disabled.");
        return;
    }

    int              numConfigs  = 0;
    const auto       CONFIGS     = glXGetFBConfigs(GLDisplay, SCREENNUM, &numConfigs);
    GLXFBConfig      rootConfig  = nullptr;

    if (!CONFIGS || numConfigs == 0) {
        Debug::log(ERR, "compositorSetupGL: glXGetFBConfigs returned nothing - GL compositing stays disabled.");
        return;
    }

    for (int i = 0; i < numConfigs; ++i) {
        const auto CONFIG = CONFIGS[i];

        int visualID = 0, drawableType = 0, renderType = 0;
        glXGetFBConfigAttrib(GLDisplay, CONFIG, GLX_VISUAL_ID, &visualID);
        glXGetFBConfigAttrib(GLDisplay, CONFIG, GLX_DRAWABLE_TYPE, &drawableType);
        glXGetFBConfigAttrib(GLDisplay, CONFIG, GLX_RENDER_TYPE, &renderType);

        if (visualID == 0 || !(renderType & GLX_RGBA_BIT))
            continue;

        // The on-screen destination config: must be able to back a real
        // GLXWindow and match the root window's own already-fixed visual
        // (an X window's visual can't be changed after creation, so this
        // is the only config that could ever work for wrapping root).
        if (!rootConfig && (drawableType & GLX_WINDOW_BIT) && (xcb_visualid_t)visualID == Screen->root_visual)
            rootConfig = CONFIG;

        // Per-visual configs usable for texture-from-pixmap binding later,
        // one per distinct visual any client window might actually use.
        if (!(drawableType & GLX_PIXMAP_BIT) || GLFBConfigsByVisual.count((xcb_visualid_t)visualID))
            continue;

        int bindRGBA = 0, bindRGB = 0, targets = 0, yInverted = 0;
        glXGetFBConfigAttrib(GLDisplay, CONFIG, GLX_BIND_TO_TEXTURE_RGBA_EXT, &bindRGBA);
        glXGetFBConfigAttrib(GLDisplay, CONFIG, GLX_BIND_TO_TEXTURE_RGB_EXT, &bindRGB);
        glXGetFBConfigAttrib(GLDisplay, CONFIG, GLX_BIND_TO_TEXTURE_TARGETS_EXT, &targets);
        glXGetFBConfigAttrib(GLDisplay, CONFIG, GLX_Y_INVERTED_EXT, &yInverted);

        if (!(targets & GLX_TEXTURE_2D_BIT_EXT) || (!bindRGBA && !bindRGB))
            continue;

        SGLTexFromPixmapConfig ENTRY;
        ENTRY.fbconfig      = CONFIG;
        ENTRY.textureFormat = bindRGBA ? GLX_TEXTURE_FORMAT_RGBA_EXT : GLX_TEXTURE_FORMAT_RGB_EXT;
        ENTRY.yInverted     = yInverted != 0;

        GLFBConfigsByVisual[(xcb_visualid_t)visualID] = ENTRY;
    }

    if (!rootConfig) {
        Debug::log(ERR, "compositorSetupGL: no GLXFBConfig matches the root window's own visual - GL compositing stays disabled.");
        XFree(CONFIGS);
        GLFBConfigsByVisual.clear();
        return;
    }

    GLContext = glXCreateNewContext(GLDisplay, rootConfig, GLX_RGBA_TYPE, NULL, True);

    if (!GLContext) {
        Debug::log(ERR, "compositorSetupGL: glXCreateNewContext failed - GL compositing stays disabled.");
        XFree(CONFIGS);
        GLFBConfigsByVisual.clear();
        return;
    }

    GLWindow = glXCreateWindow(GLDisplay, rootConfig, Screen->root, NULL);

    if (!GLWindow) {
        Debug::log(ERR, "compositorSetupGL: glXCreateWindow (wrapping root) failed - GL compositing stays disabled.");
        glXDestroyContext(GLDisplay, GLContext);
        GLContext = nullptr;
        XFree(CONFIGS);
        GLFBConfigsByVisual.clear();
        return;
    }

    if (!glXMakeContextCurrent(GLDisplay, GLWindow, GLWindow, GLContext)) {
        Debug::log(ERR, "compositorSetupGL: glXMakeContextCurrent failed - GL compositing stays disabled.");
        glXDestroyWindow(GLDisplay, GLWindow);
        glXDestroyContext(GLDisplay, GLContext);
        GLWindow  = 0;
        GLContext = nullptr;
        XFree(CONFIGS);
        GLFBConfigsByVisual.clear();
        return;
    }

    const auto GLVERSTR = glGetString(GL_VERSION);
    const auto GLRENDSTR = glGetString(GL_RENDERER);
    Debug::log(LOG, "compositorSetupGL: GL ready. Version: " + std::string(GLVERSTR ? (const char*)GLVERSTR : "?") +
                         ", Renderer: " + std::string(GLRENDSTR ? (const char*)GLRENDSTR : "?"));

    // Milestone 3: the rounded-corner shader. Failure here disables the
    // whole GL path (falls back to milestone 1b's XRender passthrough,
    // same as every other GL setup failure above) rather than limping on
    // with plain rectangular corners - keeps this function's own
    // all-or-nothing simplicity rather than needing a second, partial
    // "GLReady but no rounding" state.
    const GLuint VERTEXSHADER = compileShader(GL_VERTEX_SHADER, ZARIS_GL_VERTEX_SHADER);
    const GLuint FRAGMENTSHADER = VERTEXSHADER ? compileShader(GL_FRAGMENT_SHADER, ZARIS_GL_FRAGMENT_SHADER) : 0;

    // Milestone 4's shadow fragment shader and milestone 5's two blur
    // fragment shaders all share this same vertex shader (see each one's
    // own comment) - compiled here, attached to all four programs below,
    // and only deleted once every link is done, rather than right after
    // the first program links it.
    const GLuint SHADOWFRAGMENTSHADER    = (VERTEXSHADER && FRAGMENTSHADER) ? compileShader(GL_FRAGMENT_SHADER, ZARIS_GL_SHADOW_FRAGMENT_SHADER) : 0;
    const GLuint BLURDOWNFRAGMENTSHADER  = SHADOWFRAGMENTSHADER ? compileShader(GL_FRAGMENT_SHADER, ZARIS_GL_BLUR_DOWNSAMPLE_FRAGMENT_SHADER) : 0;
    const GLuint BLURUPFRAGMENTSHADER    = BLURDOWNFRAGMENTSHADER ? compileShader(GL_FRAGMENT_SHADER, ZARIS_GL_BLUR_UPSAMPLE_FRAGMENT_SHADER) : 0;

    if (!VERTEXSHADER || !FRAGMENTSHADER || !SHADOWFRAGMENTSHADER || !BLURDOWNFRAGMENTSHADER || !BLURUPFRAGMENTSHADER) {
        if (VERTEXSHADER)
            glDeleteShaderFn(VERTEXSHADER);
        if (FRAGMENTSHADER)
            glDeleteShaderFn(FRAGMENTSHADER);
        if (SHADOWFRAGMENTSHADER)
            glDeleteShaderFn(SHADOWFRAGMENTSHADER);
        if (BLURDOWNFRAGMENTSHADER)
            glDeleteShaderFn(BLURDOWNFRAGMENTSHADER);
        if (BLURUPFRAGMENTSHADER)
            glDeleteShaderFn(BLURUPFRAGMENTSHADER);
        XFree(CONFIGS);
        GLFBConfigsByVisual.clear();
        return;
    }

    GLShaderProgram = glCreateProgramFn();
    glAttachShaderFn(GLShaderProgram, VERTEXSHADER);
    glAttachShaderFn(GLShaderProgram, FRAGMENTSHADER);
    glLinkProgramFn(GLShaderProgram);

    GLShadowShaderProgram = glCreateProgramFn();
    glAttachShaderFn(GLShadowShaderProgram, VERTEXSHADER);
    glAttachShaderFn(GLShadowShaderProgram, SHADOWFRAGMENTSHADER);
    glLinkProgramFn(GLShadowShaderProgram);

    GLBlurDownsampleProgram = glCreateProgramFn();
    glAttachShaderFn(GLBlurDownsampleProgram, VERTEXSHADER);
    glAttachShaderFn(GLBlurDownsampleProgram, BLURDOWNFRAGMENTSHADER);
    glLinkProgramFn(GLBlurDownsampleProgram);

    GLBlurUpsampleProgram = glCreateProgramFn();
    glAttachShaderFn(GLBlurUpsampleProgram, VERTEXSHADER);
    glAttachShaderFn(GLBlurUpsampleProgram, BLURUPFRAGMENTSHADER);
    glLinkProgramFn(GLBlurUpsampleProgram);

    GLint linked = GL_FALSE, shadowLinked = GL_FALSE, blurDownLinked = GL_FALSE, blurUpLinked = GL_FALSE;
    glGetProgramivFn(GLShaderProgram, GL_LINK_STATUS, &linked);
    glGetProgramivFn(GLShadowShaderProgram, GL_LINK_STATUS, &shadowLinked);
    glGetProgramivFn(GLBlurDownsampleProgram, GL_LINK_STATUS, &blurDownLinked);
    glGetProgramivFn(GLBlurUpsampleProgram, GL_LINK_STATUS, &blurUpLinked);
    glDeleteShaderFn(VERTEXSHADER);
    glDeleteShaderFn(FRAGMENTSHADER);
    glDeleteShaderFn(SHADOWFRAGMENTSHADER);
    glDeleteShaderFn(BLURDOWNFRAGMENTSHADER);
    glDeleteShaderFn(BLURUPFRAGMENTSHADER);

    if (!linked || !shadowLinked || !blurDownLinked || !blurUpLinked) {
        char log[512];
        const GLuint FAILEDPROGRAM = !linked ? GLShaderProgram : !shadowLinked ? GLShadowShaderProgram : !blurDownLinked ? GLBlurDownsampleProgram : GLBlurUpsampleProgram;
        glGetProgramInfoLogFn(FAILEDPROGRAM, sizeof(log), NULL, log);
        Debug::log(ERR, "compositorSetupGL: shader link failed: " + std::string(log) + " - GL compositing stays disabled.");
        glDeleteProgramFn(GLShaderProgram);
        glDeleteProgramFn(GLShadowShaderProgram);
        glDeleteProgramFn(GLBlurDownsampleProgram);
        glDeleteProgramFn(GLBlurUpsampleProgram);
        GLShaderProgram         = 0;
        GLShadowShaderProgram   = 0;
        GLBlurDownsampleProgram = 0;
        GLBlurUpsampleProgram   = 0;
        XFree(CONFIGS);
        GLFBConfigsByVisual.clear();
        return;
    }

    GLUniformTex     = glGetUniformLocationFn(GLShaderProgram, "tex");
    GLUniformWinSize = glGetUniformLocationFn(GLShaderProgram, "winSize");
    GLUniformRadius  = glGetUniformLocationFn(GLShaderProgram, "radius");

    GLShadowUniformWinSize = glGetUniformLocationFn(GLShadowShaderProgram, "winSize");
    GLShadowUniformRadius  = glGetUniformLocationFn(GLShadowShaderProgram, "radius");
    GLShadowUniformBlur    = glGetUniformLocationFn(GLShadowShaderProgram, "blur");
    GLShadowUniformColor   = glGetUniformLocationFn(GLShadowShaderProgram, "shadowColor");

    GLBlurDownsampleUniformTex  = glGetUniformLocationFn(GLBlurDownsampleProgram, "tex");
    GLBlurDownsampleUniformHalf = glGetUniformLocationFn(GLBlurDownsampleProgram, "halfpixel");
    GLBlurUpsampleUniformTex    = glGetUniformLocationFn(GLBlurUpsampleProgram, "tex");
    GLBlurUpsampleUniformHalf   = glGetUniformLocationFn(GLBlurUpsampleProgram, "halfpixel");

    // One-time snapshot of whatever's currently on the root window - the
    // wallpaper, drawn there before compositing ever started - to redraw
    // as every frame's base layer. See GLBackgroundTexture's own comment
    // in windowManager.hpp for why this is needed now that corners are
    // genuinely partially transparent, unlike milestones 1b/2.
    //
    // Deliberately grabbed via a plain Xlib XGetImage, not glCopyTexImage2D
    // from the just-created GLXWindow - caught live while verifying this
    // milestone: with a solid, known root color set for the test, the
    // "captured" background rendered back as solid black instead. Milestone
    // 2's own bug (this same GLXWindow needing an explicit glXSwapBuffers to
    // ever show anything) already proved this drawable isn't a simple alias
    // onto root's real on-screen storage on this software (llvmpipe) GL
    // stack - it's backed by its own separate buffer that starts blank
    // until the first real swap. Reading root's actual pixels straight over
    // XCB/Xlib instead sidesteps that GL-buffer-aliasing question entirely.
    const auto ROOTIMAGE = XGetImage(GLDisplay, Screen->root, 0, 0, Screen->width_in_pixels, Screen->height_in_pixels, AllPlanes, ZPixmap);

    glGenTextures(1, &GLBackgroundTexture);
    glBindTexture(GL_TEXTURE_2D, GLBackgroundTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    if (ROOTIMAGE) {
        // BGRA: the standard in-memory byte order for a 32-bit ZPixmap on
        // this kind of little-endian X server/GL combination - matches
        // what every other window's own texture-from-pixmap binding
        // already assumes implicitly (RGBA/RGB via GLX_TEXTURE_FORMAT_EXT).
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, Screen->width_in_pixels, Screen->height_in_pixels, 0, GL_BGRA, GL_UNSIGNED_BYTE, ROOTIMAGE->data);
        XDestroyImage(ROOTIMAGE);
    } else {
        Debug::log(ERR, "compositorSetupGL: XGetImage on root failed - background snapshot will render blank.");
    }

    // A GLX context can only be current on one thread at a time - this
    // setup runs on the main thread, but compositorRepaintGL() runs on the
    // separate tick thread (see Events::handle()), so the main thread must
    // release it here before that thread can ever bind it. Skipping this
    // was a real bug caught while verifying this milestone: the tick
    // thread's own glXMakeContextCurrent call failed with a BadAccess X
    // error, which - before the error handler above was installed - was
    // fatal to the entire WM via Xlib's default error handler.
    glXMakeContextCurrent(GLDisplay, None, None, NULL);

    XFree(CONFIGS);
    GLReady = true;
}

void CWindowManager::compositorDrawBlurBehind(float x, float y, float w, float h, float radius, int screenW, int screenH) {
    // Too small to meaningfully blur, and guards the halving loop below
    // from ever reaching a degenerate 0-sized level.
    if (w < 4.f || h < 4.f)
        return;

    // The caller (compositorRepaintGL()) leaves GL_BLEND enabled across
    // this whole call (needed for the shadow/window draws immediately
    // before and after it) - but every downsample/upsample pass below
    // renders into a *freshly allocated* FBO texture (glTexImage2D with
    // NULL data, so its initial content is undefined per the GL spec), and
    // blending a draw onto genuinely undefined memory is a real bug, not
    // just untidy. Disabled for the whole chain (a plain overwrite is
    // exactly what every pass here wants anyway) and restored before
    // returning, since the caller expects blending still on afterward.
    glDisable(GL_BLEND);

    // Capture whatever's already been drawn to the screen within this
    // rect so far this frame (the background, plus every lower-stacked
    // window already drawn this same frame) - a real GL read of the
    // buffer this exact draw call sequence is actively rendering into,
    // which is a completely different situation from milestone 3's own
    // background-snapshot bug (that one read an on-screen GLXWindow
    // buffer before anything had ever been drawn to it at all, right
    // after context creation; this one reads content from earlier in the
    // very same frame's own draw sequence, well after real drawing into
    // that buffer has already happened).
    GLuint captureTex = 0;
    glGenTextures(1, &captureTex);
    glBindTexture(GL_TEXTURE_2D, captureTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // glCopyTexImage2D's (x,y) is the LOWER-LEFT corner in window-system
    // (bottom-left-origin) coordinates - x,y here are top-left/X11-style
    // like everywhere else in this compositor, so the Y needs flipping
    // against the screen height.
    glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, (int)x, screenH - (int)(y + h), (int)w, (int)h, 0);

    // A real, if modest (3 levels, not the 5-6 a full implementation
    // might use - an explicit scoping choice, see this milestone's own
    // ROADMAP.md writeup), dual-kawase chain: downsample 3 times, then
    // upsample back up 3 times. Every level's texture/FBO is created and
    // torn down fresh every call (every blur-behind window, every frame)
    // - the same "simplicity over performance for now" tradeoff every
    // other per-frame allocation in this compositor already makes; a
    // real persistent cache is milestone 6's job.
    constexpr int LEVELS = 3;
    int           levelW[LEVELS + 1], levelH[LEVELS + 1];
    levelW[0] = (int)w;
    levelH[0] = (int)h;

    for (int i = 1; i <= LEVELS; ++i) {
        levelW[i] = levelW[i - 1] / 2;
        levelH[i] = levelH[i - 1] / 2;
        if (levelW[i] < 1)
            levelW[i] = 1;
        if (levelH[i] < 1)
            levelH[i] = 1;
    }

    GLuint downTex[LEVELS + 1] = {0};
    GLuint downFBO[LEVELS + 1] = {0};
    downTex[0]                 = captureTex;
    bool ok                    = true;

    for (int i = 1; i <= LEVELS && ok; ++i) {
        glGenTextures(1, &downTex[i]);
        glBindTexture(GL_TEXTURE_2D, downTex[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, levelW[i], levelH[i], 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);

        glGenFramebuffersFn(1, &downFBO[i]);
        glBindFramebufferFn(GL_FRAMEBUFFER, downFBO[i]);
        glFramebufferTexture2DFn(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, downTex[i], 0);

        if (glCheckFramebufferStatusFn(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            ok = false;
            break;
        }

        glViewport(0, 0, levelW[i], levelH[i]);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, levelW[i], levelH[i], 0, -1, 1);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        glUseProgramFn(GLBlurDownsampleProgram);
        glUniform1iFn(GLBlurDownsampleUniformTex, 0);
        glUniform2fFn(GLBlurDownsampleUniformHalf, 0.5f / (float)levelW[i - 1], 0.5f / (float)levelH[i - 1]);
        glBindTexture(GL_TEXTURE_2D, downTex[i - 1]);

        glBegin(GL_QUADS);
        glTexCoord2f(0.f, 0.f); glVertex2f(0, 0);
        glTexCoord2f(1.f, 0.f); glVertex2f((float)levelW[i], 0);
        glTexCoord2f(1.f, 1.f); glVertex2f((float)levelW[i], (float)levelH[i]);
        glTexCoord2f(0.f, 1.f); glVertex2f(0, (float)levelH[i]);
        glEnd();
    }

    GLuint upTex[LEVELS] = {0};
    GLuint upFBO[LEVELS] = {0};
    GLuint prevTex       = downTex[LEVELS];
    int    prevW = levelW[LEVELS], prevH = levelH[LEVELS];

    for (int i = LEVELS - 1; i >= 0 && ok; --i) {
        glGenTextures(1, &upTex[i]);
        glBindTexture(GL_TEXTURE_2D, upTex[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, levelW[i], levelH[i], 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);

        glGenFramebuffersFn(1, &upFBO[i]);
        glBindFramebufferFn(GL_FRAMEBUFFER, upFBO[i]);
        glFramebufferTexture2DFn(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, upTex[i], 0);

        if (glCheckFramebufferStatusFn(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            ok = false;
            break;
        }

        glViewport(0, 0, levelW[i], levelH[i]);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, levelW[i], levelH[i], 0, -1, 1);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        glUseProgramFn(GLBlurUpsampleProgram);
        glUniform1iFn(GLBlurUpsampleUniformTex, 0);
        glUniform2fFn(GLBlurUpsampleUniformHalf, 0.5f / (float)prevW, 0.5f / (float)prevH);
        glBindTexture(GL_TEXTURE_2D, prevTex);

        glBegin(GL_QUADS);
        glTexCoord2f(0.f, 0.f); glVertex2f(0, 0);
        glTexCoord2f(1.f, 0.f); glVertex2f((float)levelW[i], 0);
        glTexCoord2f(1.f, 1.f); glVertex2f((float)levelW[i], (float)levelH[i]);
        glTexCoord2f(0.f, 1.f); glVertex2f(0, (float)levelH[i]);
        glEnd();

        prevTex = upTex[i];
        prevW   = levelW[i];
        prevH   = levelH[i];
    }

    // Restore state for the main pass this was called from the middle of -
    // including GL_BLEND, disabled at the top of this function for the
    // downsample/upsample chain's own draws (see that comment) but needed
    // again both for the final blurred quad drawn just below (its captured
    // content is opaque RGB with an implicit alpha of 1 everywhere except
    // at the rounded edge, so blending it in lets that edge blend smoothly
    // against the shadow drawn just before it, rather than a hard cut) and
    // for the caller's own subsequent shadow/window draws once this
    // function returns.
    glBindFramebufferFn(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, screenW, screenH);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, screenW, screenH, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glEnable(GL_BLEND);

    if (ok) {
        // The final blurred texture, drawn at the real window rect,
        // rounded via the exact same shader/radius the window's own
        // content uses right after this call returns - without that, the
        // blur would show as a plain square peeking out past the
        // window's own rounded corners.
        glUseProgramFn(GLShaderProgram);
        glUniform1iFn(GLUniformTex, 0);
        glUniform2fFn(GLUniformWinSize, w, h);
        glUniform1fFn(GLUniformRadius, radius);
        glBindTexture(GL_TEXTURE_2D, upTex[0]);

        glBegin(GL_QUADS);
        glMultiTexCoord2f(GL_TEXTURE0, 0.f, 0.f); glMultiTexCoord2f(GL_TEXTURE1, 0.f, 0.f); glVertex2f(x, y);
        glMultiTexCoord2f(GL_TEXTURE0, 1.f, 0.f); glMultiTexCoord2f(GL_TEXTURE1, w, 0.f);   glVertex2f(x + w, y);
        glMultiTexCoord2f(GL_TEXTURE0, 1.f, 1.f); glMultiTexCoord2f(GL_TEXTURE1, w, h);     glVertex2f(x + w, y + h);
        glMultiTexCoord2f(GL_TEXTURE0, 0.f, 1.f); glMultiTexCoord2f(GL_TEXTURE1, 0.f, h);   glVertex2f(x, y + h);
        glEnd();
    }

    for (int i = 1; i <= LEVELS; ++i) {
        if (downFBO[i])
            glDeleteFramebuffersFn(1, &downFBO[i]);
        if (downTex[i])
            glDeleteTextures(1, &downTex[i]);
    }

    for (int i = 0; i < LEVELS; ++i) {
        if (upFBO[i])
            glDeleteFramebuffersFn(1, &upFBO[i]);
        if (upTex[i])
            glDeleteTextures(1, &upTex[i]);
    }

    glDeleteTextures(1, &captureTex);
}

void CWindowManager::compositorRepaintGL() {
    // GLX contexts are only current on whichever thread last bound them -
    // this repaint runs on the tick thread, while setup above ran on the
    // main thread, so it must be (re-)bound here too. A no-op call if
    // already current on this thread, so doing it every frame is harmless.
    glXMakeContextCurrent(GLDisplay, GLWindow, GLWindow, GLContext);

    const auto ROOTGEOM = xcb_get_geometry_reply(DisplayConnection, xcb_get_geometry(DisplayConnection, Screen->root), NULL);

    if (!ROOTGEOM)
        return;

    const int SCREENW = ROOTGEOM->width;
    const int SCREENH = ROOTGEOM->height;
    free(ROOTGEOM);

    glViewport(0, 0, SCREENW, SCREENH);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    // Top-left origin matching X11's own coordinate convention, so window
    // geometry from xcb_get_geometry can be used directly with no flipping.
    glOrtho(0, SCREENW, SCREENH, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glEnable(GL_TEXTURE_2D);

    // Base layer, plain fixed-function (no rounding, no blending needed -
    // it's the one thing every frame draws fully opaque, covering the
    // whole screen). See GLBackgroundTexture's own comment in
    // windowManager.hpp for why this needs to happen every frame now,
    // unlike milestones 1b/2.
    //
    // v=0 at the top of the screen, v=1 at the bottom - matching the row
    // order XGetImage actually fills GLBackgroundTexture's data with (row
    // 0 = the top of the captured region, standard X11/Xlib image
    // convention), which is what OpenGL then treats as t=0 once uploaded
    // via glTexImage2D. Reported live after the first real reboot with
    // the compositor on: the desktop wallpaper rendered upside down on
    // every monitor (confirmed with an unambiguous top-red/bottom-blue
    // gradient test image in a Xephyr sandbox before shipping this fix -
    // top read back as blue, bottom as red, exactly reversed) - the
    // original mapping here had v flipped, a mistake introduced when this
    // quad was first written in milestone 3 and never caught until now,
    // since every sandbox verification through milestone 6 used either a
    // plain solid color or a symmetric checkerboard for the desktop
    // background, neither of which can reveal a vertical flip at all.
    glUseProgramFn(0);
    glDisable(GL_BLEND);
    glBindTexture(GL_TEXTURE_2D, GLBackgroundTexture);
    glBegin(GL_QUADS);
    glTexCoord2f(0.f, 0.f); glVertex2f(0, 0);
    glTexCoord2f(1.f, 0.f); glVertex2f(SCREENW, 0);
    glTexCoord2f(1.f, 1.f); glVertex2f(SCREENW, SCREENH);
    glTexCoord2f(0.f, 1.f); glVertex2f(0, SCREENH);
    glEnd();

    // Every window from here on is drawn through the rounded-corner
    // shader (see its own comment above compileShader()) - corners are
    // now genuinely partially transparent at the anti-aliased edge, so
    // real alpha blending is required (unlike the flat opaque overwrite
    // milestones 1b/2 used); the interior of every window is still
    // effectively alpha=1, so this doesn't change how anything already
    // opaque looks.
    //
    // GL_ONE (not GL_SRC_ALPHA) for the source factor - both shaders now
    // output premultiplied color (see their own comments), so the source
    // is used as-is and only the destination gets scaled down by
    // (1 - alpha). Milestone 6 found and fixed a real bug here: the
    // original GL_SRC_ALPHA/GL_ONE_MINUS_SRC_ALPHA pair is the textbook
    // choice for *straight* (non-premultiplied) alpha, but Quickshell/Qt's
    // own ARGB32 rendering - confirmed via a direct pixel readback of the
    // real Bar's own redirected pixmap at a reduced backgroundOpacity - is
    // premultiplied, so that pairing was silently double-darkening
    // translucent content down to solid black every time, the whole
    // reason the Bar/Dock opacity sliders looked "dead" even after real
    // GL_BLEND became active back in milestone 3.
    glUseProgramFn(GLShaderProgram);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glUniform1iFn(GLUniformTex, 0);

    // Same ground-truth stacking-order query compositorRepaintXRender()
    // uses, for the same reason - see that function's own comment.
    const auto TREEREPLY = xcb_query_tree_reply(DisplayConnection, xcb_query_tree(DisplayConnection, Screen->root), NULL);

    if (!TREEREPLY)
        return;

    const auto CHILDREN   = xcb_query_tree_children(TREEREPLY);
    const int  CHILDCOUNT = xcb_query_tree_children_length(TREEREPLY);

    for (int i = 0; i < CHILDCOUNT; ++i) {
        const xcb_window_t WIN = CHILDREN[i];

        const auto ATTRSREPLY = xcb_get_window_attributes_reply(DisplayConnection, xcb_get_window_attributes(DisplayConnection, WIN), NULL);

        if (!ATTRSREPLY)
            continue;

        if (ATTRSREPLY->map_state != XCB_MAP_STATE_VIEWABLE) {
            free(ATTRSREPLY);
            continue;
        }

        const auto VISUALCFGIT = GLFBConfigsByVisual.find((xcb_visualid_t)ATTRSREPLY->visual);

        free(ATTRSREPLY);

        if (VISUALCFGIT == GLFBConfigsByVisual.end())
            continue;

        const auto& VISUALCFG = VISUALCFGIT->second;

        const auto GEOMREPLY = xcb_get_geometry_reply(DisplayConnection, xcb_get_geometry(DisplayConnection, WIN), NULL);

        if (!GEOMREPLY)
            continue;

        const float X = GEOMREPLY->x, Y = GEOMREPLY->y, W = GEOMREPLY->width, H = GEOMREPLY->height;

        // Same "no rounding for fullscreen, or the lone window on a
        // no_gaps_when_only workspace" exception applyShapeToWindow()
        // itself already applies (see that function's own comment on why
        // it now skips its old hard clip once GLReady) - mirrored here so
        // a fullscreen window's corners (and shadow, below) aren't
        // rounded either.
        float radius = (float)(ConfigManager::getInt("rounding") + ConfigManager::getInt("border_size"));
        bool  isFullscreen = false;

        if (const auto PWINDOW = getWindowFromDrawable((int64_t)WIN); PWINDOW) {
            isFullscreen = PWINDOW->getFullscreen();

            if (isFullscreen || (ConfigManager::getInt("layout:no_gaps_when_only") && getWindowsOnWorkspace(PWINDOW->getWorkspaceID()) == 1))
                radius = 0.f;
        }

        // Milestone 4: the drop shadow, drawn immediately behind this
        // window and before its own content - correct stacking falls out
        // naturally from the same bottom-to-top loop order every other
        // per-window draw here already uses. Skipped for a fullscreen
        // window: its shadow would extend past the screen edge on every
        // side for zero visible benefit. A flat analytic falloff (see
        // ZARIS_GL_SHADOW_FRAGMENT_SHADER's own comment), not a real
        // blur - cheap, and good enough for a shadow's soft edge.
        if (!isFullscreen) {
            constexpr float SHADOWMARGIN = 24.f;
            constexpr float SHADOWBLUR   = 24.f;

            glUseProgramFn(GLShadowShaderProgram);
            glUniform2fFn(GLShadowUniformWinSize, W, H);
            glUniform1fFn(GLShadowUniformRadius, radius);
            glUniform1fFn(GLShadowUniformBlur, SHADOWBLUR);
            glUniform4fFn(GLShadowUniformColor, 0.f, 0.f, 0.f, 0.45f);

            glBegin(GL_QUADS);
            glMultiTexCoord2f(GL_TEXTURE1, -SHADOWMARGIN, -SHADOWMARGIN);     glVertex2f(X - SHADOWMARGIN, Y - SHADOWMARGIN);
            glMultiTexCoord2f(GL_TEXTURE1, W + SHADOWMARGIN, -SHADOWMARGIN); glVertex2f(X + W + SHADOWMARGIN, Y - SHADOWMARGIN);
            glMultiTexCoord2f(GL_TEXTURE1, W + SHADOWMARGIN, H + SHADOWMARGIN); glVertex2f(X + W + SHADOWMARGIN, Y + H + SHADOWMARGIN);
            glMultiTexCoord2f(GL_TEXTURE1, -SHADOWMARGIN, H + SHADOWMARGIN); glVertex2f(X - SHADOWMARGIN, Y + H + SHADOWMARGIN);
            glEnd();

            glUseProgramFn(GLShaderProgram);
            glUniform1iFn(GLUniformTex, 0);
        }

        // Milestone 5: background blur, behind every window this
        // compositor already tracks as always-on-top - see
        // GLBlurDownsampleProgram's own comment in windowManager.hpp for
        // why that's the chosen set (X11 offers no reliable way to
        // narrow it to specifically Settings/Control Center). Drawn after
        // the shadow (so the blur fills the window's own footprint,
        // sitting on top of the shadow's soft outer margin, exactly as a
        // real frosted-glass panel would) and before the window's own
        // content (so that content's real alpha then blends against this
        // freshly blurred backdrop instead of whatever was directly
        // beneath it).
        if (!isFullscreen && std::find(alwaysOnTopWindows.begin(), alwaysOnTopWindows.end(), WIN) != alwaysOnTopWindows.end()) {
            compositorDrawBlurBehind(X, Y, W, H, radius, SCREENW, SCREENH);
            glUseProgramFn(GLShaderProgram);
            glUniform1iFn(GLUniformTex, 0);
        }

        // Same "re-fetch fresh every frame, no long-term cache" tradeoff
        // as compositorRepaintXRender() - see that function's own comment.
        // Unlike that function, this one MUST wait for a reply (a real
        // round trip, via the checked cookie + xcb_request_check below)
        // rather than fire-and-forget: DisplayConnection and GLDisplay are
        // two independent connections/sockets to the server, so with no
        // synchronization there's no guarantee the server has actually
        // finished creating this Pixmap before GLDisplay's own
        // glXCreatePixmap call below - issued moments later, but on a
        // totally different connection - tries to reference it. Caught via
        // this exact race while verifying this milestone (an intermittent
        // GLXBadPixmap/BadDrawable from Mesa, "failed to create drawable").
        const xcb_pixmap_t PIXMAP     = xcb_generate_id(DisplayConnection);
        const auto         NAMECOOKIE = xcb_composite_name_window_pixmap_checked(DisplayConnection, WIN, PIXMAP);

        if (const auto NAMEERROR = xcb_request_check(DisplayConnection, NAMECOOKIE); NAMEERROR != NULL) {
            free(NAMEERROR);
            free(GEOMREPLY);
            continue;
        }

        const int PIXMAPATTRS[] = {
            GLX_TEXTURE_TARGET_EXT, GLX_TEXTURE_2D_EXT,
            GLX_TEXTURE_FORMAT_EXT, VISUALCFG.textureFormat,
            XCB_NONE,
        };

        const GLXPixmap GLXPIX = glXCreatePixmap(GLDisplay, VISUALCFG.fbconfig, PIXMAP, PIXMAPATTRS);

        if (GLXPIX) {
            GLuint tex = 0;
            glGenTextures(1, &tex);
            glBindTexture(GL_TEXTURE_2D, tex);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glXBindTexImageEXTFn(GLDisplay, GLXPIX, GLX_FRONT_LEFT_EXT, NULL);

            const float VTOP = VISUALCFG.yInverted ? 0.f : 1.f;
            const float VBOT = VISUALCFG.yInverted ? 1.f : 0.f;

            glUniform2fFn(GLUniformWinSize, W, H);
            glUniform1fFn(GLUniformRadius, radius);

            glBegin(GL_QUADS);
            glMultiTexCoord2f(GL_TEXTURE0, 0.f, VTOP); glMultiTexCoord2f(GL_TEXTURE1, 0.f, 0.f); glVertex2f(X, Y);
            glMultiTexCoord2f(GL_TEXTURE0, 1.f, VTOP); glMultiTexCoord2f(GL_TEXTURE1, W, 0.f);   glVertex2f(X + W, Y);
            glMultiTexCoord2f(GL_TEXTURE0, 1.f, VBOT); glMultiTexCoord2f(GL_TEXTURE1, W, H);     glVertex2f(X + W, Y + H);
            glMultiTexCoord2f(GL_TEXTURE0, 0.f, VBOT); glMultiTexCoord2f(GL_TEXTURE1, 0.f, H);   glVertex2f(X, Y + H);
            glEnd();

            glXReleaseTexImageEXTFn(GLDisplay, GLXPIX, GLX_FRONT_LEFT_EXT);
            glDeleteTextures(1, &tex);
            glXDestroyPixmap(GLDisplay, GLXPIX);
        }

        xcb_free_pixmap(DisplayConnection, PIXMAP);
        free(GEOMREPLY);
    }

    free(TREEREPLY);

    glFlush();

    // Rendering was invisible without this despite every draw call
    // reporting success (correct MakeContextCurrent, valid GLXPixmap,
    // GL_NO_ERROR) - the destination GLXWindow's FBConfig ended up
    // double-buffered rather than the single-buffered one assumed when
    // picking it, so every frame was actually landing in the back buffer
    // and never reaching the screen. Swapping unconditionally is the
    // standard, safe fix any real GL application uses regardless of which
    // buffering mode it ended up with - a harmless no-op if the config
    // genuinely were single-buffered, required if (as turned out to be the
    // actual case here) it isn't.
    glXSwapBuffers(GLDisplay, GLWindow);
}

bool CWindowManager::shouldBeFloatedOnInit(int64_t window) {
    // Should be floated also sets some properties

    const auto PWINDOW = getWindowFromDrawable(window);

    if (!PWINDOW) {
        Debug::log(ERR, "shouldBeFloatedOnInit with an invalid window!");
        return true;
    }
        
    
    const auto WINCLASS = getClassName(window);
    const auto CLASSNAME = WINCLASS.second;
    const auto CLASSINSTANCE = WINCLASS.first;

    Debug::log(LOG, "New window got class " + (std::string)CLASSINSTANCE + " -> " + CLASSNAME);

    // Grab the title before we stomp WM_NAME below, so title: window rules see the
    // app's real title and not our placeholder.
    const auto WINNAME = getWindowName(window);

    xcb_change_property(DisplayConnection, XCB_PROP_MODE_REPLACE, window, XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8, strlen("zaris"), "zaris");

    // Role stuff
    const auto WINROLE = getRoleName(window);

    Debug::log(LOG, "Window opened with a role of " + WINROLE);

    // Set it in the pwindow
    PWINDOW->setClassName(CLASSNAME);
    PWINDOW->setRoleName(WINROLE);
    PWINDOW->setName(WINNAME);

    //
    // Type stuff
    //
    PROP(wm_type_cookie, ZARISATOMS["_NET_WM_WINDOW_TYPE"], UINT32_MAX);

    if (wm_type_cookiereply == NULL || xcb_get_property_value_length(wm_type_cookiereply) < 1) {
        Debug::log(LOG, "No preferred type found. (shouldBeFloatedOnInit)");
    } else {
        const auto ATOMS = (xcb_atom_t*)xcb_get_property_value(wm_type_cookiereply);
        if (!ATOMS) {
            Debug::log(ERR, "Atoms not found in preferred type!");
        } else {
            if (xcbContainsAtom(wm_type_cookiereply, ZARISATOMS["_NET_WM_WINDOW_TYPE_DOCK"])) {
                free(wm_type_cookiereply);
                return true;
            } else if (xcbContainsAtom(wm_type_cookiereply, ZARISATOMS["_NET_WM_WINDOW_TYPE_DIALOG"])
                || xcbContainsAtom(wm_type_cookiereply, ZARISATOMS["_NET_WM_WINDOW_TYPE_TOOLBAR"])
                || xcbContainsAtom(wm_type_cookiereply, ZARISATOMS["_NET_WM_WINDOW_TYPE_UTILITY"])
                || xcbContainsAtom(wm_type_cookiereply, ZARISATOMS["_NET_WM_STATE_MODAL"])
                || xcbContainsAtom(wm_type_cookiereply, ZARISATOMS["_NET_WM_WINDOW_TYPE_SPLASH"])) {
                
                Events::nextWindowCentered = true;
                free(wm_type_cookiereply);
                return true;
            }
        }
    }
    free(wm_type_cookiereply);
    //
    //
    //

    // Verify the rules.
    for (auto& rule : ConfigManager::getMatchingRules(window)) {
        if (rule.szRule == "tile")
            return false;
        else if (rule.szRule == "float")
            return true;
        else if (rule.szRule == "nointerventions") {
            PWINDOW->setNoInterventions(true);
            PWINDOW->setImmovable(true);
            return true;
        }
    }

    return false;
}

void CWindowManager::updateActiveWindowName() {
    if (!getWindowFromDrawable(LastWindow))
        return;

    const auto PLASTWINDOW = getWindowFromDrawable(LastWindow);

    auto WINNAME = getWindowName(LastWindow);
    if (WINNAME != PLASTWINDOW->getName()) {
        Debug::log(LOG, "Update, window got name: " + WINNAME);
        PLASTWINDOW->setName(WINNAME);
    }
}

void CWindowManager::doPostCreationChecks(CWindow* pWindow) {
    //
    Debug::log(LOG, "Post creation checks init");

    const auto window = pWindow->getDrawable();

    PROP(wm_type_cookie, ZARISATOMS["_NET_WM_WINDOW_TYPE"], UINT32_MAX);

    if (wm_type_cookiereply == NULL || xcb_get_property_value_length(wm_type_cookiereply) < 1) {
        Debug::log(LOG, "No preferred type found. (doPostCreationChecks)");
    } else {
        const auto ATOMS = (xcb_atom_t*)xcb_get_property_value(wm_type_cookiereply);
        if (!ATOMS) {
            Debug::log(ERR, "Atoms not found in preferred type!");
        } else {
            if (xcbContainsAtom(wm_type_cookiereply, ZARISATOMS["_NET_WM_STATE_FULLSCREEN"])) {
                // set it fullscreen
                pWindow->setFullscreen(true);

                setFocusedWindow(window);
                
                KeybindManager::toggleActiveWindowFullscreen("");
            }
        }
    }
    free(wm_type_cookiereply);

    // Check if it has a name
    const auto NAME = getClassName(window);
    if (NAME.first == "Error" && NAME.second == "Error") {
        Debug::log(WARN, "Window created but has a class of NULL?");
    }

    Debug::log(LOG, "Post creation checks ended");
    //
}

void CWindowManager::getICCCMWMProtocols(CWindow* pWindow) {
    xcb_icccm_get_wm_protocols_reply_t WMProtocolsReply;
    if (!xcb_icccm_get_wm_protocols_reply(DisplayConnection,
        xcb_icccm_get_wm_protocols(DisplayConnection, pWindow->getDrawable(), ZARISATOMS["WM_PROTOCOLS"]), &WMProtocolsReply, NULL))
        return;

    for (auto i = 0; i < (int)WMProtocolsReply.atoms_len; i++) {
        if (WMProtocolsReply.atoms[i] == ZARISATOMS["WM_DELETE_WINDOW"])
            pWindow->setCanKill(true);
    }
    
    xcb_icccm_get_wm_protocols_reply_wipe(&WMProtocolsReply);
}

void CWindowManager::refocusWindowOnClosed() {
    const auto PWINDOW = findWindowAtCursor();

    // No window or last window valid
    if (!PWINDOW || getWindowFromDrawable(LastWindow)) {
        setFocusedWindow(Screen->root);  //refocus on root
            
        return;
    }

    LastWindow = PWINDOW->getDrawable();

    setFocusedWindow(PWINDOW->getDrawable());
}

void CWindowManager::recalcAllWorkspaces() {
    for (auto& workspace : workspaces) {
        recalcEntireWorkspace(workspace.getID());
    }
}

void CWindowManager::moveWindowToUnmapped(int64_t id) {
    if (ConfigManager::getInt("no_unmap_saving") == 1){
        closeWindowAllChecks(id);
        return;
    }

    for (auto& w : windows) {
        if (w.getDrawable() == id) {
            // Move it
            unmappedWindows.push_back(w);
            removeWindowFromVectorSafe(w.getDrawable());
            return;
        }
    }
}

void CWindowManager::moveWindowToMapped(int64_t id) {
    for (auto& w : unmappedWindows) {
        if (w.getDrawable() == id) {
            // Move it
            windows.push_back(w);
            // manually remove
            auto temp = unmappedWindows;
            unmappedWindows.clear();

            for (auto& t : temp) {
                if (t.getDrawable() != id)
                    unmappedWindows.push_back(t);
            }

            windows[windows.size() - 1].setUnderFullscreen(false);
            windows[windows.size() - 1].setDirty(true);
            windows[windows.size() - 1].setLastUpdatePosition(Vector2D(0,0));
            windows[windows.size() - 1].setLastUpdateSize(Vector2D(0,0));

            return;
        }
    }
}

bool CWindowManager::isWindowUnmapped(int64_t id) {
    for (auto& w : unmappedWindows) {
        if (w.getDrawable() == id) {
            return true;
        }
    }

    return false;
}

void CWindowManager::setAllWorkspaceWindowsAboveFullscreen(const int& workspace) {
    for (auto& w : windows) {
        if (w.getWorkspaceID() == workspace && w.getIsFloating()) {
            w.setUnderFullscreen(false);
        }
    }
}

void CWindowManager::setAllWorkspaceWindowsUnderFullscreen(const int& workspace) {
    for (auto& w : windows) {
        if (w.getWorkspaceID() == workspace && w.getIsFloating()) {
            w.setUnderFullscreen(true);
        }
    }
}

void CWindowManager::toggleWindowFullscrenn(const int& window) {
    const auto PWINDOW = getWindowFromDrawable(window);

    if (!PWINDOW)
        return;

    const auto MONITOR = getMonitorFromWindow(PWINDOW);

    if (getWorkspaceByID(activeWorkspaces[MONITOR->ID])->getHasFullscreenWindow() && !PWINDOW->getFullscreen()) {
        Debug::log(LOG, "Not making a window fullscreen because there already is one!");
        return;
    }

    setAllWorkspaceWindowsDirtyByID(activeWorkspaces[MONITOR->ID]);

    PWINDOW->setFullscreen(!PWINDOW->getFullscreen());
    getWorkspaceByID(PWINDOW->getWorkspaceID())->setHasFullscreenWindow(PWINDOW->getFullscreen());

    // Fix windows over and below fullscreen.
    if (PWINDOW->getFullscreen())
        setAllWorkspaceWindowsUnderFullscreen(activeWorkspaces[MONITOR->ID]);
    else
        setAllWorkspaceWindowsAboveFullscreen(activeWorkspaces[MONITOR->ID]);

    // Neither branch above (nor anything in refreshDirtyWindows()'s own
    // fullscreen handling) ever actually issues an XCB restack - a window
    // going fullscreen visually covers Zaris-managed windows below it
    // simply by being resized to fill the monitor while already
    // reasonably near the top of the stack from having just been focused/
    // clicked. That's not true for Quickshell's override-redirect popups
    // (Settings, Control Center, etc. - see reassertAlwaysOnTop()'s own
    // comment) - they're never part of the focus-driven raise dance at
    // all, so if one was already open before this window went fullscreen,
    // nothing was ever pushing it out of the way and it would sit on top
    // of the game indefinitely, exactly the case the "except fullscreen
    // ones" carve-out in reassertAlwaysOnTop() is meant to respect. A
    // one-time real raise of the newly-fullscreened window to the actual
    // top of X11's stacking order (not just the WM's own tracked windows -
    // XCB stacking is global across all children of root, override-
    // redirect included) puts it above any already-open always-on-top
    // popup too; reassertAlwaysOnTop() then leaves it there by skipping
    // its own raise for as long as this workspace's fullscreen flag stays
    // set, rather than fighting back on the very next event-loop tick.
    if (PWINDOW->getFullscreen())
        setAWindowTop(window);

    // EWMH 
    Values[0] = ZARISATOMS["_NET_WM_STATE_FULLSCREEN"];
    if (PWINDOW->getFullscreen())
        xcb_change_property(DisplayConnection, XCB_PROP_MODE_APPEND, window, ZARISATOMS["_NET_WM_STATE"], XCB_ATOM_ATOM, 32, 1, Values);
    else
        removeAtom(window, ZARISATOMS["_NET_WM_STATE"], ZARISATOMS["_NET_WM_STATE_FULLSCREEN"]);

    EWMH::updateWindow(window);

    Debug::log(LOG, "Set fullscreen to " + std::to_string(PWINDOW->getFullscreen()) + " for " + std::to_string(window));
}

void CWindowManager::handleClientMessage(xcb_client_message_event_t* E) {

    const auto PWINDOW = getWindowFromDrawable(E->window);

    if (E->type == ZARISATOMS["_NET_WM_STATE"]) {
        // The window wants to change its' state.
        // For now we only support FULLSCREEN

        if (!PWINDOW){
            Debug::log(ERR, "Requested _NET_WM_STATE with an invalid window ID! Ignoring.");
            return;
        }

        if (E->data.data32[1] == ZARISATOMS["_NET_WM_STATE_FULLSCREEN"]) {
            if ((PWINDOW->getFullscreen() && (E->data.data32[0] == 0 || E->data.data32[0] == 2))
                || (!PWINDOW->getFullscreen() && (E->data.data32[0] == 1 || E->data.data32[0] == 2))) {

                // Toggle fullscreen
                toggleWindowFullscrenn(PWINDOW->getDrawable());
            }

            Debug::log(LOG, "Message recieved to toggle fullscreen for " + std::to_string(PWINDOW->getDrawable()));
        }
    } else if (E->type == ZARISATOMS["_NET_ACTIVE_WINDOW"]) {
        // Change the focused window
        if (E->format != 32)
            return;

        if (!PWINDOW) {
            Debug::log(ERR, "Requested _NET_ACTIVE_WINDOW with an invalid window ID! Ignoring.");
            return;
        }

        // EWMH's source-indication field (0 = unspecified, 1 = application, 2 = pager/
        // user-initiated) is untrustworthy: confirmed live via diagnostic logging that
        // Wine/Proton sends source=2 - the value this code used to treat as "explicit,
        // trusted user action" - for its OWN internal foreground-window reclaims. That
        // made every previous version of this check a no-op against the actual game
        // causing the problem, since it always qualified for the trusted carve-out.
        // ZarisWM has no legitimate feature today that activates a window via this
        // ClientMessage (workspace switching uses _NET_CURRENT_DESKTOP, not this), so
        // there's no real activation to protect by trusting any source value. Only a
        // genuine X11 input event (a real click or hover, via eventButtonPress/
        // eventEnter) ever counts as user-initiated - no EWMH message does, regardless
        // of what it claims. Any self-activation request while the current focus is
        // the user's own deliberate choice is rejected outright.
        const auto SOURCE = E->data.data32[0];

        if (CurrentFocusIsUserChosen && PWINDOW->getDrawable() != LastWindow) {
            Debug::log(LOG, "Ignoring _NET_ACTIVE_WINDOW from " + std::to_string(PWINDOW->getDrawable()) + " (source " + std::to_string(SOURCE) + ") - current focus (" + std::to_string(LastWindow) + ") is the user's own deliberate choice.");
            return;
        }

        Debug::log(LOG, "Request to change active window to " + std::to_string(PWINDOW->getDrawable()));

        setFocusedWindow(PWINDOW->getDrawable(), false);

        Debug::log(LOG, "Message recieved to set active for " + std::to_string(PWINDOW->getDrawable()));
    } else if (E->type == ZARISATOMS["_NET_MOVERESIZE_WINDOW"]) {
        void *const PEVENT = calloc(32, 1);
        xcb_configure_request_event_t* const GENEV = (xcb_configure_request_event_t*)PEVENT;

        GENEV->window = E->window;
        GENEV->response_type = XCB_CONFIGURE_REQUEST;

        GENEV->value_mask = 0;
        if (E->data.data32[0] & _NET_MOVERESIZE_WINDOW_X) {
            GENEV->value_mask |= XCB_CONFIG_WINDOW_X;
            GENEV->x = E->data.data32[1];
        }
        if (E->data.data32[0] & _NET_MOVERESIZE_WINDOW_Y) {
            GENEV->value_mask |= XCB_CONFIG_WINDOW_Y;
            GENEV->y = E->data.data32[2];
        }
        if (E->data.data32[0] & _NET_MOVERESIZE_WINDOW_WIDTH) {
            GENEV->value_mask |= XCB_CONFIG_WINDOW_WIDTH;
            GENEV->width = E->data.data32[3];
        }
        if (E->data.data32[0] & _NET_MOVERESIZE_WINDOW_HEIGHT) {
            GENEV->value_mask |= XCB_CONFIG_WINDOW_HEIGHT;
            GENEV->height = E->data.data32[4];
        }

        Events::eventConfigure((xcb_generic_event_t*)GENEV);
        free(GENEV);
    } else if (E->type == ZARISATOMS["_NET_CURRENT_DESKTOP"]) {
        // request to change the workspace to something else
        // likely a bar/pager, emitted by xcb_ewmh_request_change_current_desktop
        // data32[0] is a desktop INDEX, not a workspace ID (workspace IDs can have gaps)

        const auto DESKTOPINDEX = E->data.data32[0];
        const auto WORK = EWMH::workspaceIDFromDesktopIndex(DESKTOPINDEX);

        if (WORK == -1) {
            Debug::log(ERR, "Desktop index " + std::to_string(DESKTOPINDEX) + " does NOT map to any workspace! Ignoring.");
            return;
        }

        Debug::log(LOG, "External request to switch to workspace " + std::to_string(WORK));

        changeWorkspaceByID(WORK);
    }
}

void CWindowManager::recalcAllDocks() {
    for (auto& mon : monitors) {
        mon.vecReservedTopLeft = {0, 0};
        mon.vecReservedBottomRight = {0, 0};

        setAllWorkspaceWindowsDirtyByID(activeWorkspaces[mon.ID]);
    }

    for (auto& w : windows) {
        if (!w.getDock() || w.getDead() || !w.getIsFloating())
            continue;

        const auto MONITOR = &monitors[w.getMonitor()];

        const auto VERTICAL = w.getSize().x / w.getSize().y < 1;

        if (VERTICAL) {
            if (w.getPosition().x < MONITOR->vecSize.x / 2.f + MONITOR->vecPosition.x) {
                // Left
                MONITOR->vecReservedTopLeft = Vector2D(w.getSize().x, 0);
            } else {
                // Right
                MONITOR->vecReservedBottomRight = Vector2D(w.getSize().x, 0);
            }
        } else {
            if (w.getPosition().y < MONITOR->vecSize.y / 2.f + MONITOR->vecPosition.y) {
                // Top
                MONITOR->vecReservedTopLeft = Vector2D(0, w.getSize().y);
            } else {
                // Bottom
                MONITOR->vecReservedBottomRight = Vector2D(0, w.getSize().y);
            }
        }

        // Move it
        Values[0] = w.getDefaultPosition().x;
        Values[1] = w.getDefaultPosition().y;
        xcb_configure_window(DisplayConnection, w.getDrawable(), XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y, Values);

        Values[0] = w.getDefaultSize().x;
        Values[1] = w.getDefaultSize().y;
        xcb_configure_window(DisplayConnection, w.getDrawable(), XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, Values);
    }
}

void CWindowManager::startWipeAnimOnWorkspace(const int& oldwork, const int& newwork) {
    const auto PMONITOR = getMonitorFromWorkspace(newwork);

    if (newwork < oldwork) { // Wipe from left to right
        for (auto& work : workspaces) {
            if (work.getID() == oldwork) {
                if (ConfigManager::getInt("animations:workspaces") == 1)
                    work.setCurrentOffset(Vector2D(0,0));
                else
                    work.setCurrentOffset(Vector2D(150000, 150000));
                work.setGoalOffset(Vector2D(PMONITOR->vecSize.x, 0));
                work.setAnimationInProgress(true);
            } else if (work.getID() == newwork) {
                if (ConfigManager::getInt("animations:workspaces") == 1)
                    work.setCurrentOffset(Vector2D(-PMONITOR->vecSize.x, 0));
                else
                    work.setCurrentOffset(Vector2D(0, 0));
                work.setGoalOffset(Vector2D(0, 0));
                work.setAnimationInProgress(true);
            }
        }
    } else {  // Wipe from right to left (oldwork < newwork)
        for (auto& work : workspaces) {
            if (work.getID() == oldwork) {
                if (ConfigManager::getInt("animations:workspaces") == 1)
                    work.setCurrentOffset(Vector2D(0,0));
                else
                    work.setCurrentOffset(Vector2D(150000, 150000));
                work.setGoalOffset(Vector2D(-PMONITOR->vecSize.x, 0));
                work.setAnimationInProgress(true);
            } else if (work.getID() == newwork) {
                if (ConfigManager::getInt("animations:workspaces") == 1)
                    work.setCurrentOffset(Vector2D(PMONITOR->vecSize.x, 0));
                else
                    work.setCurrentOffset(Vector2D(0, 0));
                work.setGoalOffset(Vector2D(0, 0));
                work.setAnimationInProgress(true);
            }
        }
    }
}

void CWindowManager::dispatchQueuedWarp() {
    if (QueuedPointerWarp.x == -1 && QueuedPointerWarp.y == -1)
        return;

    warpCursorTo(QueuedPointerWarp);
    QueuedPointerWarp = Vector2D(-1,-1);
}

bool CWindowManager::shouldBeManaged(const int& window) {
    const auto WINDOWATTRS = xcb_get_window_attributes_reply(DisplayConnection, xcb_get_window_attributes(DisplayConnection, window), NULL);

    if (!WINDOWATTRS) {
        Debug::log(LOG, "Skipping: window attributes null");
        return false;
    }

    if (WINDOWATTRS->override_redirect) {
        Debug::log(LOG, "Skipping: override redirect");
        return false;
    }

    const auto GEOMETRY = xcb_get_geometry_reply(DisplayConnection, xcb_get_geometry(DisplayConnection, window), NULL);
    if (!GEOMETRY) {
        Debug::log(LOG, "Skipping: No geometry");
        return false;
    }

    Debug::log(LOG, "shouldBeManaged passed!");

    return true;
}

SMonitor* CWindowManager::getMonitorFromCoord(const Vector2D coord) {
    for (auto& m : monitors) {
        if (VECINRECT(coord, m.vecPosition.x, m.vecPosition.y, m.vecPosition.x + m.vecSize.x, m.vecPosition.y + m.vecSize.y))
            return &m;
    }

    return nullptr;
}

void CWindowManager::changeSplitRatioCurrent(std::string dir) {

    const auto CURRENT = getWindowFromDrawable(LastWindow);

    if (!CURRENT) {
        Debug::log(LOG, "Cannot change split ratio when lastwindow NULL.");
        return;
    }

    const auto PARENT = getWindowFromDrawable(CURRENT->getParentNodeID());

    if (!PARENT) {
        Debug::log(LOG, "Cannot change split ratio when parent NULL.");
        return;
    }

    if (dir == "+") 
        PARENT->setSplitRatio(PARENT->getSplitRatio() + 0.05f);
    else if (dir == "-") 
        PARENT->setSplitRatio(PARENT->getSplitRatio() - 0.05f);
    else 
        PARENT->setSplitRatio(PARENT->getSplitRatio() + std::stof(dir));

    PARENT->setSplitRatio(std::clamp(PARENT->getSplitRatio(), 0.1f, 1.9f));

    Debug::log(LOG, "Changed SplitRatio of " + std::to_string(PARENT->getDrawable()) + " to " + std::to_string(PARENT->getSplitRatio()) + " (" + dir + ")" );

    recalcEntireWorkspace(CURRENT->getWorkspaceID());
}

void CWindowManager::getICCCMSizeHints(CWindow* pWindow) {
    xcb_size_hints_t sizeHints;
    const auto succ = xcb_icccm_get_wm_normal_hints_reply(g_pWindowManager->DisplayConnection, xcb_icccm_get_wm_normal_hints_unchecked(g_pWindowManager->DisplayConnection, pWindow->getDrawable()), &sizeHints, NULL);
    
    if (succ) {
        auto NEWSIZE = Vector2D(std::max(std::max(sizeHints.width, (int32_t)pWindow->getDefaultSize().x), std::max(sizeHints.max_width > g_pWindowManager->monitors[pWindow->getMonitor()].vecSize.x ? 0 : sizeHints.max_width, sizeHints.base_width)),
                                std::max(std::max(sizeHints.height, (int32_t)pWindow->getDefaultSize().y), std::max(sizeHints.max_height > g_pWindowManager->monitors[pWindow->getMonitor()].vecSize.y ? 0 : sizeHints.max_height, sizeHints.base_height)));

        pWindow->setPseudoSize(NEWSIZE);
    } else {
        Debug::log(ERR, "ICCCM Size Hints failed.");
    }
}

void CWindowManager::processCursorDeltaOnWindowResizeTiled(CWindow* pWindow, const Vector2D& pointerDelta) {
    // this resizes the window based on cursor movement,
    // basically like a mouse-ver of splitratio

    if (!pWindow)
        return;

    // TODO: support master-stack
    if (ConfigManager::getInt("layout") == LAYOUT_MASTER){
        Debug::log(WARN, "processCursorDeltaOnWindowResizeTiled does NOT support MASTER yet. Ignoring.");
        return;
    }

    // Construct an allowed delta movement
    const auto PMONITOR             = getMonitorFromWindow(pWindow);
    const bool DISPLAYLEFT          = STICKS(pWindow->getPosition().x, PMONITOR->vecPosition.x);
    const bool DISPLAYRIGHT         = STICKS(pWindow->getPosition().x + pWindow->getSize().x, PMONITOR->vecPosition.x + PMONITOR->vecSize.x);
    const bool DISPLAYTOP           = STICKS(pWindow->getPosition().y, PMONITOR->vecPosition.y);
    const bool DISPLAYBOTTOM        = STICKS(pWindow->getPosition().y + pWindow->getSize().y, PMONITOR->vecPosition.y + PMONITOR->vecSize.y);

    Vector2D allowedMovement = pointerDelta;
    if (DISPLAYLEFT && DISPLAYRIGHT)
        allowedMovement.x = 0;

    if (DISPLAYTOP && DISPLAYBOTTOM)
        allowedMovement.y = 0;

    // Get the correct containers to apply the splitratio to
    const auto PPARENT = getWindowFromDrawable(pWindow->getParentNodeID());

    // If there is no parent we ignore the request (only window)
    if (!PPARENT)
        return;

    const bool PARENTSIDEBYSIDE = PPARENT->getSize().x / PPARENT->getSize().y > 1;

    // Get the parent's parent.
    const auto PPARENT2 = getWindowFromDrawable(PPARENT->getParentNodeID());

    // if there is no parent, we have 2 windows only and have the ability to drag in only one direction.
    if (!PPARENT2) {
        if (PARENTSIDEBYSIDE) {
            // splitratio adjust for pixels
            allowedMovement.x *= 2.f / PPARENT->getSize().x;
            PPARENT->setSplitRatio(std::clamp(PPARENT->getSplitRatio() + allowedMovement.x, (double)0.05f, (double)1.95f));
            PPARENT->recalcSizePosRecursive();
        } else {
            allowedMovement.y *= 2.f / PPARENT->getSize().y;
            PPARENT->setSplitRatio(std::clamp(PPARENT->getSplitRatio() + allowedMovement.y, (double)0.05f, (double)1.95f));
            PPARENT->recalcSizePosRecursive();
        }

        return;
    }

    // if there is a parent, we have 2 axes of freedom
    const auto SIDECONTAINER = PARENTSIDEBYSIDE ? PPARENT : PPARENT2;
    const auto TOPCONTAINER = PARENTSIDEBYSIDE ? PPARENT2 : PPARENT;

    allowedMovement.x *= 2.f / SIDECONTAINER->getSize().x;
    allowedMovement.y *= 2.f / TOPCONTAINER->getSize().y;

    SIDECONTAINER->setSplitRatio(std::clamp(SIDECONTAINER->getSplitRatio() + allowedMovement.x, (double)0.05f, (double)1.95f));
    TOPCONTAINER->setSplitRatio(std::clamp(TOPCONTAINER->getSplitRatio() + allowedMovement.y, (double)0.05f, (double)1.95f));
    SIDECONTAINER->recalcSizePosRecursive();
    TOPCONTAINER->recalcSizePosRecursive();
}