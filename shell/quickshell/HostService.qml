pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Host/user identity info - distro name + logo, resolved display name, and
// hostname (adapted from Services/System/HostService.qml, MIT licensed,
// v4.7.7 - see README.md's "Third-party code" section). No current use
// site yet (no About panel or user-facing header exists to show any of
// this), ported as a foundation piece the way MediaService/WallpaperService
// were - genuinely useful, zero Wayland/compositor coupling, and not
// redundant with anything Zaris's own bar modules already read (those
// cover CPU/kernel/network, not host/user identity). Dropped the
// `NOCTALIA_REALNAME` env-var override (Noctalia-specific env var name,
// no Zaris equivalent) and `Logger.*` calls (no such logging singleton
// here).
Singleton {
    id: root

    property string osPretty: ""
    property string osLogo: ""
    property bool isNixOS: false
    property bool isReady: false

    readonly property string username: (Quickshell.env("USER") || "")
    property string realName: ""

    property string hostName: ""

    property string pendingLogoName: ""

    readonly property string displayName: {
        if (realName && realName.length > 0)
            return realName
        if (username && username.length > 0)
            return username
        return "User"
    }

    function buildCandidates(name) {
        const n = (name || "").trim()
        if (!n)
            return []

        const sizes = ["512x512", "256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "22x22", "16x16"]
        const exts = ["svg", "png"]
        const candidates = []

        for (const ext of exts)
            candidates.push(`/usr/share/pixmaps/${n}.${ext}`)

        candidates.push(`/usr/share/icons/hicolor/scalable/apps/${n}.svg`)
        for (const s of sizes) {
            for (const ext of exts)
                candidates.push(`/usr/share/icons/hicolor/${s}/apps/${n}.${ext}`)
        }

        for (const ext of exts) {
            candidates.push(`/usr/share/icons/${n}.${ext}`)
            candidates.push(`/usr/share/icons/${n}/${n}.${ext}`)
            candidates.push(`/usr/share/icons/${n}/apps/${n}.${ext}`)
        }

        return candidates
    }

    function resolveLogo(name) {
        const n = (name || "").trim()
        if (!n)
            return

        try {
            const path = Quickshell.iconPath(n, "")
            if (path && path !== "" && !path.startsWith("image://")) {
                root.osLogo = path.startsWith("file://") ? path : "file://" + path
                return
            }
        } catch (e) {
            // fall through to manual probe
        }

        root.pendingLogoName = n
        const all = buildCandidates(n)
        if (all.length === 0) {
            root.osLogo = `image://icon/${n}`
            return
        }
        const script = all.map(p => `if [ -f "${p}" ]; then echo "${p}"; exit 0; fi`).join("; ") + "; exit 1"
        probe.command = ["sh", "-c", script]
        probe.running = true
    }

    FileView {
        id: osInfo
        path: "/etc/os-release"
        onLoaded: {
            try {
                const lines = text().split("\n")
                const val = k => {
                    const l = lines.find(x => x.startsWith(k + "="))
                    return l ? l.split("=")[1].replace(/"/g, "") : ""
                }
                root.osPretty = val("PRETTY_NAME") || val("NAME")

                const osId = (val("ID") || "").toLowerCase()
                root.isNixOS = osId === "nixos" || (root.osPretty || "").toLowerCase().includes("nixos")
                const logoName = val("LOGO")
                if (logoName)
                    resolveLogo(logoName)
                root.isReady = true
            } catch (e) {
                // /etc/os-release missing or unparseable - leave defaults
            }
        }
    }

    Process {
        id: probe
        onExited: code => {
            const p = String(stdout.text || "").trim()
            if (code === 0 && p) {
                root.osLogo = `file://${p}`
                root.pendingLogoName = ""
            } else if (root.pendingLogoName) {
                root.osLogo = `image://icon/${root.pendingLogoName}`
                root.pendingLogoName = ""
            } else {
                root.osLogo = ""
            }
        }
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // Resolve GECOS real name once on startup.
    Process {
        id: realNameProcess
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const name = String(text || "").trim()
                if (name.length > 0)
                    root.realName = name
            }
        }
        stderr: StdioCollector {}
    }

    // Prefer /etc/hostname, fallback to Gentoo/OpenRC's /etc/conf.d/hostname.
    Process {
        id: hostNameProcess
        command: ["sh", "-c",
            "if [ -r /etc/hostname ]; then sed -n '1p' /etc/hostname; exit 0; fi; if [ -r /etc/conf.d/hostname ]; then v=$(sed -n -E 's/^[[:space:]]*[Hh][Oo][Ss][Tt][Nn][Aa][Mm][Ee][[:space:]]*=[[:space:]]*//p' /etc/conf.d/hostname | sed -n '1p'); v=$(printf '%s' \"$v\" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^\"//; s/\"$//; s/^\x27//; s/\x27$//'); printf '%s\n' \"$v\"; exit 0; fi; exit 0"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const name = String(text || "").trim()
                if (name.length > 0)
                    root.hostName = name
            }
        }
        stderr: StdioCollector {}
    }
}
