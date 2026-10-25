/**
 * V2Ray Import Parser – pure functions, no Vue deps.
 * Feeds the universal import box in the Config panel.
 * Supports: vmess://, vless://, trojan:// URIs and raw v2ray JSON (full config or bare outbound).
 */

const VMESS_CIPHERS = ["auto", "aes-128-gcm", "chacha20-poly1305", "none"];

function mapNetwork(net) {
    // panel only supports tcp / ws / http
    if (net === "ws") return "ws";
    if (net === "http" || net === "h2") return "http";
    return "tcp";
}

function emptyUser() {
    return {
        level: 0,
        vmess: { id: "", security: "" },
        vless: { id: "" },
        trojan: { password: "" }
    };
}

/** vmess://<base64 json> */
function parseVmessURI(uri) {
    try {
        let b64 = uri.slice("vmess://".length).split("#")[0];
        while (b64.length % 4) b64 += "=";
        const json = JSON.parse(atob(b64));
        return {
            protocol: "vmess",
            host: json.add || "",
            port: parseInt(json.port, 10) || 443,
            network: mapNetwork(json.net),
            security: json.tls ? "tls" : "none",
            vmessId: json.id || "",
            alterId: parseInt(json.aid, 10) || 0,
            cipher: VMESS_CIPHERS.includes(json.scy) ? json.scy : "auto",
            sni: json.host || json.sni || "",
            path: json.path || ""
        };
    } catch (e) { return null; }
}

/** vless://<uuid>@host:port?security=tls&type=ws&path=/x&host=x&sni=x#name */
function parseVlessURI(uri) {
    try {
        const url = new URL(uri);
        const type = url.searchParams.get("type") || "tcp";
        return {
            protocol: "vless",
            host: url.hostname,
            port: parseInt(url.port, 10) || 443,
            network: mapNetwork(type),
            security: (url.searchParams.get("security") || "none") === "tls" ? "tls" : "none",
            vlessId: decodeURIComponent(url.username || ""),
            alterId: 0,
            sni: url.searchParams.get("sni") || url.searchParams.get("host") || "",
            path: url.searchParams.get("path") || ""
        };
    } catch (e) { return null; }
}

/** trojan://<password>@host:port?security=tls&type=ws&path=/x&host=x&sni=x#name */
function parseTrojanURI(uri) {
    try {
        const url = new URL(uri);
        const type = url.searchParams.get("type") || "tcp";
        return {
            protocol: "trojan",
            host: url.hostname,
            port: parseInt(url.port, 10) || 443,
            network: mapNetwork(type),
            security: (url.searchParams.get("security") || "none") === "tls" ? "tls" : "none",
            trojanPassword: decodeURIComponent(url.username || ""),
            alterId: 0,
            sni: url.searchParams.get("sni") || url.searchParams.get("host") || "",
            path: url.searchParams.get("path") || ""
        };
    } catch (e) { return null; }
}

/** Raw JSON: full client config (outbounds[0]) or a bare outbound object. */
function parseJsonImport(text) {
    try {
        const json = JSON.parse(text);
        const out = (json.outbounds && json.outbounds[0]) || json;
        const protocol = out.protocol;
        if (!["vmess", "vless", "trojan"].includes(protocol)) return null;
        const stream = out.streamSettings || {};
        const result = {
            protocol,
            host: "",
            port: 443,
            network: mapNetwork(stream.network),
            security: stream.security === "tls" ? "tls" : "none",
            alterId: 0,
            sni: (stream.tlsSettings && stream.tlsSettings.serverName) || "",
            path:
                (stream.wsSettings && stream.wsSettings.path) ||
                (stream.httpSettings && stream.httpSettings.path) ||
                ""
        };
        if (protocol === "trojan") {
            const server = (out.settings.servers || [])[0] || {};
            result.host = server.address || "";
            result.port = parseInt(server.port, 10) || 443;
            result.trojanPassword = server.password || "";
        } else {
            const vnext = (out.settings.vnext || [])[0] || {};
            const user = (vnext.users || [])[0] || {};
            result.host = vnext.address || "";
            result.port = parseInt(vnext.port, 10) || 443;
            result.alterId = parseInt(user.level, 10) || 0;
            if (protocol === "vmess") {
                result.vmessId = user.id || "";
                result.cipher = VMESS_CIPHERS.includes(user.security) ? user.security : "auto";
            } else {
                result.vlessId = user.id || "";
            }
        }
        return result;
    } catch (e) { return null; }
}

/** Main entry. Returns { protocol, profile, needsHostResolve } or null. */
function importV2rayConfigFromText(text) {
    text = (text || "").trim();
    if (!text) return null;
    let r;
    if (text.startsWith("{")) r = parseJsonImport(text);
    else if (text.startsWith("vmess://")) r = parseVmessURI(text);
    else if (text.startsWith("vless://")) r = parseVlessURI(text);
    else if (text.startsWith("trojan://")) r = parseTrojanURI(text);
    else return null;
    if (!r || !r.host) return null;

    const profile = {
        network: r.network,
        security: r.security,
        server: { host: r.host, port: r.port, user: emptyUser() },
        stream: { sni: r.sni, path: r.path }
    };
    profile.server.user.level = r.alterId || 0;
    if (r.protocol === "vmess") {
        profile.server.user.vmess.id = r.vmessId || "";
        profile.server.user.vmess.security = r.cipher || "auto";
    } else if (r.protocol === "vless") {
        profile.server.user.vless.id = r.vlessId || "";
    } else if (r.protocol === "trojan") {
        profile.server.user.trojan.password = r.trojanPassword || "";
    }

    const needsHostResolve =
        r.host !== "127.0.0.1" && !/^\d{1,3}(\.\d{1,3}){3}$/.test(r.host);
    return { protocol: r.protocol, profile, needsHostResolve };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        parseVmessURI, parseVlessURI, parseTrojanURI, parseJsonImport,
        importV2rayConfigFromText
    };
}