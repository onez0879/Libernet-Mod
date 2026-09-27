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

        <a href="setting.php" class="btn btn-sm btn-light">
            <i class="fa fa-arrow-left"></i>
        </a>

        <div>

            <div class="config-title">
                SYSTEM CONFIGURATION
            </div>

            <div class="config-subtitle">
                Configure Libernet core services
            </div>

        </div>

    </div>

</div>

<div class="setting-grid">
<div class="setting-card">

    <div class="setting-icon">
        <i class="fa fa-power-off"></i>
    </div>

    <div class="setting-info">
                <div class="setting-title">
                Auto Boot
                </div>
                <small>
                    Start Libernet automatically after reboot
                </small>

    </div>

    <label class="switch">
        <input
            type="checkbox"
            v-model="system.autoboot">
        <span class="slider"></span>
    </label>

</div>
<div class="setting-card">

    <div class="setting-icon">
        <i class="fa fa-refresh"></i>
    </div>

    <div class="setting-info">
                <div class="setting-title">
                Auto Reconnect
                </div>
                <small>
                   Reconnect tunnel automatically
                </small>

    </div>

    <label class="switch">
        <input
            type="checkbox"
            v-model="system.autoreconnect">
        <span class="slider"></span>
    </label>

</div>
<div class="setting-card">

    <div class="setting-icon">
        <i class="fa fa-random"></i>
    </div>

    <div class="setting-info">
                <div class="setting-title">
                Auto Switch Config
                </div>
                <small>
                   Change config tunnel automatically
                </small>

    </div>

    <label class="switch">
        <input
            type="checkbox"
            v-model="system.autoswitch">
        <span class="slider"></span>
    </label>

</div>

<div class="setting-card">

    <div class="setting-icon">
        <i class="fa fa-trash"></i>
    </div>

    <div class="setting-info">
                <div class="setting-title">
                Memory Cleaner
                </div>
                <small>
                   Free memory periodically
                </small>

    </div>

    <label class="switch">
        <input
            type="checkbox"
            v-model="system.memory">
        <span class="slider"></span>
    </label>

</div>

<button
    class="btn btn-primary w-100 mt-3"
    @click="saveSystem">

    <i class="fa fa-save"></i>
    Save Settings

</button>

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

        system: {

            autoboot: true,
            autoreconnect: true,
            autoswitch: true,
            memory: true

        }

    },

    mounted() {

        this.loadSystem();

    },

    methods: {

        loadSystem() {

            axios.post('api.php', {

                action: 'get_system_setting'

            }).then((res) => {

                this.system = res.data.data;

            });

        },

        saveSystem() {

            axios.post('api.php', {

                action: 'save_system_setting',

                data: this.system

            }).then(() => {

                Swal.fire({
                    position: "center",
                    icon: "success",
                    title: "System settings saved",
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