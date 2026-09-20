<!doctype html>
<html lang="en">
<head>
<?php
    $title = "Ping Monitor";
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

<div class="libernet-header">

    <img
        src="img/logo.png"
        class="libernet-logo"
        alt="Libernet">

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

        <a
            href="setting.php"
            class="btn btn-sm btn-light">

            <i class="fa fa-arrow-left"></i>

        </a>

        <div>

            <div class="config-title">
                PING MONITOR
            </div>

            <div class="config-subtitle">
                Configure internet connectivity monitor
            </div>

        </div>

    </div>

</div>
<div class="setting-card">

    <div class="setting-icon">
        <i class="fa fa-bullhorn"></i>
    </div>

    <div class="setting-info">

        <div class="setting-title">
            PING STATUS
        </div>
    </div>

    <label class="switch">

        <input
            type="checkbox"
            v-model="ping.enable">

        <span class="slider"></span>

    </label>

</div>

<div class="form-group mb-3">

    <label class="setting-label">
        Host
    </label>

    <input
        type="text"
        class="form-control config-input"
        v-model="ping.host">

</div>

<div class="form-group mb-3">

    <label class="setting-label">
        Interval (Seconds)
    </label>

    <input
        type="number"
        class="form-control config-input"
        v-model.number="ping.interval">

</div>

<div class="form-group mb-3">

    <label class="setting-label">
        Timeout (Seconds)
    </label>

    <input
        type="number"
        class="form-control config-input"
        v-model.number="ping.timeout">

</div>

<div class="form-group mb-4">

    <label class="setting-label">
        Fail Count
    </label>

    <select
        class="form-control config-input"
        v-model.number="ping.fail_count">

        <option :value="1">1 Attempt</option>
        <option :value="2">2 Attempts</option>
        <option :value="3">3 Attempts</option>
        <option :value="5">5 Attempts</option>

    </select>

</div>
<div class="form-group mb-3">

    <label class="setting-label">
        Log Interval (Seconds)
    </label>

    <input
        type="number"
        class="form-control"
        v-model.number="ping.log_interval">
</div>
    <button
        class="btn btn-primary w-100"
        @click="savePing">

        <i class="fa fa-save"></i>
        Save Settings

    </button>

</div>
</div>

</div>
</div>
</div>

</div>
<?php include('footer.php'); ?>
<?php include("javascript.php"); ?>

<script>

new Vue({

    el: '#app',

    data: {

        ping: {
            enable: true,
            host: '',
            interval: 30,
            timeout: 5,
            fail_count: 3,
            log_interval: 10
        }

    },

    mounted() {

        this.loadPing();

    },

    methods: {

        loadPing() {

            axios.post('api.php', {
                action: 'get_ping_setting'
            }).then((res) => {

                this.ping = res.data.data;

            });

        },

        savePing() {

            axios.post('api.php', {

                action: 'save_ping_setting',

                enable: this.ping.enable,
                host: this.ping.host,
                interval: this.ping.interval,
                timeout: this.ping.timeout,
                fail_count: this.ping.fail_count,
                log_interval: this.ping.log_interval
            }).then((res) => {

                console.log("Ping Monitor settings saved");

                Swal.fire({
                    position: "center",
                    icon: "success",
                    title: "Ping Monitor settings saved",
                    showConfirmButton: false,
                    timer: 1500
                });

            });

        }

    }

});

</script>

</body>
</html>