<?php
    session_start();

    function set_session($username, $password) {
        $_SESSION['username'] = $username;
        $_SESSION['password'] = $password;
        header("Location: index.php");
        exit;
    }

    function check_session() {
        // Redirect if either key is missing — using OR is correct here.
        if (!isset($_SESSION['username']) || !isset($_SESSION['password'])) {
            header("Location: login.php");
            exit;
        }
    }

    function remove_session() {
        unset($_SESSION['username']);
        unset($_SESSION['password']);
        session_unset();
        session_destroy();
        header("Location: login.php");
        exit;
    }
?>