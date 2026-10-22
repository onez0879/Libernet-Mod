// node tests/v2ray-import.test.js
const assert = require('assert');
const p = require('../files/www/libernet/js/v2ray-import.js');

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64');

// 1. vmess://
let r = p.importV2rayConfigFromText('vmess://' + b64({
    ps: 'n', add: 'v.example.com', port: '443', id: 'uuid-1', aid: '0',
    scy: 'auto', net: 'ws', type: 'none', host: 'v.example.com', path: '/ws', tls: 'tls'
}));
assert.strictEqual(r.protocol, 'vmess');
assert.strictEqual(r.profile.server.host, 'v.example.com');
assert.strictEqual(r.profile.server.port, 443);
assert.strictEqual(r.profile.network, 'ws');
assert.strictEqual(r.profile.security, 'tls');
assert.strictEqual(r.profile.server.user.vmess.id, 'uuid-1');
assert.strictEqual(r.profile.server.user.vmess.security, 'auto');
assert.strictEqual(r.profile.stream.path, '/ws');
assert.strictEqual(r.profile.stream.sni, 'v.example.com');
assert.strictEqual(r.needsHostResolve, true);

// 2. vless://
r = p.importV2rayConfigFromText(
    'vless://uuid-vless@l.example.com:443?security=tls&type=ws&path=%2Fvl&host=l.example.com&sni=l.example.com#nm');
assert.strictEqual(r.protocol, 'vless');
assert.strictEqual(r.profile.server.host, 'l.example.com');
assert.strictEqual(r.profile.server.port, 443);
assert.strictEqual(r.profile.server.user.vless.id, 'uuid-vless');
assert.strictEqual(r.profile.stream.path, '/vl');
assert.strictEqual(r.profile.network, 'ws');

// 3. trojan://
r = p.importV2rayConfigFromText(
    'trojan://p%40ss@t.example.com:8443?security=tls&type=ws&path=%2Ftr&sni=t.example.com');
assert.strictEqual(r.protocol, 'trojan');
assert.strictEqual(r.profile.server.user.trojan.password, 'p@ss');
assert.strictEqual(r.profile.server.port, 8443);
assert.strictEqual(r.profile.stream.path, '/tr');

// 4. raw JSON, full config
r = p.importV2rayConfigFromText(JSON.stringify({
    outbounds: [{
        protocol: 'vmess',
        settings: { vnext: [{ address: 'j.example.com', port: 443, users: [{ id: 'uuid-j', level: 0, security: 'chacha20-poly1305' }] }] },
        streamSettings: { network: 'tcp', security: 'tls', tlsSettings: { serverName: 'j.example.com' } }
    }]
}));
assert.strictEqual(r.protocol, 'vmess');
assert.strictEqual(r.profile.server.user.vmess.security, 'chacha20-poly1305');
assert.strictEqual(r.profile.stream.sni, 'j.example.com');

// 5. raw JSON, bare trojan outbound
r = p.importV2rayConfigFromText(JSON.stringify({
    protocol: 'trojan',
    settings: { servers: [{ address: 'b.example.com', port: 443, password: 'secret' }] },
    streamSettings: { network: 'ws', security: 'tls', wsSettings: { path: '/b' }, tlsSettings: { serverName: 'b.example.com' } }
}));
assert.strictEqual(r.profile.server.user.trojan.password, 'secret');
assert.strictEqual(r.profile.stream.path, '/b');

// 6. IP host → no resolve
r = p.importV2rayConfigFromText('trojan://x@1.2.3.4:443?security=tls');
assert.strictEqual(r.needsHostResolve, false);

// 7. garbage → null
assert.strictEqual(p.importV2rayConfigFromText('hello world'), null);
assert.strictEqual(p.importV2rayConfigFromText('{"foo":1}'), null);

console.log('ok - 7 import scenarios passed');
