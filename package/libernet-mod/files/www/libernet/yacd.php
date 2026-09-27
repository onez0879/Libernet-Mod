<!doctype html>
<html lang="en">
<head>
<?php
$title = "Yacd";
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
    <img src="img/logo.png"
         class="libernet-logo"
         alt="Libernet 26 Modify">
</div>

<div class="libernet-menu">

    <a href="index.php">
        <i class="fa fa-home"></i>
        <span>Home</span>
    </a>
    <a href="setting.php">
        <i class="fa fa-gear"></i>
        <span>Config</span>
    </a>
    <a href="config.php">
        <i class="fa fa-hdd-o"></i>
        <span>Config</span>
    </a>

    <a href="speedtest.php">
        <i class="fa fa-dashboard"></i>
        <span>Speed</span>
    </a>

    <a href="yacd.php" class="active">
        <i class="fa fa-rss"></i>
        <span>Yacd</span>
    </a>
</div>

<hr>

<div class="card-body p-0">

    <iframe
        src="http://<?= $_SERVER['HTTP_HOST']; ?>:9090/ui/"
        style="
            width:100%;
            height:80vh;
            border:none;
            border-radius:12px;
        ">
    </iframe>

</div>

</body>
</html>