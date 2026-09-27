<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "Configuration";
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
                        <a href="setting.php" class="active">
                            <i class="fa fa-gear"></i>
                            <span>Setting</span>
                        </a>
                        <a href="config.php">
                            <i class="fa fa-hdd-o"></i>
                            <span>Config</span>
                        </a>
                        <a href="speedtest.php">
                            <i class="fa fa-dashboard"></i>
                            <span>Speed</span>
                        </a>

                        <a href="yacd.php">
                            <i class="fa fa-rss"></i>
                            <span>Yacd</span>
                        </a>

                    </div>
                   </div>

 <div class="card-body">                 
<div class="config-header">

    <div class="config-header-left">

        <i class="fa fa-sliders"></i>

        <div>

            <div class="config-title">
                ADVANCED SETTINGS
            </div>

            <div class="config-subtitle">
                Configure Libernet system components
            </div>

        </div>

    </div>

</div>

    <div class="setting-grid">
    
    
                <div class="setting-card">

            <div class="setting-icon">
                <i class="fa fa-gear"></i>
            </div>

            <div class="setting-info">
                <div class="setting-title">
                System Config
                </div>
                <small>
                    Autoboot, Auto Reconnect, Auto Switch & Memory Cleaner
                </small>

            </div>

            <button
                type="button"
                class="btn btn-sm btn-primary"
                onclick="location.href='system.php'">
                Configure

            </button>

        </div>    
        <div class="setting-card">

            <div class="setting-icon">
                <i class="fa fa-heartbeat"></i>
            </div>

            <div class="setting-info">
                <div class="setting-title">
                Ping Monitor
                </div>
                <small>
                    Internet Connectivity Checker
                </small>

            </div>

            <button
                type="button"
                class="btn btn-sm btn-primary"
                onclick="location.href='ping.php'">
                Configure

            </button>

        </div>

        <div class="setting-card">

            <div class="setting-icon">
                <i class="fa fa-random"></i>
            </div>

            <div class="setting-info">
                <div class="setting-title">
                Tunnel Engine
                </div>
                <small>
                    TUN Interface, Routing & Firewall
                </small>

            </div>

            <button
                type="button"
                class="btn btn-sm btn-primary">

                Configure

            </button>

        </div>
        <div class="setting-card">

            <div class="setting-icon">
                <i class="fa fa-cogs"></i>
            </div>

            <div class="setting-info">
                <div class="setting-title">
                 Mihomo Engine
                </div>
                <small>
                    TUN, DNS & Proxy Settings
                </small>

            </div>

            <button
                type="button"
                class="btn btn-sm btn-primary">

                Configure
            </button>
        </div>
    </div>
   
  </div>
</div>
<?php include('footer.php'); ?>
<?php include("javascript.php"); ?>
<script src="js/config.js"></script>
</body>
</html>