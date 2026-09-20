<?php
    include('auth.php');
    check_session();
?>
<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "AdGuard";
        include("head.php");
    ?>
</head>
<body>
<div id="app">
    <?php include('navbar.php'); ?>
                <div class="embed-responsive embed-responsive-1by1">
                            <iframe class="embed-responsive-item" src="//192.168.1.1:3000" allowfullscreen></iframe>              
				</div>
        <?php include('footer.php'); ?>
</div>
<?php include("javascript.php"); ?>
</body>
</html>