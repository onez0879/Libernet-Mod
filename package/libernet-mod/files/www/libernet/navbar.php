<?php
$current = basename($_SERVER['PHP_SELF']);
?>
<nav class="navbar">
    <div class="libernet-menu">

        <a href="index.php"
           class="<?php echo ($url == 'index.php') ? 'active' : ''; ?>">
           Home
        </a>

        <a href="config.php"
           class="<?php echo ($url == 'config.php') ? 'active' : ''; ?>">
           Configuration
        </a>

        <a href="speedtest.php"
           class="<?php echo ($url == 'speedtest.php') ? 'active' : ''; ?>">
           SpeedTest
        </a>

        <a href="http://<?php echo $_SERVER['HTTP_HOST']; ?>:9090/ui/"
           target="_blank">
           Yacd
        </a>

        <a href="about.php"
           class="<?php echo ($url == 'about.php') ? 'active' : ''; ?>">
           About
        </a>

    </div>
</nav>