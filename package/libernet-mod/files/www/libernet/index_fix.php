<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "Home";
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

    <a href="index.php" class="active">
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

    <a href="speedtest.php">
        <i class="fa fa-dashboard"></i>
        <span>Speed</span>
    </a>

    <a href="yacd.php">
        <i class="fa fa-rss"></i>
        <span>Yacd</span>
    </a>

</div>

<hr>

<form >

<div class="config-panel">

<div class="config-header">

    <div class="config-header-left">

        <i class="fa fa-navicon"></i>

        <span>CONFIG FILE</span>

    </div>

    <span class="config-current">

        {{ config.temp.modes[config.mode].name }}
        •
        {{ config.profile }}

    </span>

</div>

<button
    type="button"
    class="config-toggle"
    @click="showConfig = !showConfig">

    Change Config

    <i
        :class="
            showConfig
            ? 'fa fa-chevron-up'
            : 'fa fa-chevron-down'
        ">
    </i>

</button>

    <div v-show="showConfig">

        <div class="config-select">

            <select
                class="form-control"
                v-model.number="config.mode"
                :disabled="status">

                <option
                    v-for="mode in config.temp.modes"
                    :value="mode.value">

                    {{ mode.name }}

                </option>

            </select>

        </div>

        <div class="config-select">

            <select
                class="form-control"
                v-model="config.profile"
                :disabled="status">

                <option
                    v-for="profile in config.profiles"
                    :value="profile">

                    {{ profile }}

                </option>

            </select>

        </div>

    </div>

</div>

        <div class="config-actions">

<button
    type="button"
    class="btn btn-success"
    :disabled="status"
    @click="startLibernet">

    <i class="fa fa-play"></i>
    Start

</button>

<button
    type="button"
    class="btn btn-warning"
    :disabled="!status"
    @click="restartLibernet">

    <i class="fa fa-refresh"></i>
    Restart

</button>

<button
    type="button"
    class="btn btn-danger"
    :disabled="!status"
    @click="stopLibernet">

    <i class="fa fa-stop"></i>
    Stop

</button>
        </div>


</form>

</div> <!-- card-header -->

<div class="card-body">



    <div class="libernet-status-card">

        <div class="status-header">

    <div class="status-title">

        <span
            class="status-dot"
            :class="{
                'ready': connection === 0,
                'connecting': connection === 1,
                'connected': connection === 2,
                'disconnect': connection === 3
            }">
        </span>

        <span
            :class="{
                'text-secondary': connection === 0,
                'text-warning': connection === 1,
                'text-success': connection === 2,
                'text-info': connection === 3
            }">

            {{ connectionText }}

        </span>

    </div>

    <div class="status-marquee">

        <div class="status-marquee-text">

    Connected to

    <span class="mode-text">
        <span v-if="config.mode == 0">SSH</span>
        <span v-else-if="config.mode == 1">V2RAY</span>
        <span v-else-if="config.mode == 2">SSH-SSL</span>
        <span v-else-if="config.mode == 3">TROJAN</span>
        <span v-else-if="config.mode == 4">SHADOWSOCKS</span>
        <span v-else-if="config.mode == 5">OPENVPN</span>
    </span>

    •

    <span class="profile-text">
        {{ config.profile }}
    </span>

    <template v-if="connection === 2">

        •

        <span class="ip-text">
            {{ wan_ip }}
        </span>

    </template>

</div>

</div>

</div>
        <div class="traffic-grid">

    <div class="traffic-item">

        <i class="fa fa-arrow-down metric-icon download"></i>

        <div>
            <small>DOWNLOAD</small>
            <strong>
                {{ connection === 2 ? total_data.rx : '--' }}
            </strong>
        </div>

    </div>

    <div class="traffic-item">

        <i class="fa fa-arrow-up metric-icon upload"></i>

        <div>
            <small>UPLOAD</small>
            <strong>
                {{ connection === 2 ? total_data.tx : '--' }}
            </strong>
        </div>

    </div>

<div class="traffic-item">

    <i class="fa fa-clock-o metric-icon uptime"></i>

    <div>

        <small>UPTIME</small>

        <strong>
            {{ connection === 2 ? connectedTime : '--' }}
        </strong>

     </div>
    </div>
  </div> 
 </div> 
</div> 

<div class="col-12 pt-2">
    <pre
        ref="log"
        class="form-control text-left"
        style="height:15rem;background-color:#e9ecef"
        v-html="log">
    </pre>

</div>
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
<script>
window.onerror = function(msg, url, line, col, err) {
    alert(msg + "\nLine: " + line);
};
</script>
<script src="js/index.js"></script>
</body>
</html>
