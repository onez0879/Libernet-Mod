<?php
include "config.inc.php";
//include('auth.php');
//check_session();
function formatBytes($bytes, $precision = 2)
{
    $units = ["B", "KB", "MB", "GB", "TB"];

    $bytes = max($bytes, 0);

    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);

    $bytes /= pow(1024, $pow);

    return round($bytes, $precision) . " " . $units[$pow];
}
function tail($file, $lines = 200)
{
    if (!file_exists($file)) {
        return "";
    }

    $data = file($file, FILE_IGNORE_NEW_LINES);

    if ($data === false) {
        return "";
    }

    return implode("\n", array_slice($data, -$lines));
}
function json_response($data)
{
    $resp = [
        "status" => "OK",
        "data" => $data,
    ];
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode($resp, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
}
function get_profiles($mode)
{
    global $libernet_dir;
    $profiles = [];
    if ($handle = opendir($libernet_dir . "/bin/config/" . $mode . "/")) {
        while (false !== ($file = readdir($handle))) {
            if (
                $file != "." &&
                $file != ".." &&
                strtolower(substr($file, strrpos($file, ".") + 1)) == "json"
            ) {
                array_push(
                    $profiles,
                    preg_replace('/\\.[^.\\s]{3,4}$/', "", $file)
                );
            }
        }
        closedir($handle);
    }
    json_response($profiles);
}
function get_config($mode, $profile)
{
    global $libernet_dir;
    $data = null;
    $config = null;
    if ($profile) {
        $config = file_get_contents(
            $libernet_dir . "/bin/config/" . $mode . "/" . $profile . ".json"
        );
    } else {
        $system_config = file_get_contents(
            $libernet_dir . "/system/config.json"
        );
        $system_config = json_decode($system_config);
        $config = file_get_contents(
            $libernet_dir .
                "/bin/config/" .
                $mode .
                "/" .
                $system_config->tunnel->profile->$mode .
                ".json"
        );
    }
    $data = json_decode($config);
    json_response($data);
}
function set_v2ray_config(
    $config,
    $protocol,
    $network,
    $security,
    $sni,
    $path,
    $ip,
    $udpgw_ip,
    $udpgw_port
) {
    $config->outbounds[0]->protocol = $protocol;
    $config->outbounds[0]->streamSettings->network = $network;
    $config->outbounds[0]->streamSettings->security = $security;
    // forcing security to none if network http
    if ($network === "http") {
        $config->outbounds[0]->streamSettings->security = "none";
    }
    // tls
    $config->outbounds[0]->streamSettings->tlsSettings->serverName = $sni;
    // ws
    $config->outbounds[0]->streamSettings->wsSettings->path = $path;
    $config->outbounds[0]->streamSettings->wsSettings->headers->Host = $sni;
    // http
    $config->outbounds[0]->streamSettings->httpSettings->host[0] = $sni;
    $config->outbounds[0]->streamSettings->httpSettings->path = $path;
    // misc
    $config->etc->ip = $ip;
    $config->etc->udpgw->ip = $udpgw_ip;
    $config->etc->udpgw->port = $udpgw_port;
}
function set_auto_start($status)
{
    global $libernet_dir;
    $system_config = file_get_contents($libernet_dir . "/system/config.json");
    $system_config = json_decode($system_config);
    if ($status) {
        // enable auto start
        exec(
            'export LIBERNET_DIR="' .
                $libernet_dir .
                '" && ' .
                $libernet_dir .
                "/bin/service.sh -ea"
        );
        $system_config->tunnel->autostart = true;
    } else {
        // disable auto start
        exec(
            'export LIBERNET_DIR="' .
                $libernet_dir .
                '" && ' .
                $libernet_dir .
                "/bin/service.sh -da"
        );
        $system_config->tunnel->autostart = false;
    }
    $system_config = json_encode(
        $system_config,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
    );
    file_put_contents($libernet_dir . "/system/config.json", $system_config);
}
if (isset($_POST)) {
    $json = json_decode(file_get_contents("php://input"), true);
    switch ($json["action"]) {
        case "get_system_config":
            $system_config = file_get_contents(
                $libernet_dir . "/system/config.json"
            );
            $data = json_decode($system_config);
            json_response($data);
            break;
        case "get_ssh_config":
            $profile = $json["profile"];
            get_config("ssh", $profile);
            break;
        case "get_v2ray_config":
            $profile = $json["profile"];
            get_config("v2ray", $profile);
            break;
        case "get_qssh_config":
            $profile = $json["profile"];
            get_config("qssh", $profile);
            break;            
            
        case "get_v2ray_configs":
            get_profiles("v2ray");
            break;
        case "get_ssh_configs":
            get_profiles("ssh");
            break;
        case "get_qssh_configs":
            get_profiles("qssh");
            break;           
        case "start_libernet":
            $system_config = file_get_contents(
                $libernet_dir . "/system/config.json"
            );
            $system_config = json_decode($system_config);
            exec(
                "export LIBERNET_DIR=" .
                    $libernet_dir .
                    " && " .
                    $libernet_dir .
                    "/bin/service.sh -sl"
            );
            json_response("Libernet service started");
            break;
        case "cancel_libernet":
            exec(
                'export LIBERNET_DIR="' .
                    $libernet_dir .
                    '" && ' .
                    $libernet_dir .
                    "/bin/service.sh -cl"
            );
            json_response("Libernet service canceled");
            break;
        case "stop_libernet":
            exec(
                'export LIBERNET_DIR="' .
                    $libernet_dir .
                    '" && ' .
                    $libernet_dir .
                    "/bin/service.sh -ds"
            );
            json_response("Libernet service stopped");
            break;
        case "get_wan_ip":
        
            $json = shell_exec(
                "curl --socks5-hostname 127.0.0.1:1080 -s http://ip-api.com/json"
            );
        
            $data = json_decode($json, true);
        
            echo json_encode([
                "status" => !empty($data["query"]),
                "data"   => $data["query"] ?? "",
                "isp"    => isset($data["isp"])
                    ? "{$data['country']}, {$data['isp']} ({$data['as']})"
                    : ""
            ]);
        
        break;
        case "get_dashboard_info":
        
            $status = file_get_contents($libernet_dir . "/log/status.log");
            $log = file_get_contents($libernet_dir . "/log/service.log");
            $connected = file_get_contents($libernet_dir . "/log/connected.log");
        
            $core_log = "";
            
            if (file_exists("/tmp/qssh.log")) {
                $core_log .= tail("/tmp/qssh.log", 50);
            }
            
            if (file_exists("/tmp/qload.log")) {
                $core_log .= "\n\n================ QLOAD ================\n";
                $core_log .= tail("/tmp/qload.log", 50);
            }
        
            $tx = "0 B";
            $rx = "0 B";
        
            $connections = @file_get_contents("http://127.0.0.1:9090/connections");
        
            if ($connections !== false) {
                $connections = json_decode($connections, true);
        
                if (isset($connections["uploadTotal"])) {
                    $tx = formatBytes($connections["uploadTotal"]);
                }
        
                if (isset($connections["downloadTotal"])) {
                    $rx = formatBytes($connections["downloadTotal"]);
                }
            }
        
            json_response([
                "status" => intval($status),
                "log" => $log,
                "core_log" => $core_log,
                "connected" => $connected,
                "total_data" => [
                    "tx" => $tx,
                    "rx" => $rx,
                ],
            ]);
        
        break;
        case "get_ping_setting":
            $system_config = file_get_contents(
                $libernet_dir . "/system/config.json"
            );

            $system_config = json_decode($system_config);

            json_response($system_config->settings->ping);

            break;

        case "save_ping_setting":
            $system_config = file_get_contents(
                $libernet_dir . "/system/config.json"
            );

            $system_config = json_decode($system_config);

            $system_config->settings->ping->enable = $json["enable"];

            $system_config->settings->ping->host = $json["host"];

            $system_config->settings->ping->interval = intval(
                $json["interval"]
            );

            $system_config->settings->ping->timeout = intval($json["timeout"]);

            $system_config->settings->ping->fail_count = intval(
                $json["fail_count"]
            );
            $system_config->settings->ping->log_interval =
            intval($json["log_interval"]);
            file_put_contents(
                $libernet_dir . "/system/config.json",
                json_encode(
                    $system_config,
                    JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
                )
            );

            json_response("Ping Monitor saved");

            break;
        case "get_system_setting":
            $system_config = json_decode(
                file_get_contents($libernet_dir . "/system/config.json")
            );

            json_response([
                "autoboot" => $system_config->tunnel->autostart,

                "autoreconnect" =>
                    $system_config->settings->autoreconnect->enable,

                "autoswitch" => $system_config->settings->autoswitch->enable,

                "memory" => $system_config->settings->memory->enable,
            ]);

            break;

        case "save_system_setting":
            $system_config = json_decode(
                file_get_contents($libernet_dir . "/system/config.json")
            );

            $data = $json["data"];

            $system_config->tunnel->autostart = $data["autoboot"];

            $system_config->settings->autoreconnect->enable =
                $data["autoreconnect"];

            $system_config->settings->autoswitch->enable = $data["autoswitch"];

            $system_config->settings->memory->enable = $data["memory"];

            file_put_contents(
                $libernet_dir . "/system/config.json",
                json_encode(
                    $system_config,
                    JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
                )
            );

            json_response("System settings saved");

            break;
        case "get_clash_log":
            $log = "";

            if (file_exists("/root/libernet/log/clash.log")) {
                $lines = explode(
                    "\n",
                    trim(
                        shell_exec("tail -n 200 /root/libernet/log/clash.log")
                    )
                );

                $output = [];

                foreach ($lines as $line) {
                    if (
                        preg_match(
                            '/time="([^"]+)".*level=(\w+).*msg="(.*)"/',
                            $line,
                            $m
                        )
                    ) {
                        preg_match(
                            "/T([0-9]{2}:[0-9]{2}:[0-9]{2})/",
                            $m[1],
                            $tm
                        );

                        $time = $tm[1];

                        $level = strtoupper($m[2]);

                        $msg = $m[3];

                        $output[] = "[$time] [$level] $msg";
                    } else {
                        $output[] = $line;
                    }
                }

                $log = implode("\n", $output);
            }

            echo json_encode([
                "status" => true,
                "data" => htmlspecialchars($log),
            ]);

            break;

        case "save_config":
            if (isset($json["data"])) {
                $system_config = file_get_contents(
                    $libernet_dir . "/system/config.json"
                );
                $system_config = json_decode($system_config);
                $data = $json["data"];
                $mode = $data["mode"];
                $profile = $data["profile"];
                $config = $data["config"];
                switch ($mode) {
                    // ssh
                    case 0:
                        file_put_contents(
                            $libernet_dir .
                                "/bin/config/ssh/" .
                                $profile .
                                ".json",
                            json_encode(
                                $config,
                                JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
                            )
                        );
                        json_response("SSH config saved");
                        break;
                    // v2ray
                    case 1:
                        $protocol = $config["protocol"];
                        $network = $config["network"];
                        $security = $config["security"];
                        // remote server
                        $host = $config["server"]["host"];
                        $port = $config["server"]["port"];
                        // user settings
                        $user_level = $config["server"]["user"]["level"];
                        $vmess_id = $config["server"]["user"]["vmess"]["id"];
                        $vless_id = $config["server"]["user"]["vless"]["id"];
                        $vmess_security =
                            $config["server"]["user"]["vmess"]["security"];
                        $trojan_password =
                            $config["server"]["user"]["trojan"]["password"];
                        // stream settings
                        $sni = $config["stream"]["sni"];
                        $path = $config["stream"]["path"];
                        // misc
                        $ip = $config["etc"]["ip"];
                        $udpgw_ip = $config["etc"]["udpgw"]["ip"];
                        $udpgw_port = $config["etc"]["udpgw"]["port"];
                        switch ($protocol) {
                            // vmess
                            case "vmess":
                                $vmess_config = file_get_contents(
                                    $libernet_dir .
                                        "/bin/config/v2ray/templates/vmess.json"
                                );
                                $vmess_config = json_decode($vmess_config);
                                $vmess_config->outbounds[0]->settings->vnext[0]->address = $host;
                                $vmess_config->outbounds[0]->settings->vnext[0]->port = $port;
                                $vmess_config->outbounds[0]->settings->vnext[0]->users[0]->level = $user_level;
                                $vmess_config->outbounds[0]->settings->vnext[0]->users[0]->alterId = $user_level;
                                $vmess_config->outbounds[0]->settings->vnext[0]->users[0]->id = $vmess_id;
                                $vmess_config->outbounds[0]->settings->vnext[0]->users[0]->security = $vmess_security;
                                set_v2ray_config(
                                    $vmess_config,
                                    $protocol,
                                    $network,
                                    $security,
                                    $sni,
                                    $path,
                                    $ip,
                                    $udpgw_ip,
                                    $udpgw_port
                                );
                                file_put_contents(
                                    $libernet_dir .
                                        "/bin/config/v2ray/" .
                                        $profile .
                                        ".json",
                                    json_encode(
                                        $vmess_config,
                                        JSON_PRETTY_PRINT |
                                            JSON_UNESCAPED_SLASHES
                                    )
                                );
                                json_response("V2Ray vmess config saved");
                                break;
                            // vless
                            case "vless":
                                $vless_config = file_get_contents(
                                    $libernet_dir .
                                        "/bin/config/v2ray/templates/vless.json"
                                );
                                $vless_config = json_decode($vless_config);
                                $vless_config->outbounds[0]->settings->vnext[0]->address = $host;
                                $vless_config->outbounds[0]->settings->vnext[0]->port = $port;
                                $vless_config->outbounds[0]->settings->vnext[0]->users[0]->level = $user_level;
                                $vless_config->outbounds[0]->settings->vnext[0]->users[0]->id = $vless_id;
                                set_v2ray_config(
                                    $vless_config,
                                    $protocol,
                                    $network,
                                    $security,
                                    $sni,
                                    $path,
                                    $ip,
                                    $udpgw_ip,
                                    $udpgw_port
                                );
                                file_put_contents(
                                    $libernet_dir .
                                        "/bin/config/v2ray/" .
                                        $profile .
                                        ".json",
                                    json_encode(
                                        $vless_config,
                                        JSON_PRETTY_PRINT |
                                            JSON_UNESCAPED_SLASHES
                                    )
                                );
                                json_response("V2Ray vless config saved");
                                break;
                            // trojan
                            case "trojan":
                                $trojan_config = file_get_contents(
                                    $libernet_dir .
                                        "/bin/config/v2ray/templates/trojan.json"
                                );
                                $trojan_config = json_decode($trojan_config);
                                $trojan_config->outbounds[0]->settings->servers[0]->address = $host;
                                $trojan_config->outbounds[0]->settings->servers[0]->port = $port;
                                $trojan_config->outbounds[0]->settings->servers[0]->level = $user_level;
                                $trojan_config->outbounds[0]->settings->servers[0]->password = $trojan_password;
                                set_v2ray_config(
                                    $trojan_config,
                                    $protocol,
                                    $network,
                                    $security,
                                    $sni,
                                    $path,
                                    $ip,
                                    $udpgw_ip,
                                    $udpgw_port
                                );
                                file_put_contents(
                                    $libernet_dir .
                                        "/bin/config/v2ray/" .
                                        $profile .
                                        ".json",
                                    json_encode(
                                        $trojan_config,
                                        JSON_PRETTY_PRINT |
                                            JSON_UNESCAPED_SLASHES
                                    )
                                );
                                json_response("V2Ray trojan config saved");
                                break;
                        }
                        break;
                        
                        // qssh
                        case 2:
                        
                            file_put_contents(
                                $libernet_dir .
                                    "/bin/config/qssh/" .
                                    $profile .
                                    ".json",
                                json_encode(
                                    $config,
                                    JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
                                )
                            );
                        
                            json_response("QSSH config saved");
                            break;
                      }  
                     }  
                     break;
        case "apply_config":
            if (isset($json["data"])) {
                $system_config = file_get_contents(
                    $libernet_dir . "/system/config.json"
                );
                $system_config = json_decode($system_config);
                $data = $json["data"];
                $profile = $data["profile"];
                $mode = $data["mode"];
                switch ($mode) {
                    // ssh
                    case 0:
                        $ssh_config = file_get_contents(
                            $libernet_dir .
                                "/bin/config/ssh/" .
                                $profile .
                                ".json"
                        );
                        $ssh_config = json_decode($ssh_config);
                        $system_config->tunnel->profile->ssh = $profile;
                        $system_config->server = $ssh_config->ip;
                        $system_config->network->udpgw->ip =
                        $ssh_config->udpgw->ip;
                        $system_config->network->udpgw->port =
                            $ssh_config->udpgw->port;
                            $system_config->network->socks->ip = "127.0.0.1";
                        $system_config->network->socks->port = 1080;
                        break;
                    // v2ray
                    case 1:
                        $v2ray_config = file_get_contents(
                            $libernet_dir .
                                "/bin/config/v2ray/" .
                                $profile .
                                ".json"
                        );
                        $v2ray_config = json_decode($v2ray_config);
                        $system_config->tunnel->profile->v2ray = $profile;
                        $system_config->server = $v2ray_config->etc->ip;
                        $system_config->network->udpgw->ip =
                            $v2ray_config->etc->udpgw->ip;
                        $system_config->network->udpgw->port =
                            $v2ray_config->etc->udpgw->port;
                        break;
                    // qssh    
                    case 2:
                        $qssh_config = file_get_contents(
                            $libernet_dir .
                            "/bin/config/qssh/" .
                            $profile .
                            ".json"
                        );
                    
                        $qssh_config = json_decode($qssh_config);
                    
                        $system_config->tunnel->profile->qssh = $profile;
                    
                        $system_config->server = $qssh_config->ssh->ip;
                    
                        // QSSH pakai q-load
                        $system_config->network->socks->ip = "127.0.0.1";
                        $system_config->network->qload->port = 7777;
                    
                    break;                          
                        }
                        $system_config->tunnel->mode = $mode;
                        $system_config = json_encode(
                            $system_config,
                            JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
                        );
                        file_put_contents(
                            $libernet_dir . "/system/config.json",
                            $system_config
                        );
                        json_response("Configuration applied");
                       
                        break; 
                    }  
           
        case "delete_config":
            if (isset($json["data"])) {
                $data = $json["data"];
                $mode = $data["mode"];
                $profile = $data["profile"];
                switch ($mode) {
                    case 0:
                        unlink(
                            $libernet_dir .
                                "/bin/config/ssh/" .
                                $profile .
                                ".json"
                        );
                        json_response("SSH config removed");
                        break;
                    case 1:
                        unlink(
                            $libernet_dir .
                                "/bin/config/v2ray/" .
                                $profile .
                                ".json"
                        );
                        json_response("V2Ray config removed");
                        break;
                    case 2:
                    
                        unlink(
                            $libernet_dir .
                            "/bin/config/qssh/" .
                            $profile .
                            ".json"
                        );
                    
                        json_response("QSSH config removed");
                    
                    break;                        
                }
            }
            break;
        case "set_auto_start":
            $status = $json["status"];
            set_auto_start($status);
            if ($status) {
                json_response("Libernet service auto start enabled");
            } else {
                json_response("Libernet service auto start disabled");
            }
            break;
        case "run_speedtest":
            putenv("HOME=/root");
            putenv("USER=root");
            putenv("LOGNAME=root");

            $json_out = shell_exec(
                "/usr/bin/speedtest --accept-license --accept-gdpr --progress=no --format=json 2>&1"
            );

            if (!$json_out) {
                echo json_encode([
                    "status" => false,
                    "message" => "Speedtest failed",
                ]);

                break;
            }

            $data = json_decode($json_out, true);

            if (!$data) {
                echo json_encode([
                    "status" => false,
                    "message" => $json_out,
                ]);

                break;
            }

            echo json_encode([
                "status" => true,

                "ping" => round($data["ping"]["latency"]),
                "download" => round(
                    ($data["download"]["bandwidth"] * 8) / 1000000
                ),
                "upload" => round(($data["upload"]["bandwidth"] * 8) / 1000000),

                "isp" => $data["isp"],

                "server" => $data["server"]["name"],
                "location" => $data["server"]["location"],
            ]);

            break;
        case "check_update":
            $update_status = file_get_contents(
                $libernet_dir . "/log/update.log"
            );
            json_response($update_status);
            break;
        case "update_libernet":
            $output = null;
            $retval = null;
            exec(
                'export LIBERNET_DIR="' .
                    $libernet_dir .
                    '" && ' .
                    $libernet_dir .
                    "/update.sh -web > /dev/null 2>&1 &",
                $output,
                $retval
            );
            if (!$retval) {
                json_response("Libernet updated!");
            }
            break;
        case "resolve_host":
            $output = null;
            $retval = null;
            $host = $json["host"];
            exec(
                "ping -4Ac 1 -W 1 " .
                    $host .
                    " | grep PING | awk '{print $3}' | sed 's/(//g; s/)//g; s/://g' | sed -n '1p'",
                $output,
                $retval
            );
            if (!$retval) {
                json_response($output);
            }
            break;
        case "change_password":
            $password = $json["password"];
            $system_config = file_get_contents(
                $libernet_dir . "/system/config.json"
            );
            $system_config = json_decode($system_config);
            $system_config->system->password = $password;
            $system_config = json_encode(
                $system_config,
                JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
            );
            file_put_contents(
                $libernet_dir . "/system/config.json",
                $system_config
            );
            json_response("Password changed");
            break;
    }
}
?>
