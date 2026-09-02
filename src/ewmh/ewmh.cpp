#include "ewmh.hpp"
#include "../windowManager.hpp"

namespace {
    // EWMH desktops must be a contiguous 0-indexed range, but Hypr's workspace
    // IDs are arbitrary and can have gaps (e.g. jumping straight to workspace 47).
    // These helpers map the set of currently-existing (non-scratchpad) workspace
    // IDs, sorted ascending, onto that 0..N-1 desktop index space.
    std::vector<int> sortedDesktopWorkspaceIDs() {
        std::vector<int> ids;
        for (auto& w : g_pWindowManager->workspaces) {
            if (w.getID() != SCRATCHPAD_ID)
                ids.push_back(w.getID());
        }
        std::sort(ids.begin(), ids.end());
        return ids;
    }

    int desktopIndexForWorkspaceID(const std::vector<int>& sortedIDs, int workspaceID) {
        const auto IT = std::find(sortedIDs.begin(), sortedIDs.end(), workspaceID);
        if (IT == sortedIDs.end())
            return 0;
        return std::distance(sortedIDs.begin(), IT);
    }

    // CWindowManager::getMonitorFromWorkspace is private; reimplemented here off its public members.
    SMonitor* monitorForWorkspaceID(int workspaceID) {
        for (auto& w : g_pWindowManager->workspaces) {
            if (w.getID() != workspaceID)
                continue;

            for (auto& m : g_pWindowManager->monitors) {
                if (m.ID == w.getMonitor())
                    return &m;
            }

            break;
        }

        return nullptr;
    }
}

void EWMH::setupInitEWMH() {
    Debug::log(LOG, "EWMH init!");

    EWMHwindow = xcb_generate_id(g_pWindowManager->DisplayConnection);

    Debug::log(LOG, "Allocated ID " + std::to_string(EWMHwindow) + " for the EWMH window.");

    uint32_t values[1] = {1};
    xcb_create_window(g_pWindowManager->DisplayConnection, XCB_COPY_FROM_PARENT, EWMHwindow, g_pWindowManager->Screen->root,
        -1, -1, 1, 1, 0, XCB_WINDOW_CLASS_INPUT_ONLY, XCB_COPY_FROM_PARENT, 0, values);

    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, EWMHwindow, HYPRATOMS["_NET_SUPPORTING_WM_CHECK"], XCB_ATOM_WINDOW, 32, 1, &EWMHwindow);
    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, EWMHwindow, HYPRATOMS["_NET_WM_NAME"], HYPRATOMS["UTF8_STRING"], 8, strlen("Hypr"), "Hypr");
    
    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_WM_NAME"], HYPRATOMS["UTF8_STRING"], 8, strlen("Hypr"), "Hypr");
    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_SUPPORTING_WM_CHECK"], XCB_ATOM_WINDOW, 32, 1, &EWMHwindow);
    
    // Atoms EWMH

    xcb_atom_t supportedAtoms[HYPRATOMS.size()];
    int i = 0;
    for (auto& a : HYPRATOMS) {
        supportedAtoms[i] = a.second;
        i++;
    }

    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_SUPPORTED"], XCB_ATOM_ATOM, 32, sizeof(supportedAtoms) / sizeof(xcb_atom_t), supportedAtoms);

    // delete workarea
    xcb_delete_property(g_pWindowManager->DisplayConnection, g_pWindowManager->Screen->root, HYPRATOMS["_NET_WORKAREA"]);

    Debug::log(LOG, "EWMH init done.");
}

void EWMH::updateCurrentWindow(xcb_window_t w) {
    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_ACTIVE_WINDOW"], XCB_ATOM_WINDOW, 32, 1, &w);
}

void EWMH::updateClientList() {
    std::vector<xcb_window_t> windowsList;

    for (auto& w : g_pWindowManager->windows)
        if (w.getDrawable() > 0 && !w.getIsFloating())
            windowsList.push_back(w.getDrawable());

    // hack
    xcb_window_t* ArrWindowList = &windowsList[0];

    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_CLIENT_LIST"], XCB_ATOM_WINDOW,
        32, windowsList.size(), ArrWindowList);

    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_CLIENT_LIST_STACKING"], XCB_ATOM_WINDOW,
        32, windowsList.size(), ArrWindowList);
}

void EWMH::refreshAllExtents() {
    for (auto& w : g_pWindowManager->windows)
        if (w.getDrawable() > 0)
	    setFrameExtents(w.getDrawable());
}

void EWMH::setFrameExtents(xcb_window_t w) {
    const auto BORDERSIZE = ConfigManager::getInt("border_size");
    uint32_t extents[4] = {BORDERSIZE,BORDERSIZE,BORDERSIZE,BORDERSIZE};
    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, w, HYPRATOMS["_NET_FRAME_EXTENTS"], XCB_ATOM_CARDINAL, 32, 4, &extents);
}

void EWMH::updateDesktops() {

    const auto SORTEDIDS = sortedDesktopWorkspaceIDs();

    int activeWorkspaceID = -1;

    if (const auto PMONITOR = g_pWindowManager->getMonitorFromCursor(); PMONITOR) {
        activeWorkspaceID = g_pWindowManager->activeWorkspaces[PMONITOR->ID];
    } else if (const auto PWINDOW = g_pWindowManager->getWindowFromDrawable(g_pWindowManager->LastWindow); PWINDOW) {
        Debug::log(ERR, "Monitor was null! (updateDesktops EWMH) Using LastWindow's workspace.");
        activeWorkspaceID = PWINDOW->getWorkspaceID();
    } else if (!SORTEDIDS.empty()) {
        activeWorkspaceID = SORTEDIDS[0];
    }

    const int ACTIVEDESKTOPINDEX = desktopIndexForWorkspaceID(SORTEDIDS, activeWorkspaceID);
    const int ALLDESKTOPS = SORTEDIDS.size();

    // Skip the (relatively expensive) property updates if nothing pagers/bars
    // care about has actually changed since last tick.
    if (DesktopInfo::lastid == ACTIVEDESKTOPINDEX && DesktopInfo::lastCount == ALLDESKTOPS)
        return;

    DesktopInfo::lastid = ACTIVEDESKTOPINDEX;
    DesktopInfo::lastCount = ALLDESKTOPS;

    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_CURRENT_DESKTOP"], XCB_ATOM_CARDINAL, 32, 1, &ACTIVEDESKTOPINDEX);
    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_NUMBER_OF_DESKTOPS"], XCB_ATOM_CARDINAL, 32, 1, &ALLDESKTOPS);

    // Desktop names: workspace IDs stringified, in sorted order, NUL-separated (UTF8_STRING per EWMH spec)
    std::string namesBlob;
    for (const auto& id : SORTEDIDS) {
        namesBlob += std::to_string(id);
        namesBlob += '\0';
    }

    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_DESKTOP_NAMES"], HYPRATOMS["UTF8_STRING"], 8, namesBlob.size(), namesBlob.data());

    // Desktop viewport: top-left of the monitor each desktop currently lives on
    std::vector<uint32_t> workspaceCoords;
    workspaceCoords.reserve(SORTEDIDS.size() * 2);
    for (const auto& id : SORTEDIDS) {
        const auto PMONITOR = monitorForWorkspaceID(id);
        workspaceCoords.push_back(PMONITOR ? (uint32_t)PMONITOR->vecPosition.x : 0);
        workspaceCoords.push_back(PMONITOR ? (uint32_t)PMONITOR->vecPosition.y : 0);
    }

    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, g_pWindowManager->Screen->root, HYPRATOMS["_NET_DESKTOP_VIEWPORT"], XCB_ATOM_CARDINAL, 32, workspaceCoords.size(), workspaceCoords.data());
}

void EWMH::updateWindow(xcb_window_t win) {
    const auto PWINDOW = g_pWindowManager->getWindowFromDrawable(win);

    if (!PWINDOW || win < 1)
        return;

    uint32_t desktopIndex = 0xFFFFFFFF; // EWMH sentinel: not associated with any single desktop
    if (PWINDOW->getWorkspaceID() != SCRATCHPAD_ID)
        desktopIndex = desktopIndexForWorkspaceID(sortedDesktopWorkspaceIDs(), PWINDOW->getWorkspaceID());

    xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, win, HYPRATOMS["_NET_WM_DESKTOP"], XCB_ATOM_CARDINAL, 32, 1, &desktopIndex);

    // ICCCM State Normal
    if (!PWINDOW->getDock()) {
        long data[] = {XCB_ICCCM_WM_STATE_NORMAL, XCB_NONE};
        xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_REPLACE, win, HYPRATOMS["WM_STATE"], HYPRATOMS["WM_STATE"], 32, 2, data);

        if (PWINDOW->getDrawable() == g_pWindowManager->LastWindow) {
            uint32_t dataa[] = {HYPRATOMS["_NET_WM_STATE_FOCUSED"]};
            xcb_change_property(g_pWindowManager->DisplayConnection, XCB_PROP_MODE_APPEND, PWINDOW->getDrawable(), HYPRATOMS["_NET_WM_STATE"], XCB_ATOM_ATOM, 32, 1, dataa);
        } else {
            removeAtom(PWINDOW->getDrawable(), HYPRATOMS["_NET_WM_STATE"], HYPRATOMS["_NET_WM_STATE_FOCUSED"]);
        }
    }
}

int EWMH::workspaceIDFromDesktopIndex(int index) {
    const auto SORTEDIDS = sortedDesktopWorkspaceIDs();
    if (index < 0 || index >= (int)SORTEDIDS.size())
        return -1;
    return SORTEDIDS[index];
}

void EWMH::checkTransient(xcb_window_t window) {

    const auto PWINDOW = g_pWindowManager->getWindowFromDrawable(window);

    if (!PWINDOW)
        return;

    // Check if it's a transient
    const auto TRANSIENTCOOKIE = xcb_get_property(g_pWindowManager->DisplayConnection, false, window, 68 /* TRANSIENT_FOR */, XCB_GET_PROPERTY_TYPE_ANY, 0, UINT32_MAX);
    const auto TRANSIENTREPLY = xcb_get_property_reply(g_pWindowManager->DisplayConnection, TRANSIENTCOOKIE, NULL);

    if (!TRANSIENTREPLY || xcb_get_property_value_length(TRANSIENTREPLY) == 0) {
        Debug::log(WARN, "Transient check failed.");
        return;
    }

    xcb_window_t transientWindow;
    if (!xcb_icccm_get_wm_transient_for_from_reply(&transientWindow, TRANSIENTREPLY)) {
        Debug::log(WARN, "Transient reply failed.");
        free(TRANSIENTREPLY);
        return;
    }

    // set the flags
    const auto PPARENTWINDOW = g_pWindowManager->getWindowFromDrawable(transientWindow);

    if (!PPARENTWINDOW) {
        free(TRANSIENTREPLY);
        Debug::log(LOG, "Transient set for a nonexistent window, ignoring.");
        return;
    }

    PPARENTWINDOW->addTransientChild(window);

    Debug::log(LOG, "Added a transient child to " + std::to_string(transientWindow) + ".");

    free(TRANSIENTREPLY);
}