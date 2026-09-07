/*

ZarisWM Window Manager for X.
Forked from Hypr, started by Vaxry on 2021 / 11 / 17

*/

#include <cstdio>
#include <fstream>
#include <csignal>
#include "windowManager.hpp"
#include "defines.hpp"

int main(int argc, char** argv) {
    // stdout is fully-buffered (not line-buffered) by default whenever it's
    // not attached to a terminal - which is always true for how this WM
    // actually runs (launched via a session script, its own stdout usually
    // redirected to something like ~/.xsession-errors). Without this, log
    // output sits in libc's internal buffer until it either fills (several KB)
    // or the process exits - for a long-lived process that logs in modest
    // bursts, that can mean nothing ever reaches disk while it's actually
    // useful for debugging a live problem.
    setvbuf(stdout, nullptr, _IOLBF, 0);

    clearLogs();

    // Reap exec/exec-once children automatically instead of leaving zombies.
    signal(SIGCHLD, SIG_IGN);

    Debug::log(LOG, "ZarisWM debug log. Built on " + std::string(__DATE__) + " at " + std::string(__TIME__));

    g_pWindowManager->DisplayConnection = xcb_connect(NULL, NULL);
    if (const auto RET = xcb_connection_has_error(g_pWindowManager->DisplayConnection); RET != 0) {
        Debug::log(CRIT, "Connection Failed! Return: " + std::to_string(RET));
        return RET;
    }

    g_pWindowManager->Screen = xcb_setup_roots_iterator(xcb_get_setup(g_pWindowManager->DisplayConnection)).data;

    if (!g_pWindowManager->Screen) {
        Debug::log(CRIT, "Screen was null!");
        return 1;
    }

    // get atoms
    for (auto& ATOM : ZARISATOMS) {
        xcb_intern_atom_cookie_t cookie = xcb_intern_atom(g_pWindowManager->DisplayConnection, 0, ATOM.first.length(), ATOM.first.c_str());
        xcb_intern_atom_reply_t* reply = xcb_intern_atom_reply(g_pWindowManager->DisplayConnection, cookie, NULL);

        if (!reply) {
            Debug::log(ERR, "Atom failed: " + ATOM.first);
            continue;
        }

        ATOM.second = reply->atom;
    }

    g_pWindowManager->setupManager();

    Debug::log(LOG, "ZarisWM Started!");

    while (g_pWindowManager->handleEvent()) {
        ;
    }

    Debug::log(LOG, "ZarisWM reached the end! Exiting...");

    xcb_disconnect(g_pWindowManager->DisplayConnection);

    if (const auto err = xcb_connection_has_error(g_pWindowManager->DisplayConnection); err != 0) {
        Debug::log(CRIT, "Exiting because of error " + std::to_string(err));
        return err;
    }

    return 0;
}