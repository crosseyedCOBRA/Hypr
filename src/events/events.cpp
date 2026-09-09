#include "events.hpp"

#include <algorithm>

gpointer handle(gpointer data) {
    int lazyUpdateCounter = 0;

    while (1) {
        // update animations. They should be thread-safe.
        AnimationUtil::move();
        //

        // wait for the main thread to be idle
        while (g_pWindowManager->mainThreadBusy) {
            std::this_thread::sleep_for(std::chrono::microseconds(1));
        }

        // set state to let the main thread know to wait.
        g_pWindowManager->animationUtilBusy = true;

        // Don't spam these
        if (lazyUpdateCounter > 10){
            // Update the active window name
            g_pWindowManager->updateActiveWindowName();

            // check config
            ConfigManager::tick();

            lazyUpdateCounter = 0;
        }

        ++lazyUpdateCounter;

        // restore anim state
        g_pWindowManager->animationUtilBusy = false;

        std::this_thread::sleep_for(std::chrono::milliseconds(1000 / ConfigManager::getInt("max_fps")));
    }
}

void Events::setThread() {
    g_pWindowManager->tickThread = g_thread_new("ZarisTick", handle, nullptr);

    if (!g_pWindowManager->tickThread) {
        Debug::log(ERR, "Gthread failed!");
        return;
    }
}

void Events::eventEnter(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_enter_notify_event_t*>(event);

    if (E->mode != XCB_NOTIFY_MODE_NORMAL)
        return;

    if (E->detail == XCB_NOTIFY_DETAIL_INFERIOR)
        return;

    const auto PENTERWINDOW = g_pWindowManager->getWindowFromDrawable(E->event);

    if (!PENTERWINDOW){

        // We only get here for a window we've never tracked - most commonly a
        // popup/dropdown menu (bookmark menus, right-click context menus, combo
        // box lists, ...), which toolkits almost always create override-redirect
        // specifically so the WM won't touch them. Blindly trying to "manage"
        // any such window regardless of that flag - the bug this guard fixes -
        // stole focus away from the menu's actual parent window the instant the
        // mouse entered it, and most toolkits auto-dismiss a menu the moment its
        // parent loses focus: reported live as bookmark/dropdown menus in Zen
        // Browser closing themselves instantly on hover, "like a double click."
        // shouldBeManaged() is the same check eventMapWindow() already applies
        // for exactly this reason - apply it here too instead of skipping it.
        if (!g_pWindowManager->shouldBeManaged(E->event)) {
            Debug::log(LOG, "Entered a window that shouldn't be managed (e.g. override-redirect popup/menu) - leaving it alone.");
            return;
        }

        // we entered an unknown window to us. Let's manage it.
        Debug::log(LOG, "Entered an unmanaged window. Trying to manage it!");

        CWindow newEnteredWindow;
        newEnteredWindow.setDrawable(E->event);
        g_pWindowManager->addWindowToVectorSafe(newEnteredWindow);

        CWindow* pNewWindow;
        if (g_pWindowManager->shouldBeFloatedOnInit(E->event)) {
            Debug::log(LOG, "Window SHOULD be floating on start.");
            pNewWindow = remapFloatingWindow(E->event);
        } else {
            Debug::log(LOG, "Window should NOT be floating on start.");
            pNewWindow = remapWindow(E->event);
        }

        if (!pNewWindow) { // oh well. we tried. 
            g_pWindowManager->removeWindowFromVectorSafe(E->event);
            Debug::log(LOG, "Tried to manage, but failed!");
        }

        return;
    }

    // Only when focus_when_hover OR floating OR last window floating
    if (ConfigManager::getInt("focus_when_hover") == 1
        || PENTERWINDOW->getIsFloating()
        || (g_pWindowManager->getWindowFromDrawable(g_pWindowManager->LastWindow) && g_pWindowManager->getWindowFromDrawable(g_pWindowManager->LastWindow)->getIsFloating()))
            g_pWindowManager->setFocusedWindow(E->event, true);

    PENTERWINDOW->setDirty(true);

    if (PENTERWINDOW->getIsSleeping()) {
        // Wake it up, fixes some weird shenaningans
        wakeUpEvent(E->event);
        PENTERWINDOW->setIsSleeping(false);
    }
}

void Events::eventLeave(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_leave_notify_event_t*>(event);

    const auto PENTERWINDOW = g_pWindowManager->getWindowFromDrawable(E->event);

    if (!PENTERWINDOW)
        return;

    if (PENTERWINDOW->getIsSleeping()) {
        // Wake it up, fixes some weird shenaningans
        wakeUpEvent(E->event);
        PENTERWINDOW->setIsSleeping(false);
    }
}

void Events::eventDestroy(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_destroy_notify_event_t*>(event);

    Debug::log(LOG, "Destroy called on " + std::to_string(E->window));

    g_pWindowManager->closeWindowAllChecks(E->window);

    // refocus on new window
    g_pWindowManager->refocusWindowOnClosed();

    // EWMH
    EWMH::updateClientList();
}

void Events::eventUnmapWindow(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_unmap_notify_event_t*>(event);

    const auto PCLOSEDWINDOW = g_pWindowManager->getWindowFromDrawable(E->window);

    if (!PCLOSEDWINDOW) {
        Debug::log(LOG, "Unmap called on an invalid window: " + std::to_string(E->window));
        return; // bullshit window?
    }

    Debug::log(LOG, "Unmap called on " + std::to_string(E->window) + " -> " + PCLOSEDWINDOW->getName());

    // Real bug fixed here: a dock-type window (bar/dock) that's currently
    // getDockHidden() was unmapped by our OWN processDockHiding() - a
    // fullscreen window on its monitor's active workspace, not a real
    // close. That function relies on Events::ignoredEvents (a sequence-
    // number match) to suppress the resulting UnmapNotify, but that list
    // is capped at 20 entries (see recieveEvent()) and gets trimmed on
    // every subsequent real event - under the burst of window/property
    // events a game exiting fullscreen generates, the entry for the dock's
    // own unmap can be evicted before its UnmapNotify actually arrives,
    // so it falls through to here and gets treated as a genuine close:
    // closeWindowAllChecks() removes it from tracking permanently via
    // removeWindowFromVectorSafe(), so it's simply gone from `windows` by
    // the time processDockHiding() later wants to re-map it once
    // getHasFullscreenWindow() clears - explaining the reported "bar on
    // the primary monitor never comes back after exiting a fullscreen
    // game" (a `qs kill` + relaunch works around it only because that
    // creates a brand new window with a fresh MapRequest, unrelated to
    // this stale tracking entry).
    //
    // getDockHidden() is ONLY ever set true by that one code path (grep
    // confirms no other setDockHidden(true) call site exists), so it's a
    // reliable signal - independent of the racy sequence-number list -
    // that THIS specific unmap is our own intentional, temporary hide
    // rather than a real close or the dock's config-disable toggle (which
    // unmaps via Quickshell's own `visible: false`, with getDockHidden()
    // staying false throughout). Skipping closeWindowAllChecks entirely
    // for this case leaves the window's tracking entry intact so
    // processDockHiding()'s later xcb_map_window() call has something to
    // act on.
    //
    // Previously skipped entirely for dock-type windows, which meant
    // hiding one (e.g. Dock.qml's DockConfig.enabled toggle) never
    // released its reserved space - closeWindowAllChecks already has
    // correct dock handling (removes it from tracking, then
    // recalcAllDocks()) for that genuine-close/disable case, it just
    // wasn't being called at all before. Never mattered before since
    // nothing ever hid a dock-type window at runtime until the dock's
    // enable/disable toggle - this fullscreen-hide interaction is a
    // second, later runtime source of dock unmaps that toggle didn't
    // anticipate.
    if (PCLOSEDWINDOW->getDock() && PCLOSEDWINDOW->getDockHidden()) {
        Debug::log(LOG, "Unmap on " + std::to_string(E->window) + " is our own fullscreen dock-hide, not a real close - skipping closeWindowAllChecks");
        return;
    }

    g_pWindowManager->closeWindowAllChecks(E->window);

    // refocus on new window
    g_pWindowManager->refocusWindowOnClosed();

    // EWMH
    EWMH::updateClientList();
}

CWindow* Events::remapFloatingWindow(int windowID, int forcemonitor) {
    // The array is not realloc'd in this method we can make this const
    const auto PWINDOWINARR = g_pWindowManager->getWindowFromDrawable(windowID);

    if (!PWINDOWINARR) {
        Debug::log(ERR, "remapFloatingWindow called with an invalid window!");
        return nullptr;
    }

    PWINDOWINARR->setIsFloating(true);
    PWINDOWINARR->setDirty(true);

    auto PMONITOR = g_pWindowManager->getMonitorFromCursor();
    if (!PMONITOR) {
        Debug::log(ERR, "Monitor was null! (remapWindow) Using 0.");
        PMONITOR = &g_pWindowManager->monitors[0];

        if (g_pWindowManager->monitors.size() == 0) {
            Debug::log(ERR, "Not continuing. Monitors size 0.");
            return nullptr;
        }
            
    }

    // Check the monitor rule
    for (auto& rule : ConfigManager::getMatchingRules(windowID)) {
        if (!PWINDOWINARR->getFirstOpen())
            break;

        if (rule.szRule.find("monitor") == 0) {
            try {
                const auto MONITOR = stoi(rule.szRule.substr(rule.szRule.find(" ") + 1));

                Debug::log(LOG, "Rule monitor, applying to window " + std::to_string(windowID));

                if (MONITOR > g_pWindowManager->monitors.size() || MONITOR < 0)
                    forcemonitor = -1;
                else
                    forcemonitor = MONITOR;
            } catch(...) {
                Debug::log(LOG, "Rule monitor failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        }

        if (rule.szRule.find("pseudo") == 0) {
            PWINDOWINARR->setIsPseudotiled(true);
        }

        if (rule.szRule.find("fullscreen") == 0) {
            PWINDOWINARR->setFullscreen(true);
        }

        if (rule.szRule.find("center") == 0) {
            nextWindowCentered = true;
        }

        if (rule.szRule.find("workspace") == 0) {
            try {
                const auto WORKSPACE = stoi(rule.szRule.substr(rule.szRule.find(" ") + 1));

                Debug::log(LOG, "Rule workspace, applying to window " + std::to_string(windowID));

                g_pWindowManager->changeWorkspaceByID(WORKSPACE);
                forcemonitor = g_pWindowManager->getWorkspaceByID(WORKSPACE)->getMonitor();
            } catch (...) {
                Debug::log(LOG, "Rule workspace failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        }
    }

    const auto CURRENTSCREEN = forcemonitor != -1 ? forcemonitor : PMONITOR->ID;
    PWINDOWINARR->setWorkspaceID(g_pWindowManager->activeWorkspaces[CURRENTSCREEN]);
    PWINDOWINARR->setMonitor(CURRENTSCREEN);

    // Window name
    const auto WINNAME = getWindowName(windowID);
    Debug::log(LOG, "New window got name: " + WINNAME);
    PWINDOWINARR->setName(WINNAME);

    const auto WINCLASSNAME = getClassName(windowID);
    Debug::log(LOG, "New window got class: " + WINCLASSNAME.second);
    PWINDOWINARR->setClassName(WINCLASSNAME.second);

    // For all floating windows, get their default size
    const auto GEOMETRYCOOKIE   = xcb_get_geometry(g_pWindowManager->DisplayConnection, windowID);
    const auto GEOMETRY         = xcb_get_geometry_reply(g_pWindowManager->DisplayConnection, GEOMETRYCOOKIE, 0);

    if (GEOMETRY) {
        PWINDOWINARR->setDefaultPosition(g_pWindowManager->monitors[CURRENTSCREEN].vecPosition);
        PWINDOWINARR->setDefaultSize(Vector2D(GEOMETRY->width, GEOMETRY->height));
    } else {
        Debug::log(ERR, "Geometry failed in remap.");

        PWINDOWINARR->setDefaultPosition(g_pWindowManager->monitors[CURRENTSCREEN].vecPosition);
        PWINDOWINARR->setDefaultSize(Vector2D(g_pWindowManager->Screen->width_in_pixels / 2.f, g_pWindowManager->Screen->height_in_pixels / 2.f));
    }

    if (PWINDOWINARR->getDefaultSize().x < 40 || PWINDOWINARR->getDefaultSize().y < 40) {
        // min size
        PWINDOWINARR->setDefaultSize(Vector2D(std::clamp(PWINDOWINARR->getDefaultSize().x, (double)40, (double)99999),
                                       std::clamp(PWINDOWINARR->getDefaultSize().y, (double)40, (double)99999)));
    }

    if (nextWindowCentered) {
        PWINDOWINARR->setDefaultPosition(g_pWindowManager->monitors[CURRENTSCREEN].vecPosition + g_pWindowManager->monitors[CURRENTSCREEN].vecSize / 2.f - PWINDOWINARR->getDefaultSize() / 2.f);
    }

    //
    // Dock Checks
    //
    const auto wm_type_cookie = xcb_get_property(g_pWindowManager->DisplayConnection, false, windowID, ZARISATOMS["_NET_WM_WINDOW_TYPE"], XCB_GET_PROPERTY_TYPE_ANY, 0, (4294967295U));
    const auto wm_type_cookiereply = xcb_get_property_reply(g_pWindowManager->DisplayConnection, wm_type_cookie, NULL);
    xcb_atom_t TYPEATOM = NULL;
    if (wm_type_cookiereply == NULL || xcb_get_property_value_length(wm_type_cookiereply) < 1) {
        Debug::log(LOG, "No preferred type found. (RemapFloatingWindow)");
    } else {
        const auto ATOMS = (xcb_atom_t*)xcb_get_property_value(wm_type_cookiereply);
        if (!ATOMS) {
            Debug::log(ERR, "Atoms not found in preferred type!");
        } else {
            if (xcbContainsAtom(wm_type_cookiereply, ZARISATOMS["_NET_WM_WINDOW_TYPE_DOCK"])) {
                // set to floating and set the immovable and nointerventions flag
                PWINDOWINARR->setImmovable(true);
                PWINDOWINARR->setNoInterventions(true);

                PWINDOWINARR->setDefaultPosition(Vector2D(GEOMETRY->x, GEOMETRY->y));
                PWINDOWINARR->setDefaultSize(Vector2D(GEOMETRY->width, GEOMETRY->height));

                PWINDOWINARR->setDockAlign(DOCK_TOP);

                // Check reserved
                const auto STRUTREPLY = xcb_get_property_reply(g_pWindowManager->DisplayConnection, xcb_get_property(g_pWindowManager->DisplayConnection, false, windowID, ZARISATOMS["_NET_WM_STRUT_PARTIAL"], XCB_GET_PROPERTY_TYPE_ANY, 0, (4294967295U)), NULL);

                if (!STRUTREPLY || xcb_get_property_value_length(STRUTREPLY) == 0) {
                    Debug::log(ERR, "Couldn't get strut for dock.");
                } else {
                    const uint32_t* STRUT = (uint32_t*)xcb_get_property_value(STRUTREPLY);

                    if (!STRUT) {
                        Debug::log(ERR, "Couldn't get strut for dock. (2)");
                    } else {
                        // Set the dock's align
                        // LEFT RIGHT TOP BOTTOM
                        //  0     1    2     3
                        if (STRUT[2] > 0 && STRUT[3] == 0) {
                            // top
                            PWINDOWINARR->setDockAlign(DOCK_TOP);
                        } else if (STRUT[2] == 0 && STRUT[3] > 0) {
                            // bottom
                            PWINDOWINARR->setDockAlign(DOCK_BOTTOM);
                        }

                        // little todo: support left/right docks
                    }
                }

                free(STRUTREPLY);

                Debug::log(LOG, "New dock created, setting default XYWH to: " + std::to_string(PWINDOWINARR->getDefaultPosition().x) + ", " + std::to_string(PWINDOWINARR->getDefaultPosition().y)
                    + ", " + std::to_string(PWINDOWINARR->getDefaultSize().x) + ", " + std::to_string(PWINDOWINARR->getDefaultSize().y));

                PWINDOWINARR->setDock(true);

                // since it's a dock get its monitor from the coords
                const auto CENTERVEC = PWINDOWINARR->getDefaultPosition() + (PWINDOWINARR->getDefaultSize() / 2.f);
                const auto MONITOR = g_pWindowManager->getMonitorFromCoord(CENTERVEC);
                if (MONITOR) {
                    PWINDOWINARR->setMonitor(MONITOR->ID);
                    Debug::log(LOG, "Guessed dock's monitor to be " + std::to_string(MONITOR->ID) + ".");
                } else {
                    Debug::log(LOG, "Couldn't guess dock's monitor. Leaving at " + std::to_string(PWINDOWINARR->getMonitor()) + ".");
                }

                // Reserve its workarea immediately - otherwise nothing reserves space for
                // this dock until (and unless) it later sends a resize request, and tiled
                // windows spawn underneath it in the meantime.
                g_pWindowManager->recalcAllDocks();
            }
        }
    }
    free(wm_type_cookiereply);
    //
    //
    //

    g_pWindowManager->getICCCMSizeHints(PWINDOWINARR);

    if (nextWindowCentered /* Basically means dialog */) {
        auto DELTA = PWINDOWINARR->getPseudoSize() - PWINDOWINARR->getDefaultSize();

        // update
        PWINDOWINARR->setDefaultSize(PWINDOWINARR->getPseudoSize());
        PWINDOWINARR->setDefaultPosition(PWINDOWINARR->getDefaultPosition() - DELTA / 2.f);
    }

    // Check the size and pos rules
    for (auto& rule : ConfigManager::getMatchingRules(windowID)) {
        if (!PWINDOWINARR->getFirstOpen())
            break;

        if (rule.szRule.find("size") == 0) {
            try {
                const auto VALUE = rule.szRule.substr(rule.szRule.find(" ") + 1);
                const auto SIZEX = stoi(VALUE.substr(0, VALUE.find(" ")));
                const auto SIZEY = stoi(VALUE.substr(VALUE.find(" ") + 1));

                Debug::log(LOG, "Rule size, applying to window " + std::to_string(windowID));

                PWINDOWINARR->setDefaultSize(Vector2D(SIZEX, SIZEY));
            } catch (...) {
                Debug::log(LOG, "Rule size failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        } else if (rule.szRule.find("move") == 0) {
            try {
                const auto VALUE = rule.szRule.substr(rule.szRule.find(" ") + 1);
                const auto POSX = stoi(VALUE.substr(0, VALUE.find(" ")));
                const auto POSY = stoi(VALUE.substr(VALUE.find(" ") + 1));

                Debug::log(LOG, "Rule move, applying to window " + std::to_string(windowID));

                PWINDOWINARR->setDefaultPosition(Vector2D(POSX, POSY) + g_pWindowManager->monitors[CURRENTSCREEN].vecPosition);
            } catch (...) {
                Debug::log(LOG, "Rule move failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        } else if (rule.szRule.find("topright") == 0) {
            // Like "move", but relative to the monitor's top-right corner instead
            // of its top-left - for a flyout that wants to sit under a bar icon
            // near that corner (e.g. Overflow.qml's "More" chevron) regardless of
            // the monitor's actual resolution. marginX/marginY are the gap from
            // the monitor's right/top edges to the window's right/top edges.
            try {
                const auto VALUE = rule.szRule.substr(rule.szRule.find(" ") + 1);
                const auto MARGINX = stoi(VALUE.substr(0, VALUE.find(" ")));
                const auto MARGINY = stoi(VALUE.substr(VALUE.find(" ") + 1));

                Debug::log(LOG, "Rule topright, applying to window " + std::to_string(windowID));

                const auto& MONITOR = g_pWindowManager->monitors[CURRENTSCREEN];
                PWINDOWINARR->setDefaultPosition(Vector2D(
                    MONITOR.vecPosition.x + MONITOR.vecSize.x - PWINDOWINARR->getDefaultSize().x - MARGINX,
                    MONITOR.vecPosition.y + MARGINY));
            } catch (...) {
                Debug::log(LOG, "Rule topright failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        } else if (rule.szRule.find("bottomcenter") == 0) {
            // Like "topright", but anchored to the bottom-center of the
            // monitor instead - for the floating-mode dock (Dock.qml),
            // horizontally centered regardless of the monitor's actual
            // resolution. marginY is the gap from the monitor's bottom edge
            // to the window's bottom edge.
            try {
                const auto MARGINY = stoi(rule.szRule.substr(rule.szRule.find(" ") + 1));

                Debug::log(LOG, "Rule bottomcenter, applying to window " + std::to_string(windowID));

                const auto& MONITOR = g_pWindowManager->monitors[CURRENTSCREEN];
                PWINDOWINARR->setDefaultPosition(Vector2D(
                    MONITOR.vecPosition.x + (MONITOR.vecSize.x - PWINDOWINARR->getDefaultSize().x) / 2.f,
                    MONITOR.vecPosition.y + MONITOR.vecSize.y - PWINDOWINARR->getDefaultSize().y - MARGINY));
            } catch (...) {
                Debug::log(LOG, "Rule bottomcenter failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        } else if (rule.szRule.find("topcenter") == 0) {
            // Mirror of "bottomcenter" - anchored to the top-center of the
            // monitor instead, for the floating-mode dock (Dock.qml) when
            // Settings' Dock position is "top". marginY is the gap from the
            // monitor's top edge to the window's top edge.
            try {
                const auto MARGINY = stoi(rule.szRule.substr(rule.szRule.find(" ") + 1));

                Debug::log(LOG, "Rule topcenter, applying to window " + std::to_string(windowID));

                const auto& MONITOR = g_pWindowManager->monitors[CURRENTSCREEN];
                PWINDOWINARR->setDefaultPosition(Vector2D(
                    MONITOR.vecPosition.x + (MONITOR.vecSize.x - PWINDOWINARR->getDefaultSize().x) / 2.f,
                    MONITOR.vecPosition.y + MARGINY));
            } catch (...) {
                Debug::log(LOG, "Rule topcenter failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        } else if (rule.szRule.find("leftcenter") == 0) {
            // Same family as "topcenter"/"bottomcenter", anchored to the
            // vertical center of the monitor's left edge instead - for the
            // floating-mode dock when Settings' Dock position is "left".
            // marginX is the gap from the monitor's left edge to the
            // window's left edge.
            try {
                const auto MARGINX = stoi(rule.szRule.substr(rule.szRule.find(" ") + 1));

                Debug::log(LOG, "Rule leftcenter, applying to window " + std::to_string(windowID));

                const auto& MONITOR = g_pWindowManager->monitors[CURRENTSCREEN];
                PWINDOWINARR->setDefaultPosition(Vector2D(
                    MONITOR.vecPosition.x + MARGINX,
                    MONITOR.vecPosition.y + (MONITOR.vecSize.y - PWINDOWINARR->getDefaultSize().y) / 2.f));
            } catch (...) {
                Debug::log(LOG, "Rule leftcenter failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        } else if (rule.szRule.find("rightcenter") == 0) {
            // Mirror of "leftcenter" - anchored to the vertical center of
            // the monitor's right edge, for the floating-mode dock when
            // Settings' Dock position is "right". marginX is the gap from
            // the monitor's right edge to the window's right edge.
            try {
                const auto MARGINX = stoi(rule.szRule.substr(rule.szRule.find(" ") + 1));

                Debug::log(LOG, "Rule rightcenter, applying to window " + std::to_string(windowID));

                const auto& MONITOR = g_pWindowManager->monitors[CURRENTSCREEN];
                PWINDOWINARR->setDefaultPosition(Vector2D(
                    MONITOR.vecPosition.x + MONITOR.vecSize.x - PWINDOWINARR->getDefaultSize().x - MARGINX,
                    MONITOR.vecPosition.y + (MONITOR.vecSize.y - PWINDOWINARR->getDefaultSize().y) / 2.f));
            } catch (...) {
                Debug::log(LOG, "Rule rightcenter failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        }
    }

    //

    PWINDOWINARR->setSize(PWINDOWINARR->getDefaultSize());
    PWINDOWINARR->setPosition(PWINDOWINARR->getDefaultPosition());

    // The anim util will take care of this.
    PWINDOWINARR->setEffectiveSize(PWINDOWINARR->getDefaultSize());
    PWINDOWINARR->setEffectivePosition(PWINDOWINARR->getDefaultPosition());

    // Also sets the old one
    g_pWindowManager->calculateNewWindowParams(PWINDOWINARR);

    Debug::log(LOG, "Created a new floating window! X: " + std::to_string(PWINDOWINARR->getPosition().x) + ", Y: " + std::to_string(PWINDOWINARR->getPosition().y) + ", W: " + std::to_string(PWINDOWINARR->getSize().x) + ", H:" + std::to_string(PWINDOWINARR->getSize().y) + " ID: " + std::to_string(windowID));

    // Set map values
    g_pWindowManager->Values[0] = XCB_EVENT_MASK_ENTER_WINDOW | XCB_EVENT_MASK_FOCUS_CHANGE;
    xcb_change_window_attributes_checked(g_pWindowManager->DisplayConnection, windowID, XCB_CW_EVENT_MASK, g_pWindowManager->Values);

    // Focus - remapWindow (tiled path) already does this; floating windows never did,
    // so a floating window (e.g. the Quickshell launcher) never got real X input focus
    // on creation/reshow, even though it might grab focus internally within its own
    // toolkit. Docks/panels shouldn't steal focus though.
    if (!PWINDOWINARR->getDock() && !PWINDOWINARR->getNoInterventions())
        g_pWindowManager->setFocusedWindow(windowID);

    // Fix docks
    if (PWINDOWINARR->getDock())
        g_pWindowManager->recalcAllDocks();

    nextWindowCentered = false;

    // Reset flags
    PWINDOWINARR->setConstructed(true);
    PWINDOWINARR->setFirstOpen(false);

    // Fullscreen rule
    if (PWINDOWINARR->getFullscreen()) {
        PWINDOWINARR->setFullscreen(false);
        g_pWindowManager->toggleWindowFullscrenn(PWINDOWINARR->getDrawable());
    }

    return PWINDOWINARR;
}

CWindow* Events::remapWindow(int windowID, bool wasfloating, int forcemonitor) {
    const auto PWINDOWINARR = g_pWindowManager->getWindowFromDrawable(windowID);

    if (!PWINDOWINARR) {
        Debug::log(ERR, "remapWindow called with an invalid window!");
        return nullptr;
    }
        

    PWINDOWINARR->setIsFloating(false);
    PWINDOWINARR->setDirty(true);

    auto PMONITOR = g_pWindowManager->getMonitorFromCursor();
    if (!PMONITOR) {
        Debug::log(ERR, "Monitor was null! (remapWindow) Using 0.");
        PMONITOR = &g_pWindowManager->monitors[0];

        if (g_pWindowManager->monitors.size() == 0) {
            Debug::log(ERR, "Not continuing. Monitors size 0.");
            return nullptr;
        }
    }

    // Check the monitor rule
    for (auto& rule : ConfigManager::getMatchingRules(windowID)) {
        if (!PWINDOWINARR->getFirstOpen())
            break;

        if (rule.szRule.find("monitor") == 0) {
            try {
                const auto MONITOR = stoi(rule.szRule.substr(rule.szRule.find(" ") + 1));

                Debug::log(LOG, "Rule monitor, applying to window " + std::to_string(windowID));

                if (MONITOR > g_pWindowManager->monitors.size() || MONITOR < 0)
                    forcemonitor = -1;
                else
                    forcemonitor = MONITOR;
            } catch (...) {
                Debug::log(LOG, "Rule monitor failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        }

        if (rule.szRule.find("pseudo") == 0) {
            PWINDOWINARR->setIsPseudotiled(true);
        }

        if (rule.szRule.find("fullscreen") == 0) {
            PWINDOWINARR->setFullscreen(true);
        }

        if (rule.szRule.find("workspace") == 0) {
            try {
                const auto WORKSPACE = stoi(rule.szRule.substr(rule.szRule.find(" ") + 1));

                Debug::log(LOG, "Rule workspace, applying to window " + std::to_string(windowID));

                g_pWindowManager->changeWorkspaceByID(WORKSPACE);
                forcemonitor = g_pWindowManager->getWorkspaceByID(WORKSPACE)->getMonitor();
            } catch (...) {
                Debug::log(LOG, "Rule workspace failed, rule: " + rule.szRule + "=" + rule.szValue);
            }
        }
    }

    if (g_pWindowManager->getWindowFromDrawable(g_pWindowManager->LastWindow) && forcemonitor == -1 && PMONITOR->ID != g_pWindowManager->getWindowFromDrawable(g_pWindowManager->LastWindow)->getMonitor()) {
        // If the monitor of the last window doesnt match the current screen force the monitor of the cursor
        forcemonitor = PMONITOR->ID;
    }

    const auto CURRENTSCREEN = forcemonitor != -1 ? forcemonitor : PMONITOR->ID;
    PWINDOWINARR->setWorkspaceID(g_pWindowManager->activeWorkspaces[CURRENTSCREEN]);
    PWINDOWINARR->setMonitor(CURRENTSCREEN);

    // Window name
    const auto WINNAME = getWindowName(windowID);
    Debug::log(LOG, "New window got name: " + WINNAME);
    PWINDOWINARR->setName(WINNAME);

    const auto WINCLASSNAME = getClassName(windowID);
    Debug::log(LOG, "New window got class: " + WINCLASSNAME.second);
    PWINDOWINARR->setClassName(WINCLASSNAME.second);

    // For all floating windows, get their default size
    const auto GEOMETRYCOOKIE = xcb_get_geometry(g_pWindowManager->DisplayConnection, windowID);
    const auto GEOMETRY = xcb_get_geometry_reply(g_pWindowManager->DisplayConnection, GEOMETRYCOOKIE, 0);

    if (GEOMETRY) {
        PWINDOWINARR->setDefaultPosition(Vector2D(GEOMETRY->x, GEOMETRY->y));
        PWINDOWINARR->setDefaultSize(Vector2D(GEOMETRY->width, GEOMETRY->height));
    } else {
        Debug::log(ERR, "Geometry failed in remap.");

        PWINDOWINARR->setDefaultPosition(Vector2D(0, 0));
        PWINDOWINARR->setDefaultSize(Vector2D(g_pWindowManager->Screen->width_in_pixels / 2.f, g_pWindowManager->Screen->height_in_pixels / 2.f));
    }

    // Check if the workspace has a fullscreen window. if so, remove its' fullscreen status.
    const auto PWORKSPACE = g_pWindowManager->getWorkspaceByID(g_pWindowManager->activeWorkspaces[CURRENTSCREEN]);
    if (PWORKSPACE && PWORKSPACE->getHasFullscreenWindow()) {
        const auto PFULLSCREENWINDOW = g_pWindowManager->getFullscreenWindowByWorkspace(PWORKSPACE->getID());

        if (PFULLSCREENWINDOW) {
            PFULLSCREENWINDOW->setFullscreen(false);
            PFULLSCREENWINDOW->setDirty(true);
            PWORKSPACE->setHasFullscreenWindow(false);
            g_pWindowManager->setAllWorkspaceWindowsDirtyByID(PWORKSPACE->getID());
        }
    }

    g_pWindowManager->getICCCMSizeHints(PWINDOWINARR);

    // Set the parent
    // check if lastwindow is on our workspace
    if (auto PLASTWINDOW = g_pWindowManager->getWindowFromDrawable(g_pWindowManager->LastWindow); (PLASTWINDOW && PLASTWINDOW->getWorkspaceID() == g_pWindowManager->activeWorkspaces[CURRENTSCREEN]) || wasfloating || (forcemonitor != -1 && forcemonitor != PMONITOR->ID) || PWINDOWINARR->getWorkspaceID() == SCRATCHPAD_ID) {
        // LastWindow is on our workspace, let's make a new split node

        if (PWINDOWINARR->getWorkspaceID() == SCRATCHPAD_ID)
            PLASTWINDOW = g_pWindowManager->findPreferredOnScratchpad();
        else {
            if (wasfloating || (forcemonitor != -1 && forcemonitor != PMONITOR->ID) || (forcemonitor != -1 && PLASTWINDOW->getWorkspaceID() != g_pWindowManager->activeWorkspaces[CURRENTSCREEN]) || PLASTWINDOW->getIsFloating()) {
                // if it's force monitor, find the first on a workspace.
                if ((forcemonitor != -1 && forcemonitor != PMONITOR->ID) || (forcemonitor != -1 && PLASTWINDOW->getWorkspaceID() != g_pWindowManager->activeWorkspaces[CURRENTSCREEN])) {
                    PLASTWINDOW = g_pWindowManager->findFirstWindowOnWorkspace(g_pWindowManager->activeWorkspaces[CURRENTSCREEN]);
                } else {
                    // find a window manually by the cursor
                    PLASTWINDOW = g_pWindowManager->findWindowAtCursor();
                }
            }
        }

        if (PLASTWINDOW && PLASTWINDOW->getDrawable() != windowID) {
            CWindow newWindowSplitNode;
            newWindowSplitNode.setPosition(PLASTWINDOW->getPosition());
            newWindowSplitNode.setSize(PLASTWINDOW->getSize());

            newWindowSplitNode.setChildNodeAID(PLASTWINDOW->getDrawable());
            newWindowSplitNode.setChildNodeBID(windowID);

            newWindowSplitNode.setParentNodeID(PLASTWINDOW->getParentNodeID());

            newWindowSplitNode.setWorkspaceID(PWINDOWINARR->getWorkspaceID());
            newWindowSplitNode.setMonitor(PWINDOWINARR->getMonitor());

            // generates a negative node ID
            newWindowSplitNode.generateNodeID();

            // update the parent if exists
            if (const auto PREVPARENT = g_pWindowManager->getWindowFromDrawable(PLASTWINDOW->getParentNodeID()); PREVPARENT) {
                if (PREVPARENT->getChildNodeAID() == PLASTWINDOW->getDrawable()) {
                    PREVPARENT->setChildNodeAID(newWindowSplitNode.getDrawable());
                } else {
                    PREVPARENT->setChildNodeBID(newWindowSplitNode.getDrawable());
                }
            }

            PWINDOWINARR->setParentNodeID(newWindowSplitNode.getDrawable());
            PLASTWINDOW->setParentNodeID(newWindowSplitNode.getDrawable());

            g_pWindowManager->addWindowToVectorSafe(newWindowSplitNode);
        } else {
            PWINDOWINARR->setParentNodeID(0);
        }
    } else {
        // LastWindow is not on our workspace, so set the parent to 0.
        PWINDOWINARR->setParentNodeID(0);
    }

    // For master layout, add the index
    PWINDOWINARR->setMasterChildIndex(g_pWindowManager->getWindowsOnWorkspace(g_pWindowManager->activeWorkspaces[CURRENTSCREEN]) - 1);
    // and set master if needed
    if (g_pWindowManager->getWindowsOnWorkspace(g_pWindowManager->activeWorkspaces[CURRENTSCREEN]) == 1) // 1 because the current window is already in the arr 
        PWINDOWINARR->setMaster(true);
    

    // Also sets the old one
    g_pWindowManager->calculateNewWindowParams(PWINDOWINARR);

    // Set real size. No animations in the beginning. Maybe later. TODO?
    PWINDOWINARR->setRealPosition(PWINDOWINARR->getEffectivePosition());
    PWINDOWINARR->setRealSize(PWINDOWINARR->getEffectiveSize());

    Debug::log(LOG, "Created a new tiled window! X: " + std::to_string(PWINDOWINARR->getPosition().x) + ", Y: " + std::to_string(PWINDOWINARR->getPosition().y) + ", W: " + std::to_string(PWINDOWINARR->getSize().x) + ", H:" + std::to_string(PWINDOWINARR->getSize().y) + " ID: " + std::to_string(windowID));

    // Set map values
    g_pWindowManager->Values[0] = XCB_EVENT_MASK_ENTER_WINDOW | XCB_EVENT_MASK_FOCUS_CHANGE;
    xcb_change_window_attributes_checked(g_pWindowManager->DisplayConnection, windowID, XCB_CW_EVENT_MASK, g_pWindowManager->Values);

    // make the last window top (animations look better)
    g_pWindowManager->setAWindowTop(g_pWindowManager->LastWindow);

    // Focus
    g_pWindowManager->setFocusedWindow(windowID);

    // Reset flags
    PWINDOWINARR->setConstructed(true);
    PWINDOWINARR->setFirstOpen(false);

    // Fullscreen rule
    if (PWINDOWINARR->getFullscreen()) {
        PWINDOWINARR->setFullscreen(false);
        g_pWindowManager->toggleWindowFullscrenn(PWINDOWINARR->getDrawable());
    }

    return PWINDOWINARR;
}

void Events::eventMapWindow(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_map_request_event_t*>(event);

    // Ignore sequence
    ignoredEvents.push_back(E->sequence);

    // Map the window
    xcb_map_window(g_pWindowManager->DisplayConnection, E->window);

    // We check if the window is not on our tile-blacklist and if it is, we have a special treatment procedure for it.
    // this func also sets some stuff

    // Check if it's not unmapped
    CWindow* pNewWindow = nullptr;
    if (g_pWindowManager->isWindowUnmapped(E->window)) {
        Debug::log(LOG, "Window was unmapped, mapping back.");
        g_pWindowManager->moveWindowToMapped(E->window);

        pNewWindow = g_pWindowManager->getWindowFromDrawable(E->window);
    } else {
        if (g_pWindowManager->getWindowFromDrawable(E->window)) {
            Debug::log(LOG, "Window already managed.");
            return;
        }

        if (!g_pWindowManager->shouldBeManaged(E->window)) {
            Debug::log(LOG, "window shouldn't be managed");
            return;
        }

        if (g_pWindowManager->scratchpadActive) {
            KeybindManager::toggleScratchpad("");

            const auto PNEW = g_pWindowManager->findWindowAtCursor();
            g_pWindowManager->LastWindow = PNEW ? PNEW->getDrawable() : 0;
        }

        CWindow window;
        window.setDrawable(E->window);
        g_pWindowManager->addWindowToVectorSafe(window);
        
        if (g_pWindowManager->shouldBeFloatedOnInit(E->window)) {
            Debug::log(LOG, "Window SHOULD be floating on start.");
            pNewWindow = remapFloatingWindow(E->window);
        } else {
            Debug::log(LOG, "Window should NOT be floating on start.");
            pNewWindow = remapWindow(E->window);
        }
    }

    if (!pNewWindow) {
        Debug::log(LOG, "Removing, NULL.");
        g_pWindowManager->removeWindowFromVectorSafe(E->window);
        return;
    }

    // Do post-creation checks.
    g_pWindowManager->doPostCreationChecks(pNewWindow);
    
    // Do ICCCM
    g_pWindowManager->getICCCMWMProtocols(pNewWindow);

    // Do transient checks
    EWMH::checkTransient(E->window);

    // Make all floating windows above
    g_pWindowManager->setAllFloatingWindowsTop();

    // Set not under
    pNewWindow->setUnderFullscreen(false);
    pNewWindow->setDirty(true);

    // EWMH
    EWMH::updateClientList();
    EWMH::setFrameExtents(E->window);
    EWMH::updateWindow(E->window);
}

// Quickshell's PopupWindow (Settings, Control Center, the taskbar-mode
// launcher, the calendar flyout, tooltips - anything anchored to the bar
// rather than opened as a real WM-managed floating window) is created as a
// genuine X11 override-redirect window, same reasoning eventEnter()'s own
// override-redirect skip already relies on for menus/tooltips (see its own
// comment). Override-redirect windows never send a MapRequest - the
// SubstructureRedirect that eventMapWindow()/XCB_MAP_REQUEST relies on
// specifically excludes them - so this is a separate hook on plain
// XCB_MAP_NOTIFY (already delivered for every child of root, override-
// redirect or not, since XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY is selected on
// root regardless) purely to catch these and register them for the
// "Settings/Control Center should stay always-on-top of other windows,
// except fullscreen ones" fix (reassertAlwaysOnTop(), called every event-
// loop tick from handleEvent()).
//
// There's no way at the X11 level to distinguish specifically Settings/
// Control Center from Quickshell's other PopupWindow-based popups (the
// calendar flyout, taskbar launcher, tooltips) - confirmed live via xprop:
// every one of them reports the same override_redirect=1 and the same
// _NET_WM_NAME "quickshell" (Quickshell's own app identity, not a per-
// window title - PopupWindow doesn't expose a title property at all, per
// ControlCenter.qml's own header comment) regardless of which QML file
// actually created it. Rather than guess at a narrower, unreliable
// heuristic, every Quickshell override-redirect popup gets treated as
// always-on-top uniformly - a tooltip or the calendar flyout getting
// covered by a newly raised window would be just as much a real bug as
// Settings/Control Center being covered, so this isn't overreach, just the
// only option X11 actually offers here.
//
// _NET_WM_WINDOW_TYPE is normally _NET_WM_WINDOW_TYPE_TOOLTIP for all of
// them (Quickshell's own default for PopupWindow) - except when a specific
// popup sets PopupWindow's built-in `grabFocus: true` (Launcher.qml's
// taskbar-mode variant, as of this fix), which flips it to
// _NET_WM_WINDOW_TYPE_NORMAL instead. That's a real, deliberate signal
// from the QML side, confirmed live via xprop (before/after adding
// grabFocus: true), not an incidental side effect - Quickshell has no
// other way to tell an X11 WM "this override-redirect popup wants real
// keyboard focus" (there's no MapRequest to react to, and confirmed live
// via a temporary ClientMessage-logging build that Quickshell never sends
// a _NET_ACTIVE_WINDOW request for these either). Both type atoms count as
// "this is one of ours" for always-on-top tracking; only the NORMAL one
// also gets real X11 input focus below - Tooltip.qml/CalendarFlyout.qml
// never set grabFocus and stay TOOLTIP-typed, so a hover-triggered tooltip
// can never rip keyboard focus away from whatever the user is actually
// typing into elsewhere, while a popup that deliberately opted in (the
// taskbar launcher's search field, potentially Settings' text fields
// later) gets it immediately on map - matching what the statusbar-mode
// FloatingWindow variant already gets for free from the WM's normal
// managed-window focus-on-map path (remapFloatingWindow).
void Events::eventMapNotify(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_map_notify_event_t*>(event);

    if (!E->override_redirect)
        return;

    const auto WMTYPEREPLY = xcb_get_property_reply(g_pWindowManager->DisplayConnection,
        xcb_get_property(g_pWindowManager->DisplayConnection, false, E->window, ZARISATOMS["_NET_WM_WINDOW_TYPE"], XCB_GET_PROPERTY_TYPE_ANY, 0, 4096), NULL);

    const bool ISTOOLTIPTYPE = WMTYPEREPLY && xcbContainsAtom(WMTYPEREPLY, ZARISATOMS["_NET_WM_WINDOW_TYPE_TOOLTIP"]);
    const bool ISNORMALTYPE = WMTYPEREPLY && xcbContainsAtom(WMTYPEREPLY, ZARISATOMS["_NET_WM_WINDOW_TYPE_NORMAL"]);

    if (WMTYPEREPLY)
        free(WMTYPEREPLY);

    if ((!ISTOOLTIPTYPE && !ISNORMALTYPE) || getWindowName(E->window) != "quickshell")
        return;

    if (std::find(g_pWindowManager->alwaysOnTopWindows.begin(), g_pWindowManager->alwaysOnTopWindows.end(), E->window) == g_pWindowManager->alwaysOnTopWindows.end()) {
        Debug::log(LOG, "Tracking new always-on-top Quickshell popup: " + std::to_string(E->window));
        g_pWindowManager->alwaysOnTopWindows.push_back(E->window);
    }

    if (ISNORMALTYPE) {
        Debug::log(LOG, "Quickshell popup " + std::to_string(E->window) + " requested grabFocus - giving it real X11 input focus.");
        xcb_set_input_focus(g_pWindowManager->DisplayConnection, XCB_INPUT_FOCUS_POINTER_ROOT, E->window, XCB_CURRENT_TIME);
    }
}

void Events::eventButtonPress(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_button_press_event_t*>(event);

    // mouse down!
    g_pWindowManager->mouseKeyDown = E->detail;

    if (const auto PLASTWINDOW = g_pWindowManager->getWindowFromDrawable(g_pWindowManager->LastWindow); PLASTWINDOW) {

        if (E->detail != 3)
            PLASTWINDOW->setDraggingTiled(!PLASTWINDOW->getIsFloating());

        g_pWindowManager->actingOnWindowFloating = PLASTWINDOW->getDrawable();
        g_pWindowManager->mouseLastPos = g_pWindowManager->getCursorPos();

        if (!PLASTWINDOW->getIsFloating()) {
            const auto PDRAWABLE = PLASTWINDOW->getDrawable();
            if (E->detail != 3) // right click (resize) does not
                KeybindManager::toggleActiveWindowFloating("");

            // refocus
            g_pWindowManager->setFocusedWindow(PDRAWABLE, true);
        }
    }

    xcb_grab_pointer(g_pWindowManager->DisplayConnection, 0, g_pWindowManager->Screen->root, XCB_EVENT_MASK_BUTTON_RELEASE | XCB_EVENT_MASK_BUTTON_MOTION | XCB_EVENT_MASK_POINTER_MOTION_HINT,
                     XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC,
                     g_pWindowManager->Screen->root, XCB_NONE, XCB_CURRENT_TIME);
}

void Events::eventButtonRelease(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_button_release_event_t*>(event);

    const auto PACTINGWINDOW = g_pWindowManager->getWindowFromDrawable(g_pWindowManager->actingOnWindowFloating);

    // ungrab the mouse ptr
    xcb_ungrab_pointer(g_pWindowManager->DisplayConnection, XCB_CURRENT_TIME);

    if (PACTINGWINDOW) {
        PACTINGWINDOW->setDirty(true);

        if (PACTINGWINDOW->getDraggingTiled()) {
            g_pWindowManager->LastWindow = PACTINGWINDOW->getDrawable();
            KeybindManager::toggleActiveWindowFloating("");
        }
            
    }

    g_pWindowManager->actingOnWindowFloating = 0;
    g_pWindowManager->mouseKeyDown = 0;
}

void Events::eventKeyPress(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_key_press_event_t*>(event);

    const auto KEYSYM = KeybindManager::getKeysymFromKeycode(E->detail);
    const auto IGNOREDMOD = KeybindManager::modToMask(ConfigManager::getString("ignore_mod"));

    for (auto& keybind : KeybindManager::keybinds) {
        if (keybind.getKeysym() != 0 && keybind.getKeysym() == KEYSYM && ((keybind.getMod() == E->state) || ((keybind.getMod() | IGNOREDMOD) == E->state))) {
            keybind.getDispatcher()(keybind.getCommand());
            return;
            // TODO: fix duplicating keybinds
        }
    }
}

void Events::eventMotionNotify(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_motion_notify_event_t*>(event);

    if (!g_pWindowManager->mouseKeyDown)
        return; // mouse up.

    if (!g_pWindowManager->actingOnWindowFloating)
        return; // not acting, return.

    // means we are holding super
    const auto POINTERPOS = g_pWindowManager->getCursorPos();
    const auto POINTERDELTA = Vector2D(POINTERPOS) - g_pWindowManager->mouseLastPos;

    const auto PACTINGWINDOW = g_pWindowManager->getWindowFromDrawable(g_pWindowManager->actingOnWindowFloating);

    if (!PACTINGWINDOW) {
        Debug::log(ERR, "ActingWindow not null but doesn't exist?? (Died?)");
        g_pWindowManager->actingOnWindowFloating = 0;
        return;
    }

    if (abs(POINTERDELTA.x) < 1 && abs(POINTERDELTA.y) < 1)
        return; // micromovements

    if (g_pWindowManager->mouseKeyDown == 1) {
        // moving
        PACTINGWINDOW->setPosition(PACTINGWINDOW->getPosition() + POINTERDELTA);
        PACTINGWINDOW->setEffectivePosition(PACTINGWINDOW->getPosition());
        PACTINGWINDOW->setDefaultPosition(PACTINGWINDOW->getPosition());
        PACTINGWINDOW->setRealPosition(PACTINGWINDOW->getPosition());

        // update workspace if needed
        if (g_pWindowManager->getMonitorFromCursor()) {
            const auto WORKSPACE = g_pWindowManager->activeWorkspaces[g_pWindowManager->getMonitorFromCursor()->ID];
            PACTINGWINDOW->setWorkspaceID(WORKSPACE);
        } else {
            Debug::log(WARN, "Monitor was nullptr! Ignoring workspace change in MouseMoveEvent.");
        } 

        PACTINGWINDOW->setDirty(true);
    } else if (g_pWindowManager->mouseKeyDown == 3) {

        if (!PACTINGWINDOW->getIsFloating()) {
            g_pWindowManager->processCursorDeltaOnWindowResizeTiled(PACTINGWINDOW, POINTERDELTA);
        } else {
            // resizing
            PACTINGWINDOW->setSize(PACTINGWINDOW->getSize() + POINTERDELTA);
            // clamp
            PACTINGWINDOW->setSize(Vector2D(std::clamp(PACTINGWINDOW->getSize().x, (double)30, (double)999999), std::clamp(PACTINGWINDOW->getSize().y, (double)30, (double)999999)));

            // apply to other
            PACTINGWINDOW->setDefaultSize(PACTINGWINDOW->getSize());
            PACTINGWINDOW->setEffectiveSize(PACTINGWINDOW->getSize());
            PACTINGWINDOW->setRealSize(PACTINGWINDOW->getSize());
            PACTINGWINDOW->setPseudoSize(PACTINGWINDOW->getSize());
        }

        PACTINGWINDOW->setDirty(true);
    }

    g_pWindowManager->mouseLastPos = POINTERPOS;
}

void Events::eventExpose(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_expose_event_t*>(event);

    // nothing
}

void Events::eventClientMessage(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_client_message_event_t*>(event);

    g_pWindowManager->handleClientMessage(E); // Client message handling
}

void Events::eventConfigure(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_configure_request_event_t*>(event);

    Debug::log(LOG, "Window " + std::to_string(E->window) + " requests XY: " + std::to_string(E->x) + ", " + std::to_string(E->y) + ", WH: " + std::to_string(E->width) + "x" + std::to_string(E->height));

    auto *const PWINDOW = g_pWindowManager->getWindowFromDrawable(E->window);

    if (!PWINDOW) {
        // Not managed yet - most commonly because the client is configuring itself
        // before mapping (completely normal ICCCM behavior: create, configure, then
        // map). We still own SubstructureRedirect on root, so nobody else will ever
        // grant this request - if we don't, the window sits at whatever geometry it
        // had at creation (often a tiny placeholder) until it maps, and we'll end up
        // managing it at the wrong initial size.
        uint32_t values[7];
        int      i = 0;
        if (E->value_mask & XCB_CONFIG_WINDOW_X) values[i++] = E->x;
        if (E->value_mask & XCB_CONFIG_WINDOW_Y) values[i++] = E->y;
        if (E->value_mask & XCB_CONFIG_WINDOW_WIDTH) values[i++] = E->width;
        if (E->value_mask & XCB_CONFIG_WINDOW_HEIGHT) values[i++] = E->height;
        if (E->value_mask & XCB_CONFIG_WINDOW_BORDER_WIDTH) values[i++] = E->border_width;
        if (E->value_mask & XCB_CONFIG_WINDOW_SIBLING) values[i++] = E->sibling;
        if (E->value_mask & XCB_CONFIG_WINDOW_STACK_MODE) values[i++] = E->stack_mode;

        xcb_configure_window(g_pWindowManager->DisplayConnection, E->window, E->value_mask, values);

        Debug::log(LOG, "CONFIGURE: Window not yet managed, granting pre-map request as-is.");
        return;
    }

    if (!PWINDOW->getIsFloating()) {
        Debug::log(LOG, "CONFIGURE: Window isn't floating, ignoring.");
        return;
    }

    const auto OLDDEFAULTPOS = PWINDOW->getDefaultPosition();
    const auto OLDDEFAULTSIZE = PWINDOW->getDefaultSize();

    PWINDOW->setDefaultPosition(Vector2D(E->x, E->y));
    PWINDOW->setDefaultSize(Vector2D(E->width, E->height));
    PWINDOW->setEffectiveSize(PWINDOW->getDefaultSize());
    PWINDOW->setEffectivePosition(PWINDOW->getDefaultPosition());
    // Position/Size (as opposed to Default/EffectivePosition/Size above) are
    // what recalcAllDocks() itself reads to decide which screen edge a dock
    // window's reserved space belongs on (see its top/bottom/left/right
    // check against getPosition()/getSize()). Only Default/Effective used to
    // get updated here, so a dock that moves at runtime without remapping -
    // e.g. Zaris's own bar toggling BarConfig.position between "top" and
    // "bottom" - kept reporting its OLD position/size to recalcAllDocks()
    // forever after the first map, since nothing ever refreshed Position/
    // Size past that point. recalcAllDocks() then reserved space on the
    // stale edge while the window itself visibly moved to the new one (that
    // part already worked, since it moves the window using
    // getDefaultPosition()/getDefaultSize()), leaving the old edge's
    // reserved gap permanently unreclaimed and the new edge under-reserved.
    PWINDOW->setPosition(PWINDOW->getDefaultPosition());
    PWINDOW->setSize(PWINDOW->getDefaultSize());

    // Docks (bars/panels) often resize themselves shortly after mapping, once their
    // content finishes laying out (e.g. Quickshell's QML bindings resolve a tick late).
    // The reserved workarea was computed from the dock's geometry at map time, so it
    // needs to be recalculated here too, or a dock that grows post-map never gets its
    // space reserved and tiled windows can end up underneath it.
    //
    // Only do this if the geometry actually changed: recalcAllDocks() re-asserts the
    // dock's geometry via xcb_configure_window, which itself can nudge a reactive QML
    // layout to re-request the "same" size a fraction of a pixel off. Recalculating on
    // every request regardless of whether anything changed turns that into a
    // self-sustaining request/grant loop that pegs the WM and locks up the desktop.
    const bool GEOMETRYCHANGED = OLDDEFAULTPOS.x != PWINDOW->getDefaultPosition().x || OLDDEFAULTPOS.y != PWINDOW->getDefaultPosition().y ||
                                  OLDDEFAULTSIZE.x != PWINDOW->getDefaultSize().x || OLDDEFAULTSIZE.y != PWINDOW->getDefaultSize().y;

    if (PWINDOW->getDock() && GEOMETRYCHANGED) {
        g_pWindowManager->recalcAllDocks();
    } else if (GEOMETRYCHANGED) {
        // recalcAllDocks() above is what actually pushes a dock's granted
        // geometry to the X server via xcb_configure_window - for any other
        // floating window, nothing ever did that, so a non-dock floating
        // window resizing itself post-map (e.g. Dock.qml's "floating" mode
        // growing/shrinking as icons come and go) had its internal
        // bookkeeping (setDefaultSize/setEffectiveSize above) updated with
        // nothing ever applied on screen - the window just stayed its old
        // size, matching the "resizes fine in reserved mode, not floating"
        // report exactly, since reserved mode is dock-type and already
        // went through recalcAllDocks().
        uint32_t configValues[2];
        configValues[0] = static_cast<uint32_t>(PWINDOW->getDefaultPosition().x);
        configValues[1] = static_cast<uint32_t>(PWINDOW->getDefaultPosition().y);
        xcb_configure_window(g_pWindowManager->DisplayConnection, E->window, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y, configValues);
        configValues[0] = static_cast<uint32_t>(PWINDOW->getDefaultSize().x);
        configValues[1] = static_cast<uint32_t>(PWINDOW->getDefaultSize().y);
        xcb_configure_window(g_pWindowManager->DisplayConnection, E->window, XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, configValues);
    }
}

void Events::eventRandRScreenChange(xcb_generic_event_t* event) {

    // fix sus randr events, that sometimes happen
    // it will spam these for no reason
    // so we check if we have > 9 consecutive randr events less than 1s between each
    // and if so, we stop listening for them
    const auto DELTA = std::chrono::duration_cast<std::chrono::milliseconds>(lastRandREvent - std::chrono::high_resolution_clock::now());

    if (susRandREventNo < 10) {
        if (DELTA.count() <= 1000) {
            susRandREventNo += 1;
            Debug::log(WARN, "Suspicious RandR event no. " + std::to_string(susRandREventNo) + "!");
            if (susRandREventNo > 9)
                Debug::log(WARN, "Disabling RandR event listening because of excess suspicious RandR events (bug!)");
        }
        else
            susRandREventNo = 0;
    }

    if (susRandREventNo > 9)
        return; 
    // randr sus fixed
    //

    // redetect screens
    g_pWindowManager->monitors.clear();
    g_pWindowManager->setupRandrMonitors();

    // Detect monitors that are incorrect
    // Orphaned workspaces
    for (auto& w : g_pWindowManager->workspaces) {
        if (w.getMonitor() >= g_pWindowManager->monitors.size())
            w.setMonitor(0);
    }

    // Empty monitors
    bool fineMonitors[g_pWindowManager->monitors.size()];
    for (int i = 0; i < g_pWindowManager->monitors.size(); ++i)
        fineMonitors[i] = false;

    for (auto& w : g_pWindowManager->workspaces) {
        fineMonitors[w.getMonitor()] = true;
    }

    for (int i = 0; i < g_pWindowManager->monitors.size(); ++i) {
        if (!fineMonitors[i]) {
            // add a workspace
            CWorkspace newWorkspace;
            newWorkspace.setMonitor(i);
            newWorkspace.setID(g_pWindowManager->getHighestWorkspaceID() + 1);
            newWorkspace.setHasFullscreenWindow(false);
            newWorkspace.setLastWindow(0);
            g_pWindowManager->workspaces.push_back(newWorkspace);
        }
    }

    // reload the config to update the bar too
    ConfigManager::loadConfigLoadVars();

    // Make all windows dirty and recalc all workspaces
    g_pWindowManager->recalcAllWorkspaces();
}

// Milestone 1 of ROADMAP.md's compositor plan - only ever dispatched when
// CompositingEnabled is true (see recieveEvent()'s own dispatch check), so
// this is unreachable, and thus a complete no-op, on any build/session
// that hasn't explicitly turned the feature on. Right now this only logs
// and acknowledges the damage; no redraw step exists yet (that's milestone
// 2 onward) - `xcb_damage_subtract` is not optional busywork here, it's
// required by the Damage protocol itself: without it, the X server
// considers the region still damaged and won't send another non-empty
// notification for it, so real repaint tracking would silently stop
// working after each window's very first damage event.
void Events::eventDamageNotify(xcb_generic_event_t* event) {
    const auto E = reinterpret_cast<xcb_damage_notify_event_t*>(event);

    Debug::log(LOG, "Damage notify on window " + std::to_string(E->drawable) +
                         " (damage object " + std::to_string(E->damage) + ")");

    xcb_damage_subtract(g_pWindowManager->DisplayConnection, E->damage, XCB_NONE, XCB_NONE);
}