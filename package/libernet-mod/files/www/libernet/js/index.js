const app = new Vue({
    el: '#app',
    data() {
        return {
            activeLogTab: 'status',
            logType: 'libernet',
            log: "",
            core_log: "",
            clash_log: "",          
            status: false,
            connection: 0,
            showConfig: false,
            connected: {
                timestamp: 0,
                days: 0,
                hours: 0,
                minutes: 0,
                seconds: 0
            },
            wan_ip: "",
            vpn_isp: "",
            wan_country: "",
            total_data: {
                tx: 0,
                rx: 0
            },
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
                        name: "SSH"
                    },
                    {
                        value: 1,
                        name: "V2RAY"
                    },
                    {
                        value: 2,
                        name: "QSSH"
                    }
                ]                    

                },
                system: {
                    tunnel: {
                        autostart: false,
                        dns_resolver: false,
                        ping_loop: false,
					    auto_switch: false,
					    auto_recon: false
                   
                    },
                    system: {
                        memory_cleaner: false
                    }
                }
            }
        }
    },
    computed: {
        statusText() {
            return this.status === true ? 'Stop' : 'Start'
        },
        connectionText() {
            switch (this.connection) {
                case 0:
                    return 'ready'
                case 1:
                    return 'connecting'
                case 2:
                    return 'connected'
                case 3:
                    return  'stopping'
            }
        },
        connectedTime() {
            return '[' + this.pad(this.connected.days, 2) + ':' + this.pad(this.connected.hours, 2) + ':' + this.pad(this.connected.minutes, 2) + ':' + this.pad(this.connected.seconds, 2) + ']'
        }
    },
    watch: {
        'config.mode': function (mode) {
            this.getProfiles(mode)
        }
    },
methods: {

    startLibernet() {

    this.applyConfig().then(() => {

        axios.post('api.php', {
            action: "set_auto_start",
            status: this.config.system.tunnel.autostart
        }).then(() => {

            axios.post('api.php', {
                action: "start_libernet"
            })

            setTimeout(() => location.reload(), 1000)

        })

    })

},

stopLibernet() {

    if (this.connection === 1) {

        axios.post('api.php', {
            action: "cancel_libernet"
        })

    } else if (this.connection === 2) {

        axios.post('api.php', {
            action: "stop_libernet"
        })

    }

},

restartLibernet() {

    axios.post('api.php', {
        action: "stop_libernet"
    }).then(() => {

        setTimeout(() => {

            this.startLibernet()

        }, 3000)

    })

},
  
        getProfiles(mode) {
            let action
            switch (mode) {
                case 0:
                    action = "get_ssh_configs"
                    break
                case 2:
                    action = "get_qssh_configs"
                    break
                case 1:
                    action = "get_v2ray_configs"
                    break
            }
            axios.post('api.php', {
                action: action
            }).then((res) => {
                this.config.profiles = res.data.data
            })
        },
        applyConfig() {
            return new Promise((resolve) => {
                axios.post('api.php', {
                    action: "apply_config",
                    data: {
                        mode: this.config.mode,
                        profile: this.config.profile,
                        auto_switch: this.config.system.tunnel.auto_switch,
                        dns_resolver: this.config.system.tunnel.dns_resolver,
                        memory_cleaner: this.config.system.system.memory_cleaner,
                        ping_loop: this.config.system.tunnel.ping_loop,
						auto_recon: this.config.system.tunnel.auto_recon							  
                    }
                }).then((res) => {
                    resolve(res)
                })
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
        getWanIp() {
    return new Promise((resolve) => {

        axios.post('api.php', {
            action: "get_wan_ip"
        }).then((res) => {

            this.wan_ip = res.data.data
            this.vpn_isp = res.data.isp

            resolve(res)
        })

    })
        },
        intervalGetWanIp() {
            setInterval(() => {
                this.getWanIp()
            }, 5000)
        },
getDashboardInfo() {

    return new Promise((resolve) => {

        axios.post('api.php', {
            action: "get_dashboard_info"
        }).then((res) => {

            this.status = res.data.data.status !== 0
            this.connection = res.data.data.status

            if (
                this.connection === 2 &&
                parseFloat(res.data.data.connected) > 0
            ) {

                this.connected.timestamp =
                    parseFloat(res.data.data.connected)

                this.updateConnectedTime()

            } else {

                this.connected.timestamp = 0
                this.connected.days = 0
                this.connected.hours = 0
                this.connected.minutes = 0
                this.connected.seconds = 0

            }

            this.log = res.data.data.log
            this.core_log = res.data.data.core_log
           
            this.total_data.tx =
                res.data.data.total_data.tx

            this.total_data.rx =
                res.data.data.total_data.rx

            if (
                this.activeLogTab === "status" &&
                this.$refs.log
            ) {
            
                this.$nextTick(() => {
            
                    this.$refs.log.scrollTop =
                        this.$refs.log.scrollHeight
            
                })
            
            }

            resolve(res)

        })

    })

},

getClashLog() {

    axios.post('api.php', {
        action: "get_clash_log"
    }).then((res) => {

        this.clash_log = res.data.data

        if (
            this.activeLogTab === "clash" &&
            this.$refs.log
        ) {

            this.$nextTick(() => {

                this.$refs.log.scrollTop =
                    this.$refs.log.scrollHeight

            })

        }

    })

},

intervalGetDashboardInfo() {

    setInterval(() => {

        this.getDashboardInfo()
        this.getClashLog()

    }, 1000)

},

updateConnectedTime() {

    const now =
        Math.round(new Date().getTime() / 1000)

    let difference =
        Math.abs(now - this.connected.timestamp)

    const daysDifference =
        Math.floor(difference / 60 / 60 / 24)

    difference -= daysDifference * 60 * 60 * 24

    const hoursDifference =
        Math.floor(difference / 60 / 60)

    difference -= hoursDifference * 60 * 60

    const minutesDifference =
        Math.floor(difference / 60)

    difference -= minutesDifference * 60

    const secondsDifference =
        Math.floor(difference)

    this.connected.days = daysDifference
    this.connected.hours = hoursDifference
    this.connected.minutes = minutesDifference
    this.connected.seconds = secondsDifference

},

pad(n, width, z) {

    z = z || '0'
    n = n + ''

    return n.length >= width
        ? n
        : new Array(
            width - n.length + 1
          ).join(z) + n

}
},
created() {

    this.getSystemConfig().then((res) => {

        const mode = res.tunnel.mode

        this.config.system = res
        this.config.mode = mode

        this.getProfiles(mode)

        switch (mode) {

            case 0:
                this.config.profile =
                    res.tunnel.profile.ssh
                break

            case 2:
                this.config.profile =
                    res.tunnel.profile.qssh
                break

            case 1:
                this.config.profile =
                    res.tunnel.profile.v2ray
                break
        }

    })

    this.getClashLog()

    this.getDashboardInfo().then(() => {

        if (this.$refs.log) {

            this.$refs.log.scrollTop =
                this.$refs.log.scrollHeight

        }

        this.intervalGetDashboardInfo()

    }).catch(() => {

        this.intervalGetDashboardInfo()

    })

    this.getWanIp()
        .then(() => this.intervalGetWanIp())
        .catch(() => this.intervalGetWanIp())

}
})
