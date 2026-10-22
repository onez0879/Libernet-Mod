<?php
    session_start();

    /**
     * Login is optional, controlled by "system.auth" in
     * /root/libernet/system/config.json:
     *   "auth": true  -> panel + API require a session
     *   "auth": false -> panel + API open (default; no login prompt)
     * Missing key = false, so existing installs keep working as before.
     */
    function auth_enabled() {
        static $enabled = null;
        if ($enabled !== null) {
            return $enabled;
        }
        $enabled = false;
        $cfg = "/root/libernet/system/config.json";
        if (is_readable($cfg)) {
            $json = json_decode(file_get_contents($cfg));
            if (isset($json->system) && isset($json->system->auth)) {
                $enabled = (bool) $json->system->auth;
            }
        }
        return $enabled;
    }

    function set_session($username, $password) {
        $_SESSION['username'] = $username;
        $_SESSION['password'] = $password;
        header("Location: index.php");
        exit;
    }

    function check_session() {
        if (!auth_enabled()) {
            return;
        }
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