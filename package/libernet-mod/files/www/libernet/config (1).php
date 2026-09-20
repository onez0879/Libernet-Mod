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
                         <a href="setting.php">
                            <i class="fa fa-gear"></i>
                            <span>Setting</span>
                        </a>
                        <a href="config.php" class="active">
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

                    <form @submit.prevent="getConfig">
                            <div class="form-group form-row my-auto">
                                <div class="col-lg-4 col-md-4 form-row py-1">
                                    <div class="col-lg-4 col-md-3 my-auto">
                                        <label class="my-auto">Mode</label>
                                    </div>
                                    <div class="col">
                                        <select class="form-control" v-model.number="config.mode" required>
                                            <option v-for="mode in config.temp.modes" :value="mode.value">{{ mode.name }}</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-lg-4 col-md-4 form-row py-1">
                                    <div class="col-lg-4 col-md-3 my-auto">
                                        <label class="my-auto">Config</label>
                                    </div>
                                    <div class="col">
                                        <select class="form-control" v-model="config.profile" required>
                                            <option v-for="profile in config.profiles" :value="profile">{{ profile }}</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-lg-4 col-md-3 form-row py-1">
                                    <div class="col d-flex">
                                        <button type="submit" class="btn btn-secondary mr-1">Load</button>
                                        <button type="button" class="btn btn-danger ml-1" @click="deleteConfig">Delete</button>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="card-body">
                        <form @submit.prevent="saveConfig">
                            <div class="form-row pb-lg-2">
                                <div class="col-md-6">
                                    <label>Mode</label>
                                    <select v-model.number="config.temp.mode" class="form-control" required>
                                        <option v-for="mode in config.temp.modes" :value="mode.value">{{ mode.name }}</option>
                                    </select>
                                </div>
                                  <div v-if="config.temp.mode === 2"
                                 class="col-md-6 pt-md-4 pl-lg-3 my-auto">
                            
                                <div class="form-check">
                                    <input
                                        class="form-check-input"
                                        type="checkbox"
                                        id="enable-proxy-qssh"
                                        v-model="config.temp.modes[2].profile.proxy.enable">
                            
                                    <label class="form-check-label"
                                           for="enable-proxy-qssh">
                                        Enable HTTP Proxy
                                    </label>
                                </div>
                            
                            </div>       								
                                <div v-if="config.temp.mode === 0" class="col-md-6 pt-md-4 pl-lg-3 my-auto">
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" v-model="config.temp.modes[0].profile.enable_http" checked id="enable-http">
                                        <label class="form-check-label" for="enable-http">
                                            Enable HTTP Proxy
                                        </label>
                                    </div>
                                </div>
                                <div v-if="config.temp.mode === 1" class="col-md-6">
                                    <label>Protocol</label>
                                    <select class="form-control" v-model="config.temp.modes[1].profile.protocol" required>
                                        <option v-for="protocol in config.temp.modes[1].protocols" :value="protocol.value">{{ protocol.name }}</option>
                                    </select>
                                </div>
                            </div>

                            <div v-if="config.temp.mode === 0" class="ssh pb-lg-2">
                                <div v-if="config.temp.modes[0].profile.enable_http" class="proxy">
                                    <div class="form-row pb-lg-2">
                                        <div class="col-md-6">
                                            <label>Proxy IP</label>
                                            <input type="text" class="form-control" placeholder="192.168.1.1" v-model="config.temp.modes[0].profile.http.proxy.ip" required>
                                        </div>
                                        <div class="col-md-6">
                                            <label>Proxy Port</label>
                                            <input type="number" class="form-control" placeholder="8080" v-model.number="config.temp.modes[0].profile.http.proxy.port" required>
                                        </div>
                                    </div>
                                    <div class="form-group">
                                        <label>Payload</label>
                                        <textarea class="form-control" v-model="config.temp.modes[0].profile.http.payload" rows="5" placeholder="GET http://libernet.tld/ HTTP/1.1[crlf][crlf]CONNECT [host_port] HTTP/1.1[crlf]Connection: keep-allive[crlf][crlf]" required></textarea>
                                    </div>
                                </div>
                                <div class="form-row pb-lg-2">
                                    <div class="col-md-6">
                                        <label>Server Host</label>
                                        <input type="text" class="form-control" placeholder="Host/IP" v-model="config.temp.modes[0].profile.host" @input="resolveServerHost" required>
                                    </div>
                                    <div class="col-md-3">
                                        <label>Server IP</label>
                                        <input type="text" class="form-control" placeholder="192.168.1.1" v-model="config.temp.modes[0].profile.ip" required>
                                    </div>
                                    <div class="col-md-3">
                                        <label>Server Port</label>
                                        <input type="number" class="form-control" placeholder="443" v-model.number="config.temp.modes[0].profile.port" required>
                                    </div>
                                </div>
                                <div class="form-row">
                                    <div class="col-md-3">
                                        <label>Username</label>
                                        <input type="text" class="form-control" placeholder="Username"
                                               v-model="config.temp.modes[0].profile.username" required>
                                    </div>
                                
                                    <div class="col-md-3">
                                        <label>Password</label>
                                        <input type="text" class="form-control" placeholder="Password"
                                               v-model="config.temp.modes[0].profile.password" required>
                                    </div>
                                
                                    <div class="col-md-3">
                                        <label>UDPGW Port</label>
                                        <input type="number" class="form-control" placeholder="7300"
                                               v-model.number="config.temp.modes[0].profile.udpgw.port" required>
                                    </div>
                                
                                    <div class="col-md-3">
                                        <label>Worker Count</label>
                                        <input type="number"
                                               class="form-control"
                                               min="1"
                                               max="10"
                                               placeholder="2"
                                               v-model.number="config.temp.modes[0].profile.concurrency.workers">
                                    </div>
                                  </div>
                              </div>

<div v-if="config.temp.mode === 1" class="v2ray">

    <!-- General -->
    <div class="card mb-3">
        <div class="card-header">
            General
        </div>

        <div class="card-body">

            <div class="form-row">

                <div class="col-md-3">
                    <label>Protocol</label>

                    <select class="custom-select"
                        v-model="config.temp.modes[1].profile.protocol">

                        <option value="trojan">Trojan</option>
                        <option value="vless">VLESS</option>
                        <option value="vmess">VMess</option>

                    </select>

                </div>

                <div class="col-md-2">
                    <label>Workers</label>

                    <input
                        type="number"
                        min="1"
                        class="form-control"
                        v-model.number="config.temp.modes[1].profile.concurrency.workers">

                </div>

                <div class="col-md-2">
                    <label>Start Port</label>

                    <input
                        type="number"
                        class="form-control"
                        v-model.number="config.temp.modes[1].profile.concurrency.start_port">

                </div>

            </div>

        </div>
    </div>


    <!-- Accounts -->

    <div class="card">

        <div class="card-header d-flex justify-content-between">

            <span>Accounts</span>

            <button
                class="btn btn-sm btn-success"
                @click="addV2rayAccount">

                + Add

            </button>

        </div>

        <div class="card-body p-0">

            <div class="row no-gutters">

                <!-- LEFT -->

                <div class="col-md-3 border-right">

                    <div class="list-group list-group-flush">

                        <a

                            v-for="(acc,index) in config.temp.modes[1].profile.accounts"

                            href="#"

                            class="list-group-item list-group-item-action"

                            :class="{active:index==config.temp.modes[1].profile.selected}"

                            @click.prevent="config.temp.modes[1].profile.selected=index">

                            {{acc.name || ('Account '+(index+1))}}

                        </a>

                    </div>

                </div>


                <!-- RIGHT -->

                <div class="col-md-9 p-3">

                    <div
                        v-if="config.temp.modes[1].profile.accounts.length">

                        <div class="form-row">

                            <div class="col-md-6">

                                <label>Name</label>

                                <input

                                    class="form-control"

                                    v-model="selectedAccount.name">

                            </div>

                        </div>

                        <hr>

                        <div class="form-row">

                            <div class="col-md-5">

                                <label>Server</label>

                                <input

                                    class="form-control"

                                    v-model="selectedAccount.server.host">

                            </div>

                            <div class="col-md-2">

                                <label>Port</label>

                                <input

                                    type="number"

                                    class="form-control"

                                    v-model.number="selectedAccount.server.port">

                            </div>

                            <div class="col-md-5">

                                <label>SNI</label>

                                <input

                                    class="form-control"

                                    v-model="selectedAccount.stream.sni">

                            </div>

                        </div>

                        <!-- Trojan -->

                        <div

                            v-if="config.temp.modes[1].profile.protocol=='trojan'"

                            class="form-row mt-3">

                            <div class="col">

                                <label>Password</label>

                                <input

                                    class="form-control"

                                    v-model="selectedAccount.server.user.trojan.password">

                            </div>

                        </div>


                        <!-- VLESS -->

                        <div

                            v-if="config.temp.modes[1].profile.protocol=='vless'"

                            class="form-row mt-3">

                            <div class="col">

                                <label>UUID</label>

                                <input

                                    class="form-control"

                                    v-model="selectedAccount.server.user.vless.id">

                            </div>

                        </div>


                        <!-- VMESS -->

                        <div

                            v-if="config.temp.modes[1].profile.protocol=='vmess'"

                            class="form-row mt-3">

                            <div class="col-md-8">

                                <label>UUID</label>

                                <input

                                    class="form-control"

                                    v-model="selectedAccount.server.user.vmess.id">

                            </div>

                            <div class="col-md-4">

                                <label>Security</label>

                                <select

                                    class="custom-select"

                                    v-model="selectedAccount.server.user.vmess.security">

                                    <option value="auto">auto</option>
                                    <option value="aes-128-gcm">aes-128-gcm</option>
                                    <option value="chacha20-poly1305">chacha20-poly1305</option>

                                </select>

                            </div>

                        </div>

                        <div class="form-row mt-3">

                            <div class="col-md-3">

                                <label>Network</label>

                                <select

                                    class="custom-select"

                                    v-model="selectedAccount.network">

                                    <option value="ws">WebSocket</option>
                                    <option value="grpc">gRPC</option>
                                    <option value="http">HTTP</option>
                                    <option value="tcp">TCP</option>

                                </select>

                            </div>

                            <div class="col-md-9">

                                <label>Path</label>

                                <input

                                    class="form-control"

                                    v-model="selectedAccount.stream.path">

                            </div>

                        </div>

                        <div class="text-right mt-3">

                            <button

                                class="btn btn-danger"

                                @click="deleteV2rayAccount">

                                Delete Account

                            </button>

                        </div>

                    </div>

                </div>

            </div>

        </div>

    </div>

</div>

                            <div v-if="config.temp.mode === 2" class="qssh pb-lg-2">
                            
                            
                                <!-- HTTP Proxy -->
                       
                                <div v-if="config.temp.modes[2].profile.proxy.enable">
                            
                                    <div class="form-row pb-lg-2">
                            
                                        <div class="col-md-6">
                                            <label>Proxy Host</label>
                                            <input type="text"
                                                   class="form-control"
                                                   placeholder="example.com"
                                                   v-model="config.temp.modes[2].profile.proxy.host">
                                        </div>
                            
                                        <div class="col-md-6">
                                            <label>Proxy Port</label>
                                            <input type="number"
                                                   class="form-control"
                                                   placeholder="80"
                                                   v-model.number="config.temp.modes[2].profile.proxy.port">
                                        </div>
                            
                                    </div>
                            
                                    <div class="form-group">
                                        <label>Payload</label>
                                        <textarea class="form-control"
                                                  rows="5"
                                                  v-model="config.temp.modes[2].profile.payload.request"></textarea>
                                    </div>
                            
                                </div>                            
                                <!-- SSH -->
                                <div class="form-row pb-lg-2">
                            
                                    <div class="col-md-6">
                                        <label>Server Host</label>
                                        <input type="text"
                                               class="form-control"
                                               placeholder="Host/IP"
                                               v-model="config.temp.modes[2].profile.ssh.host"
                                               @input="resolveServerHost"
                                               required>
                                    </div>
                            
                                    <div class="col-md-3">
                                        <label>Server IP</label>
                                        <input type="text"
                                               class="form-control"
                                               placeholder="192.168.1.1"
                                               v-model="config.temp.modes[2].profile.ssh.ip"
                                               required>
                                    </div>
                            
                                    <div class="col-md-3">
                                        <label>Server Port</label>
                                        <input type="number"
                                               class="form-control"
                                               placeholder="80"
                                               v-model.number="config.temp.modes[2].profile.ssh.port"
                                               required>
                                    </div>
                            
                                </div>
                            
                                <div class="form-row pb-lg-2">
                                
                                    <div class="col-md-6">
                                        <label>Username</label>
                                        <input type="text"
                                               class="form-control"
                                               placeholder="Username"
                                               v-model="config.temp.modes[2].profile.ssh.username"
                                               required>
                                    </div>
                                
                                    <div class="col-md-3">
                                        <label>Password</label>
                                        <input type="text"
                                               class="form-control"
                                               placeholder="Password"
                                               v-model="config.temp.modes[2].profile.ssh.password"
                                               required>
                                    </div>
                                
                                    <div class="col-md-3">
                                        <label>Workers</label>
                                        <input type="number"
                                               class="form-control"
                                               min="1"
                                               max="10"
                                               v-model.number="config.temp.modes[2].profile.concurrency.workers">
                                    </div>
                                </div>

                            
                            </div>                 
                            <div class="form-group pb-lg-2 text-center">
                                <label>Config Name</label>
                                <input type="text"
                                       class="form-control text-center"
                                       placeholder="Profil-Name"
                                       v-model="config.temp.profile"
                                       required>
                            </div>
                            
                            <div class="form-group text-center">
                                <button type="submit"
                                        class="btn btn-primary form-control">
                                    Save
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
        <?php include('footer.php'); ?>
    </div>
</div>
<?php include("javascript.php"); ?>
<script src="js/config.js"></script>
</body>
</html>
