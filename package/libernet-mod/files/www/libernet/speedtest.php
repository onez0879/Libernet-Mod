<?php include('auth.php'); check_session(); ?>
<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "SpeedTest";
        include("head.php");
    ?>
    <style>
    .st-wrap{max-width:860px;margin:0 auto}
    .st-hero{
        position:relative;overflow:hidden;border-radius:14px;
        background:#fff;border:1px solid #e6eaef;
        color:#495057;padding:18px 16px 22px;
        box-shadow:0 2px 10px rgba(31,45,61,.06)
    }
    .st-hero::after{
        content:"";position:absolute;inset:0;pointer-events:none;
        background:radial-gradient(60% 40% at 50% 100%,rgba(84,115,167,.05),transparent 70%)
    }
    .st-brand{display:flex;align-items:center;justify-content:center;gap:8px;
        font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#9aa5b1;font-weight:700}
    .st-brand b{color:#5473a7}
    .st-gauge{position:relative;width:100%;max-width:420px;margin:6px auto 0}
    .st-gauge svg{width:100%;height:auto;display:block}
    .st-read{position:absolute;left:0;right:0;bottom:6px;text-align:center;pointer-events:none}
    .st-value{font-size:clamp(38px,11vw,60px);line-height:1;font-weight:800;
        letter-spacing:-.03em;font-variant-numeric:tabular-nums;
        color:#2f3e57}
    .st-unit{font-size:12px;letter-spacing:.22em;color:#8a94a6;margin-top:2px}
    .st-phase{font-size:11px;letter-spacing:.2em;color:#5473a7;margin-top:8px;min-height:14px}
    .st-bar{height:4px;border-radius:99px;background:#eef1f5;overflow:hidden;margin:14px auto 0;max-width:360px}
    .st-bar>i{display:block;height:100%;width:0;border-radius:99px;
        background:linear-gradient(90deg,#5473a7,#4aa3df);transition:width .4s ease}
    .st-tiles{display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-top:16px}
    .st-tile{flex:1 1 120px;min-width:104px;text-align:center;border-radius:12px;padding:10px 8px;
        background:#f8f9fb;border:1px solid #e6eaef}
    .st-tile i{font-size:13px;color:#9aa5b1}
    .st-tile .v{font-size:20px;font-weight:700;font-variant-numeric:tabular-nums;margin-top:2px}
    .st-tile .l{font-size:10px;letter-spacing:.16em;color:#8a94a6;margin-top:2px}
    .st-tile.down .v{color:#4aa3df}
    .st-tile.up .v{color:#5473a7}
    .st-foot{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;
        margin-top:14px;padding-top:12px;border-top:1px solid #eef1f5;font-size:12px;color:#8a94a6}
    .st-foot b{display:block;color:#495057;font-weight:600;font-size:13px}
    .st-btn{display:inline-flex;align-items:center;gap:8px;border:0;cursor:pointer;
        padding:12px 28px;border-radius:99px;font-weight:700;font-size:14px;letter-spacing:.04em;
        color:#fff;background:#5473a7;
        box-shadow:0 4px 12px rgba(84,115,167,.30);transition:transform .15s,box-shadow .15s}
    .st-btn:hover{transform:translateY(-1px);box-shadow:0 6px 16px rgba(84,115,167,.40)}
    .st-btn[disabled]{opacity:.55;cursor:default;transform:none;box-shadow:none}
    .st-actions{text-align:center;margin-top:16px}
    .st-hist{margin-top:14px;border-radius:14px;background:#fff;border:1px solid #dfe3e8;overflow:hidden}
    .st-hist h6{margin:0;padding:10px 14px;font-size:11px;letter-spacing:.16em;color:#6c757d;
        text-transform:uppercase;border-bottom:1px solid #eef1f5;background:#fafbfd}
    .st-hist .rowx{display:flex;justify-content:space-between;gap:10px;padding:9px 14px;
        font-size:12px;color:#4a5568;border-bottom:1px solid #f2f4f8}
    .st-hist .rowx:last-child{border-bottom:0}
    </style>
</head>
<body>
<div id="app">

    <div class="container">
        <div class="row py-2">
            <div class="col-lg-8 col-md-12 mx-auto mt-3">
                <div class="card">
                    <div class="card-header">
                        <div>
<div class="libernet-header">

    <img
        src="img/logo.png"
        class="libernet-logo"
        alt="Libernet 26 Modify">

</div>

</div>
<div class="libernet-menu">

    <a href="index.php">
        <i class="fa fa-home"></i>
        <span>Home</span>
    </a>
        <a href="setting.php">
        <i class="fa fa-gear"></i>
        <span>Setting</span>
    </a>
    <a href="config.php">
        <i class="fa fa-hdd-o"></i>
        <span>Config</span>
    </a>

    <a href="speedtest.php" class="active">
        <i class="fa fa-dashboard"></i>
        <span>Speed</span>
    </a>

    <a href="yacd.php">
        <i class="fa fa-rss"></i>
        <span>Yacd</span>
    </a>

</div>

<hr>

<div class="st-wrap">
    <div class="st-hero">
        <div class="st-brand"><i class="fa fa-bolt"></i> speed<b>test</b></div>

        <div class="st-gauge">
            <svg viewBox="0 0 320 190" aria-hidden="true">
                <defs>
                    <linearGradient id="stGrad" x1="0" y1="0" x2="1" y2="0">
                        <stop offset="0%" stop-color="#5473a7"/>
                        <stop offset="55%" stop-color="#4aa3df"/>
                        <stop offset="100%" stop-color="#8fa8cf"/>
                    </linearGradient>
                </defs>
                <path d="M 40 150 A 120 120 0 0 1 280 150" fill="none"
                      stroke="#e9edf3" stroke-width="10" stroke-linecap="round"/>
                <path id="stArc" d="M 40 150 A 120 120 0 0 1 280 150" fill="none"
                      stroke="url(#stGrad)" stroke-width="10" stroke-linecap="round"
                      stroke-dasharray="376.99" stroke-dashoffset="376.99"/>
                <g id="stTicks"></g>
                <g id="stNeedle" transform="rotate(-90 160 150)">
                    <line x1="160" y1="150" x2="160" y2="52" stroke="#5473a7" stroke-width="3" stroke-linecap="round"/>
                    <circle cx="160" cy="150" r="7" fill="#fff" stroke="#5473a7" stroke-width="3"/>
                </g>
            </svg>
            <div class="st-read">
                <div class="st-value" id="stValue">0</div>
                <div class="st-unit" id="stUnit">Mbps</div>
                <div class="st-phase" id="stPhase">siap</div>
            </div>
        </div>

        <div class="st-bar"><i id="stBar"></i></div>

        <div class="st-tiles">
            <div class="st-tile">
                <i class="fa fa-refresh"></i>
                <div class="v" id="stPing">–</div>
                <div class="l">PING ms</div>
            </div>
            <div class="st-tile down">
                <i class="fa fa-arrow-down"></i>
                <div class="v" id="stDown">–</div>
                <div class="l">DOWNLOAD</div>
            </div>
            <div class="st-tile up">
                <i class="fa fa-arrow-up"></i>
                <div class="v" id="stUp">–</div>
                <div class="l">UPLOAD</div>
            </div>
        </div>

        <div class="st-foot">
            <div><b id="stServer">–</b>server</div>
            <div style="text-align:right"><b id="stIsp">–</b>isp</div>
        </div>
    </div>

    <div class="st-actions">
        <button class="st-btn" id="stStart" onclick="runSpeedtest()">
            <i class="fa fa-play"></i> Test Speed
        </button>
    </div>

    <div class="st-hist" id="stHist" style="display:none">
        <h6>Riwayat Test</h6>
        <div id="stHistRows"></div>
    </div>
</div>

<script>
(function () {
    var ARC = 376.99, MAX_PCT = 0.75;
    var elArc = document.getElementById('stArc');
    var elNeedle = document.getElementById('stNeedle');
    var elValue = document.getElementById('stValue');
    var elUnit = document.getElementById('stUnit');
    var elPhase = document.getElementById('stPhase');
    var elBar = document.getElementById('stBar');
    var elTicks = document.getElementById('stTicks');

    for (var a = -90; a <= 90; a += 15) {
        var m = a % 45 === 0, len = m ? 14 : 8;
        var r1 = 108, r2 = 108 - len;
        var x1 = 160 + Math.sin(a * Math.PI / 180) * r1;
        var y1 = 150 - Math.cos(a * Math.PI / 180) * r1;
        var x2 = 160 + Math.sin(a * Math.PI / 180) * r2;
        var y2 = 150 - Math.cos(a * Math.PI / 180) * r2;
        var l = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        l.setAttribute('x1', x1); l.setAttribute('y1', y1);
        l.setAttribute('x2', x2); l.setAttribute('y2', y2);
        l.setAttribute('stroke', m ? '#c3cbd6' : '#dfe4ea');
        l.setAttribute('stroke-width', m ? 2 : 1.5);
        elTicks.appendChild(l);
    }

    function scaleMax(v) {
        return v <= 10 ? 10 : v <= 50 ? 50 : v <= 100 ? 100 : v <= 200 ? 200 : v <= 500 ? 500 : 1000;
    }
    function paint(v, max) {
        var pct = Math.max(0, Math.min(1, v / max)) * MAX_PCT;
        elArc.style.strokeDashoffset = ARC * (1 - pct);
        elNeedle.setAttribute('transform', 'rotate(' + (-90 + pct * 180) + ' 160 150)');
    }
    function count(el, t, d, ms, done) {
        var s = performance.now();
        (function step(now) {
            var p = Math.min(1, (now - s) / ms), e = 1 - Math.pow(1 - p, 3);
            el.textContent = (t * e).toFixed(d || 0);
            if (p < 1) requestAnimationFrame(step); else if (done) done();
        })(s);
    }
    function sweep(val, unit, ph, ms, done) {
        var max = scaleMax(val);
        elUnit.textContent = unit;
        elPhase.textContent = ph;
        var s = performance.now(), from = 0;
        (function step(now) {
            var p = Math.min(1, (now - s) / ms), e = 1 - Math.pow(1 - p, 3);
            var v = from + (val - from) * e;
            elValue.textContent = v.toFixed(val < 10 ? 1 : 0);
            paint(v, max);
            if (p < 1) requestAnimationFrame(step); else if (done) done();
        })(s);
    }
    function setBusy(b) {
        var btn = document.getElementById('stStart');
        btn.disabled = b;
        btn.innerHTML = b ? '<i class="fa fa-circle-o-notch fa-spin"></i> Testing...' : '<i class="fa fa-play"></i> Test Speed';
        if (b) {
            elPhase.textContent = 'menghubungi server';
            elBar.style.width = '20%';
            setTimeout(function () { if (btn.disabled) elBar.style.width = '60%'; }, 5000);
            setTimeout(function () { if (btn.disabled) elBar.style.width = '85%'; }, 15000);
        } else {
            elBar.style.width = '100%';
            setTimeout(function () { elBar.style.width = '0'; }, 800);
        }
    }
    function save(r) {
        var k = 'libernet_speedtest_history', list = [];
        try { list = JSON.parse(localStorage.getItem(k) || '[]'); } catch (e) {}
        list.unshift(r); list = list.slice(0, 5);
        try { localStorage.setItem(k, JSON.stringify(list)); } catch (e) {}
        render(list);
    }
    function render(list) {
        var box = document.getElementById('stHist'), rows = document.getElementById('stHistRows');
        if (!list.length) { box.style.display = 'none'; return; }
        rows.innerHTML = '';
        list.forEach(function (r) {
            var d = document.createElement('div'); d.className = 'rowx';
            var l = document.createElement('span'); l.textContent = r.when + ' · ' + r.server;
            var rv = document.createElement('span'); rv.textContent = '↓' + r.download + ' ↑' + r.upload + ' · ' + r.ping + ' ms';
            d.appendChild(l); d.appendChild(rv); rows.appendChild(d);
        });
        box.style.display = 'block';
    }

    window.runSpeedtest = function () {
        setBusy(true);
        elValue.textContent = '0'; paint(0, 10);
        document.getElementById('stPing').textContent = '–';
        document.getElementById('stDown').textContent = '–';
        document.getElementById('stUp').textContent = '–';
        fetch('api.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'run_speedtest' })
        })
        .then(function (r) { return r.json(); })
        .then(function (data) {
            if (!data.status) throw new Error(data.message || 'Speedtest failed');
            var ping = Number(data.ping) || 0, down = Number(data.download) || 0, up = Number(data.upload) || 0;
            document.getElementById('stServer').textContent = data.server || '-';
            document.getElementById('stIsp').textContent = data.isp || '-';
            count(document.getElementById('stPing'), ping, 0, 400, function () {
                sweep(down, 'Mbps', 'download', 1200, function () {
                    document.getElementById('stDown').textContent = down;
                    sweep(up, 'Mbps', 'upload', 1200, function () {
                        document.getElementById('stUp').textContent = up;
                        sweep(down, 'Mbps', 'hasil download', 900);
                        save({
                            when: new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
                            ping: ping, download: down, upload: up,
                            server: data.server || '-', isp: data.isp || '-'
                        });
                    });
                });
            });
        })
        .catch(function (err) {
            elPhase.textContent = 'gagal';
            if (window.Swal) Swal.fire({ icon: 'error', title: 'Speedtest gagal', text: err.message || '' });
        })
        .finally(function () { setBusy(false); });
    };

    try { render(JSON.parse(localStorage.getItem('libernet_speedtest_history') || '[]')); } catch (e) {}
})();
</script>

</div>
            </div>
        </div>
        </div>
        </div>
        </div>
        <?php include('footer.php'); ?>
    </div>
</div>
<?php include("javascript.php"); ?>
</body>
</html>
