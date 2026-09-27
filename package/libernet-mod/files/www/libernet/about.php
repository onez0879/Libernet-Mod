<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "About";
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

    <a href="config.php">
        <i class="fa fa-cog"></i>
        <span>Config</span>
    </a>

    <a href="speedtest.php">
        <i class="fa fa-dashboard"></i>
        <span>Speed</span>
    </a>

    <a href="yacd.php">
        <i class="fa fa-signal"></i>
        <span>Yacd</span>
    </a>

    <a href="about.php" class="active">
        <i class="fa fa-info-circle"></i>
        <span>About</span>
    </a>

</div>

</div>
                    <div class="card-body">
                        <div>
                            <p>
                                Libernet is open source web app for tunneling internet on OpenWRT with ease.
                            </p>
                            <span>Working features:</span>
                            <ul class="m-2">
                                <li>SSH with proxy</li>
                                <li>SSH-SSL</li>
                                <li>V2Ray VMess</li>
                                <li>V2Ray VLESS</li>
                                <li>V2Ray Trojan</li>
                                <li>Trojan</li>
                                <li>Shadowsocks</li>
                                <li>OpenVPN</li>
                            </ul>
                            <p>
                                Some features still under development!
                            </p>
                            <p class="text-right m-0"><a href="https://facebook.com/lutfailham">Report bug</a></p>
                            <p class="text-right m-0">Author: <a href="https://facebook.com/lutfailham"><i>Lutfa Ilham</i></a></p>
                        </div>
                        <div class="text-center">
                            <p v-if="status === 3" class="text-danger mt-0 mb-1">Update failed!</p>
                            <p v-else-if="status === 2" class="text-success mt-0 mb-1">Updated to latest version!</p>
                            <p v-else-if="status === 1" class="text-secondary mt-0 mb-1">Updating ...</p>
                            <button class="btn btn-primary" :disabled="status === 1" @click="updateLibernet">Update</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <?php include('footer.php'); ?>
    </div>
</div>
<?php include("javascript.php"); ?>
<script src="js/about.js"></script>
</body>
</html>