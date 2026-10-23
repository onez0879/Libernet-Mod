const app = new Vue({
    el: '#app',
    data() {
        return {
            config: {
                mode: 0,
                profile: "",
                profiles: [],
                temp: {
                    mode: 0,
                    profile: "",
                    modes: [
                        {
                            value: 0,
                            name: "SSH",
                            profile: {
                                ip: "",
                                host: "",
                                port: null,
                                username: "",
                                password: "",
                                udpgw: {
                                    ip: "127.0.0.1",
                                    port: null
                                },
                                "concurrency": {
                                    "workers": 2,
                                    "start_port": 1080
                                },
                                enable_http: true,
                                http: {
                                    buffer: 32767,
                                    ip: "127.0.0.1",
                                    port: 9876,
                                    info: "HTTP Proxy",
                                    payload: "",
                                    proxy: {
                                        ip: "",
                                        port: null
                                    }
                                }
                            }
                        },
                    
                        {
                            value: 1,
                            name: "V2RAY",
                            protocols: [
                                {
                                    name: "VMess",
                                    value: "vmess",
                                    securities: [
                                        "auto",
                                        "aes-128-gcm",
                                        "chacha20-poly1305",
                                        "none"
                                    ]
                                },
                                {
                                    name: "VLESS",
                                    value: "vless"
                                },
                                {
                                    name: "Trojan",
                                    value: "trojan"
                                }
                            ],
                            networks: [
                                {
                                    name: "TCP",
                                    value: "tcp"
                                },
                                {
                                    name: "WebSocket",
                                    value: "ws"
                                },
                                {
                                    name: "HTTP",
                                    value: "http"
                                }
                            ],
                            securities: [
                                {
                                    name: "None",
                                    value: "none"
                                },
                                {
                                    name: "TLS",
                                    value: "tls"
                                }
                            ],
                            import_url: "",
                            profile: {
                                protocol: "",
                                network: "",
                                security: "",
                                server: {
                                    host: "",
                                    port: null,
                                    user: {
                                        level: 0,
                                        vmess: {
                                            id: "",
                                            security: ""
                                        },
                                        vless: {
                                            id: ""
                                        },
                                        trojan: {
                                            password: ""
                                        }
                                    }
                                },
                                stream: {
                                    sni: "",
                                    path: ""
                                },
                                etc: {
                                    ip: "",
                                    udpgw: {
                                        ip: "127.0.0.1",
                                        port: null
                                    }
                                }
                            }
                        },
                    
                        {
                            value: 2,
                            name: "QSSH",
                            profile: {
                                listen: {
                                    host: "127.0.0.1",
                                    port: 1080
                                },
                                concurrency: {
                                    enable: true,
                                    workers: 2,
                                    start_port: 1080
                                },
                                ssh: {
                                    host: "",
                                    ip: "",
                                    port: 80,
                                    username: "",
                                    password: ""
                                },
                                network: {
                                    type: "tcp"
                                },
                                transport: {
                                    tls: false,
                                    host: "",
                                    path: "/",
                                    sni: ""
                                },
                                proxy: {
                                    enable: true,
                                    host: "",
                                    port: 80
                                },
                                payload: {
                                    enable: true,
                                    request: "",
                                    expect: ["200", "101"]
                                },
                                ip: ""
                            }
                        }
                    ]
                },
                
                importPayload: "",
                system: {}
            }
        }
    },
    watch: {
        'config.mode': function (mode) {
            this.getProfiles(mode)
            this.config.profile = ""
            this.config.temp.mode = mode
        },
        'config.temp.profile': function (val) {
            this.config.temp.profile = val.split(' ').join('_')
        }
    },
    methods: {
        decodePath: _.debounce(function () {
            this.config.temp.modes[1].profile.stream.path = decodeURIComponent(JSON.parse('"' + this.config.temp.modes[1].profile.stream.path + '"'))
        }, 500),
        getProfiles(mode) {
            let action
            switch (mode) {
                case 0:
                    action = "get_ssh_configs"
                    break
                case 1:
                    action = "get_v2ray_configs"
                    break
                case 2:
                    action = "get_qssh_configs"
                    break
            }
            axios.post('api.php', {
                action: action
            }).then((res) => {
                this.config.profiles = res.data.data
            })
        },
        getConfig() {
            this.getSystemConfig().then((res) => {
                this.config.system = res
                switch (this.config.mode) {
                    case 0:
                        this.getSshConfig()
                        break
                    case 1:
                        this.getV2rayConfig()
                        break
                    case 2:
                        this.getQsshConfig()
                        break
                }
                // ensure temp.mode follows config.mode so form always matches
                this.config.temp.mode = this.config.mode
                // resolve server host
                this.resolveServerHost()
            })
        },
        deleteConfig() {
            Swal.fire({
                title: 'Are you sure?',
                text: "You won't be able to revert this!",
                icon: 'warning',
                reverseButtons: true,
                showCancelButton: true,
                confirmButtonColor: '#3085d6',
                cancelButtonColor: '#d33',
                confirmButtonText: 'Yes, delete it!'
            }).then((result) => {
                if (result.isConfirmed) {
                    axios.post('api.php', {
                        action: "delete_config",
                        data: {
                            mode: this.config.mode,
                            profile: this.config.profile
                        }
                    }).then(() => {
                        Swal.fire({
                            position: 'center',
                            icon: 'success',
                            title: 'Config has been removed',
                            showConfirmButton: false,
                            timer: 1500
                        })
                        this.config.profile = ""
                        this.getProfiles(this.config.mode)
                    })
                }
            })
        },
        getSshConfig() {
            axios.post('api.php', {
                action: "get_ssh_config",
                profile: this.config.profile
            }).then((res) => {
                const temp = this.config.temp
                temp.mode = 0
                temp.profile = this.config.profile
                temp.modes[0].profile = res.data.data
            })
        },
        getV2rayConfig() {
            axios.post('api.php', {
                action: "get_v2ray_config",
                profile: this.config.profile
            }).then((res) => {
                const temp = this.config.temp
                // pin V2RAY form even if saved config is incomplete/missing
                temp.mode = 1
                temp.profile = this.config.profile

                const profile = temp.modes[1].profile
                const data = res.data && res.data.data ? res.data.data : null
                if (!data || !data.outbounds || !data.outbounds[0]) {
                    Swal.fire({
                        icon: "info",
                        title: "Config kosong",
                        text: "Silakan pilih profil yang benar",
                        showConfirmButton: false,
                        timer: 1500
                    })
                    return
                }

                const protocol = data.outbounds[0].protocol
                const streamSettings = data.outbounds[0].streamSettings
                const network = streamSettings ? streamSettings.network : "tcp"
                const security = streamSettings ? streamSettings.security : "none"
                let remote
                let sni
                let path = ""

                // set mode & profile
                temp.mode = 1
                temp.profile = this.config.profile

                profile.protocol = protocol
                profile.network = network
                profile.security = security
                switch (protocol) {
                    // vmess
                    case "vmess":
                        remote = res.data.data.outbounds[0].settings.vnext[0]
                        profile.server.host = remote.address
                        profile.server.port = remote.port
                        profile.server.user.level = remote.users[0].level
                        profile.server.user.vmess.id = remote.users[0].id
                        profile.server.user.vmess.security = remote.users[0].security
                        break
                    // vless
                    case "vless":
                        remote = res.data.data.outbounds[0].settings.vnext[0]
                        profile.server.host = remote.address
                        profile.server.port = remote.port
                        profile.server.user.level = remote.users[0].level
                        profile.server.user.vless.id = remote.users[0].id
                        break
                    // trojan
                    case "trojan":
                        remote = res.data.data.outbounds[0].settings.servers[0]
                        profile.server.host = remote.address
                        profile.server.port = remote.port
                        profile.level = remote.level
                        profile.server.user.trojan.password = remote.password
                        break
                }
                switch (network) {
                    // tcp
                    case "tcp":
                        sni = res.data.data.outbounds[0].streamSettings.tlsSettings.serverName
                        break
                    // ws
                    case "ws":
                        sni = res.data.data.outbounds[0].streamSettings.wsSettings.headers.Host
                        path = res.data.data.outbounds[0].streamSettings.wsSettings.path
                        break
                    // http
                    case "http":
                        sni = res.data.data.outbounds[0].streamSettings.httpSettings.host[0]
                        path = res.data.data.outbounds[0].streamSettings.httpSettings.path
                        break
                }
                profile.stream.sni = sni
                profile.stream.path = path
                profile.etc.ip = res.data.data.etc.ip
                profile.etc.udpgw.ip = res.data.data.etc.udpgw.ip
                profile.etc.udpgw.port = res.data.data.etc.udpgw.port
            })
        },
        getQsshConfig() {
        
            axios.post('api.php', {
                action: "get_qssh_config",
                profile: this.config.profile
        
            }).then((res) => {
        
                const temp = this.config.temp
        
                temp.mode = 2
                temp.profile = this.config.profile
        
                temp.modes[2].profile = res.data.data
        
            })
        
        },        
        getSystemConfig() {
            return new Promise((resolve) => {
                axios.post('api.php', {
                    action: "get_system_config"
                }).then((res) => {
                    resolve(res.data.data)
                })
            })
        },
        saveConfig() {
            const configMode = this.config.temp.mode
            const configProfile = this.config.temp.profile
            let config, title
            switch (configMode) {
                case 0:
                    config = this.config.temp.modes[0].profile
                    title = "SSH config has been saved"
                    break
                case 1:
                    config = this.config.temp.modes[1].profile
                    title = "V2RAY config has been saved"
                    break
                case 2:
                    config = this.config.temp.modes[2].profile
                    title = "QSSH config has been saved"
                    break
            }
            axios.post('api.php', {
                action: "save_config",
                data: {
                    mode: configMode,
                    profile: configProfile,
                    config: config
                }
            }).then(() => {
                console.log(title)
                Swal.fire({
                    position: "center",
                    icon: "success",
                    title: title,
                    showConfirmButton: false,
                    timer: 1500
                })
                // reload config menu
                this.config.profile = ""
                this.getProfiles(this.config.mode)
            })
        },
        applyImport(text) {
            const result = importV2rayConfigFromText(text)
            if (!result) {
                Swal.fire({
                    icon: "error",
                    title: "Import failed",
                    text: "Unrecognized URI or JSON"
                })
                return
            }
            const p = this.config.temp.modes[1].profile
            p.protocol = result.protocol
            p.network = result.profile.network
            p.security = result.profile.network === "tcp" ? "tls"
                       : result.profile.network === "http" ? "none"
                       : result.profile.security
            p.server.host = result.profile.server.host
            p.server.port = result.profile.server.port
            p.server.user.level = result.profile.server.user.level
            p.server.user.vmess.id = result.profile.server.user.vmess.id
            p.server.user.vmess.security = result.profile.server.user.vmess.security
            p.server.user.vless.id = result.profile.server.user.vless.id
            p.server.user.trojan.password = result.profile.server.user.trojan.password
            p.stream.sni = result.profile.stream.sni
            p.stream.path = result.profile.stream.path
            if (!this.config.temp.profile) {
                this.config.temp.profile = result.profile.server.host
            }
            if (result.needsHostResolve) this.resolveServerHost()
            Swal.fire({
                position: "center",
                icon: "success",
                title: "Config imported",
                showConfirmButton: false,
                timer: 1200
            })
        },
        importConfigFromText() {
            this.applyImport(this.importPayload)
        },
        importV2rayConfig() {
            this.applyImport(this.config.temp.modes[1].import_url)
        },
        resolveServerHost: _.debounce(function () {
            switch (this.config.temp.mode) {
                case 0:
                    axios.post('api.php', {
                        action: 'resolve_host',
                        host: this.config.temp.modes[0].profile.host
                    }).then((res) => {
                        this.config.temp.modes[0].profile.ip = res.data.data[0]
                    })
                    break
                // v2ray
                case 1:
                    axios.post('api.php', {
                        action: 'resolve_host',
                        host: this.config.temp.modes[1].profile.server.host
                    }).then((res) => {
                        this.config.temp.modes[1].profile.etc.ip = res.data.data[0]
                    })
                    break
                case 2:
                    axios.post('api.php', {
                        action: 'resolve_host',
                        host: this.config.temp.modes[2].profile.ssh.host
                    }).then((res) => {
                        this.config.temp.modes[2].profile.ssh.ip = res.data.data[0]
                    })
                    break
            }
        }, 500)
    },
    created() {
        // init mode + profile from the router system config so the dropdown
        // and Load follow the configured mode (was: empty dropdown, SSH mode)
        this.getSystemConfig().then((system) => {
            const names = ["ssh", "v2ray", "qssh"]
            const tunnel = (system && system.tunnel) || {}
            const m = tunnel.mode
            const mode = (m === 0 || m === 1 || m === 2) ? m : 0
            const prof = (tunnel.profile && tunnel.profile[names[mode]]) || ""
            if (mode === this.config.mode) {
                this.getProfiles(mode)
                this.config.profile = prof
            } else {
                // the config.mode watcher loads the right profiles, clears the
                // stale profile and syncs temp.mode; restore saved profile after
                this.config.mode = mode
                this.$nextTick(() => { this.config.profile = prof })
            }
        })
    }
})
