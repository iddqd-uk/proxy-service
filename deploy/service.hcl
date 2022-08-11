variable "mtproxy_secret" {
  type        = string
  description = "Generate a new secret: `echo ee$(head -c 16 /dev/urandom | xxd -ps)`"
}

locals {
  mtproxy_version = "1.4"
}

# https://www.nomadproject.io/docs/job-specification/job
job "proxy-service" {
  type        = "service"
  datacenters = ["primary-dc"]
  namespace   = "apps"
  priority    = 25

  # https://www.nomadproject.io/docs/job-specification/group
  group "mtproxy" {
    count = 1

    network {
      port "mtproxy" { to = 443 /* port inside the container */ }
    }

    task "mtproxy" {
      driver = "docker"

      artifact {
        source      = "https://core.telegram.org/getProxySecret"
        mode        = "file"
        destination = "proxy-secret"
      }

      artifact {
        source      = "https://core.telegram.org/getProxyConfig"
        mode        = "file"
        destination = "proxy-multi.conf"
      }

      # https://www.nomadproject.io/docs/drivers/docker
      config {
        image = "telegrammessenger/proxy:${ local.mtproxy_version }"
        ports = ["mtproxy"]

        volumes = [
          "proxy-multi.conf:/etc/proxy-multi.conf:ro",
          "proxy-secret:/etc/proxy-secret:ro",
        ]

        # usage help: `docker run --rm telegrammessenger/proxy:1.4 mtproto-proxy --help`
        #
        #  --ipv6/-6                          	enables ipv6 TCP/UDP support
        #  --max-special-connections/-C <arg> 	sets maximal number of accepted client connections per worker
        #  --domain/-D <arg>                  	adds allowed domain for TLS-transport mode, disables other transports; can be specified more than once
        #  --http-ports/-H <arg>              	comma-separated list of client (HTTP) ports to listen
        #  --slaves/-M <arg>                  	spawn several slave workers; not recommended for TLS-transport mode for better replay protection
        #  --proxy-tag/-P <arg>               	16-byte proxy tag in hex mode to be passed along with all forwarded queries
        #  --mtproto-secret/-S <arg>          	16-byte secret in hex mode
        #  --ping-interval/-T <arg>           	sets ping interval in second for local TCP connections (default 5.000)
        #  --window-clamp/-W <arg>            	sets window clamp for client TCP connections
        #  --backlog/-b <arg>                 	sets backlog size
        #  --connections/-c <arg>             	sets maximal connections number
        #  --daemonize/-d {arg}               	changes between daemonize/not daemonize mode
        #  --help/-h                          	prints help and exits
        #  --log/-l <arg>                     	sets log file name
        #  --port/-p <arg>                    	<port> or <sport>:<eport> sets listening port number or port range
        #  --user/-u <arg>                    	sets user name to make setuid
        #  --verbosity/-v {arg}               	sets or increases verbosity level
        #  --aes-pwd <arg>                    	sets custom secret.conf file
        #  --nice <arg>                       	sets niceness
        #  --msg-buffers-size <arg>           	sets maximal buffers size (default 268435456)
        #  --disable-tcp                      	do not open listening tcp socket
        #  --crc32c                           	Try to use crc32c instead of crc32 in tcp rpc
        #  --cpu-threads <arg>                	Number of CPU threads (1-64, default 8)
        #  --io-threads <arg>                 	Number of I/O threads (1-64, default 16)
        #  --allow-skip-dh                    	Allow skipping DH during RPC handshake
        #  --force-dh                         	Force using DH for all outbound RPC connections
        #  --max-accept-rate <arg>            	max number of connections per second that is allowed to accept
        #  --max-dh-accept-rate <arg>         	max number of DH connections per second that is allowed to accept
        #  --multithread {arg}                	run in multithread mode
        #  --tcp-cpu-threads <arg>            	number of tcp-cpu threads
        #  --tcp-iothreads <arg>              	number of tcp-io threads
        #  --nat-info <arg>                   	<local-addr>:<global-addr>	sets network address translation for RPC protocol handshake
        #  --address <arg>                    	tries to bind socket only to specified address
        #  --http-stats                       	allow http server to answer on stats queries
        args = [
          "mtproto-proxy",
          "--user", "nobody",
          "--max-special-connections", "2000",
          "--http-ports", "443", # mtproxy network port
          "--port", "2398",
          "--slaves", "2",
          "--mtproto-secret", var.mtproxy_secret,
          "--aes-pwd", "/etc/proxy-secret",
          "--cpu-threads", "2",
          "--io-threads", "8",
          "/etc/proxy-multi.conf", # should be last
        ]
      }


      # https://www.nomadproject.io/docs/job-specification/resources
      resources {
        cpu        = 1200 # in MHz
        memory     = 64 # in MB
        memory_max = 256 # in MB
      }

      # https://www.nomadproject.io/docs/job-specification/service
      service {
        name = "mtproxy"
        tags = [
          "telegram", "proxy",

          # Traefik tag examples: https://doc.traefik.io/traefik/routing/providers/consul-catalog/
          "traefik.enable=true",
          "traefik.tcp.routers.mtproxy.entrypoints=https",
          "traefik.tcp.routers.mtproxy.rule=HostSNI(`bla-bla.iddqd.uk`)",
          "traefik.tcp.routers.mtproxy.tls.passthrough=true",
          "traefik.tcp.services.mtproxy.loadbalancer.server.port=${NOMAD_HOST_PORT_mtproxy}",
        ]
      }
    }
  }
}
