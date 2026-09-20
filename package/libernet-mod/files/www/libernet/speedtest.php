<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "SpeedTest";
        include("head.php");
    ?>
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

<div class="speed-panel">

<div id="loader" class="speed-loader" style="display:none;">

    <div class="loader-ring"></div>

    <div class="loader-content">
        <i class="fa fa-dashboard"></i>
        <h2>Testing...</h2>
        <p>Mohon tunggu sebentar</p>
    </div>

</div>

    <div class="text-center mb-4">
        <button id="startSpeedtest"
                class="btn btn-primary btn-lg px-5"
                onclick="runSpeedtest()">
            Start Speedtest
        </button>
    </div>

    <div class="result-card">

        <div class="row text-center">

            <div class="col metric">
                <i class="fa fa-refresh metric-icon ping"></i>
                <div class="metric-title">PING</div>
                <div id="ping" class="metric-value">-</div>
                <div class="metric-unit">ms</div>
            </div>

            <div class="col metric">
                <i class="fa fa-arrow-down metric-icon download"></i>
                <div class="metric-title">DOWNLOAD</div>
                <div id="download" class="metric-value">-</div>
                <div class="metric-unit">Mbps</div>
            </div>

            <div class="col metric">
                <i class="fa fa-arrow-up metric-icon upload"></i>
                <div class="metric-title">UPLOAD</div>
                <div id="upload" class="metric-value">-</div>
                <div class="metric-unit">Mbps</div>
            </div>

        </div>

        <hr>

  <div class="server-row">



    <div>
<div class="server-title">SERVER</div>
<div id="server">-</div>

<div class="server-title mt-2">ISP</div>
<div id="isp">-</div>

    </div>

</div>    

    </div>

    <div class="info-box">
        <i class="fa fa-info-circle"></i>
        Hasil speedtest dijalankan langsung dari router melalui tunnel.
    </div>

</div>

<script>
function runSpeedtest() {

    const btn = document.getElementById("startSpeedtest");
    const loader = document.getElementById("loader");

    btn.style.display = "none";

    loader.style.display = "block";

    document.getElementById("ping").innerHTML = "...";
    document.getElementById("download").innerHTML = "...";
    document.getElementById("upload").innerHTML = "...";

    document.getElementById("server").innerHTML =
        "Running speedtest...";

    document.getElementById("isp").innerHTML =
        "...";

    fetch("api.php", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            action: "run_speedtest"
        })
    })
    .then(r => r.json())
    .then(data => {

        if (!data.status) {

            document.getElementById("server").innerHTML =
                "Speedtest failed";

            return;
        }

        document.getElementById("ping").innerHTML =
            data.ping;

        document.getElementById("download").innerHTML =
            data.download;

        document.getElementById("upload").innerHTML =
            data.upload;

        document.getElementById("server").innerHTML =
            data.server + " - " + data.location;

        document.getElementById("isp").innerHTML =
            data.isp;

    })
    .catch(() => {

        document.getElementById("server").innerHTML =
            "Speedtest failed";

        document.getElementById("isp").innerHTML =
            "-";

    })
    .finally(() => {

        btn.style.display = "";

        loader.style.display = "none";

    });

}
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