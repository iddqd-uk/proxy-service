variable "tg_secret" {
  type        = string
  description = "Generate a new secret: `docker run --rm nineseconds/mtg:2 generate-secret <mtg-subdomain>.iddqd.uk`"
}

variable "tg_subdomain" {
  type        = string
  description = "Telegram subdomain"
}

variable "web_proxy_login" {
  type    = string
  default = "user"
}

variable "web_proxy_password" {
  type    = string
  default = "pass"
}

variable "web_proxy_primary_dns" {
  type    = string
  default = ""
}

variable "web_proxy_secondary_dns" {
  type    = string
  default = ""
}

variable "index_page_image" {
  type        = string
  description = "Full path (ghcr.io/iddqd-uk/proxy-service-index:aabbccd) to the index page image docker image"
}

variable "docker_registry" {
  type        = string
  description = "Containers registry server name"
  default     = "ghcr.io"
}

variable "docker_login" {
  type        = string
  description = "Auth login for reading images on ghcr.io"
  default     = ""
}

variable "docker_password" {
  type        = string
  description = "Auth password/token for reading images on ghcr.io"
  default     = ""
}

locals {
  # renovate: source=github-releases name=9seconds/mtg
  mtg_version = "2.1.7"

  # renovate: source=github-releases name=tarampampam/3proxy-docker
  z3proxy_version = "1.7.0"

  # renovate: source=github-releases name=tarampampam/http-proxy-daemon
  dyn_version = "0.6.0"
}

# https://www.nomadproject.io/docs/job-specification/job
job "proxy-service" {
  type        = "service"
  datacenters = ["primary-dc"]
  namespace   = "apps"
  priority    = 25

  # https://www.nomadproject.io/docs/job-specification/update
  update {
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # https://www.nomadproject.io/docs/job-specification/group
  group "telegram" {
    count = 1

    network {
      port "tg" { to = 443 /* port inside the container */ }
    }

    task "mtg" {
      driver = "docker"

      # https://www.nomadproject.io/docs/job-specification/template
      template {
        data = <<-EOF
        debug = true

        secret = "${ var.tg_secret }"
        bind-to = "0.0.0.0:443"
        concurrency = 256
        prefer-ip = "prefer-ipv4"
        domain-fronting-port = 443
        tolerate-time-skewness = "10s"

        [network]
        doh-ip = "9.9.9.9"

        [network.timeout]
        tcp = "5s"
        http = "10s"
        idle = "1m"

        [defense.anti-replay]
        enabled = true
        max-size = "1mib"
        error-rate = 0.001
        EOF

        destination = "config.toml"
      }

      # https://www.nomadproject.io/docs/drivers/docker
      config {
        image   = "ghcr.io/9seconds/mtg:${ local.mtg_version }"
        ports   = ["tg"]
        volumes = ["config.toml:/etc/config.toml:ro"]
        args    = ["run", "/etc/config.toml"]
      }

      # https://www.nomadproject.io/docs/job-specification/resources
      resources {
        cpu        = 350 # in MHz
        memory     = 64 # in MB
        memory_max = 256 # in MB
      }

      # https://www.nomadproject.io/docs/job-specification/service
      service {
        name = "mtg"
        tags = [
          "telegram", "proxy",

          # Traefik tag examples: https://doc.traefik.io/traefik/routing/providers/consul-catalog/
          "traefik.enable=true",
          "traefik.tcp.routers.mtg.entryPoints=https",
          "traefik.tcp.routers.mtg.rule=HostSNI(`${ var.tg_subdomain }.iddqd.uk`)",
          "traefik.tcp.routers.mtg.tls.passthrough=true",
          "traefik.tcp.services.mtg.loadBalancer.server.port=${NOMAD_HOST_PORT_tg}",
        ]

        check {
          name     = "mtg-tcp-port"
          type     = "tcp"
          port     = "tg"
          interval = "10s"
          timeout  = "1s"
        }
      }
    }
  }

  group "web-proxy" {
    count = 1

    scaling {
      enabled = true
      min     = 0
      max     = 10
    }

    network {
      port "http_proxy" { to = 3128 /* port inside the container */ }
    }

    task "3proxy" {
      driver = "docker"

      # https://www.nomadproject.io/docs/drivers/docker
      config {
        image = "ghcr.io/tarampampam/3proxy:${ local.z3proxy_version }"
        ports = ["http_proxy"]
      }

      env {
        PROXY_LOGIN        = var.web_proxy_login
        PROXY_PASSWORD     = var.web_proxy_password
        PRIMARY_RESOLVER   = var.web_proxy_primary_dns
        SECONDARY_RESOLVER = var.web_proxy_secondary_dns
      }

      # https://www.nomadproject.io/docs/job-specification/resources
      resources {
        cpu        = 150 # in MHz
        memory     = 64 # in MB
        memory_max = 128 # in MB
      }

      # https://www.nomadproject.io/docs/job-specification/service
      service {
        name = "3proxy"
        tags = [
          "http", "proxy",

          # Traefik tag examples: https://doc.traefik.io/traefik/routing/providers/consul-catalog/
          "traefik.enable=true",
          "traefik.tcp.routers.3proxy.entryPoints=http-proxy",
          "traefik.tcp.routers.3proxy.rule=HostSNI(`*`)",
          "traefik.tcp.services.3proxy.loadBalancer.server.port=${NOMAD_HOST_PORT_http_proxy}",
        ]

        check {
          name     = "3proxy-tcp-port"
          type     = "tcp"
          port     = "http_proxy"
          interval = "10s"
          timeout  = "1s"
        }
      }
    }
  }

  group "www" {
    count = 1

    network {
      port "index_http" { to = 8080 /* port inside the container */ }
      port "dyn_http" { to = 8080 /* port inside the container */ }
    }

    task "proxy-index" {
      driver = "docker"

      # https://www.nomadproject.io/docs/drivers/docker
      config {
        image = "${ var.index_page_image }"

        auth {
          server_address = var.docker_registry
          username       = var.docker_login
          password       = var.docker_password
        }

        ports = ["index_http"]
      }

      # https://www.nomadproject.io/docs/job-specification/resources
      resources {
        cpu        = 50 # in MHz
        memory     = 32 # in MB
        memory_max = 64 # in MB
      }

      # https://www.nomadproject.io/docs/job-specification/service
      service {
        name = "proxy-index"
        port = "index_http"
        tags = [
          # Traefik tag examples: https://doc.traefik.io/traefik/routing/providers/consul-catalog/
          "traefik.enable=true",
          "traefik.http.routers.proxy-index.entryPoints=https",
          "traefik.http.routers.proxy-index.rule=Host(`proxy.iddqd.uk`)",
          "traefik.http.routers.proxy-index.tls.certResolver=lets-encrypt",
          "traefik.http.services.proxy-index.loadBalancer.server.port=${NOMAD_HOST_PORT_index_http}",
        ]

        # https://www.nomadproject.io/docs/job-specification/service#check-parameters
        check {
          name     = "http-alive-check"
          type     = "http"
          path     = "/health/live"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }

    task "dyn-http-proxy" {
      driver = "docker"

      # https://www.nomadproject.io/docs/drivers/docker
      config {
        image = "ghcr.io/tarampampam/http-proxy-daemon:${ local.dyn_version }"
        ports = ["dyn_http"]
      }

      env {
        PROXY_PREFIX = "get"
        LISTEN_PORT  = "8080"
      }

      # https://www.nomadproject.io/docs/job-specification/resources
      resources {
        cpu        = 170 # in MHz
        memory     = 16 # in MB
        memory_max = 32 # in MB
      }

      # https://www.nomadproject.io/docs/job-specification/service
      service {
        name = "dyn-http-proxy"
        port = "dyn_http"
        tags = [
          # Traefik tag examples: https://doc.traefik.io/traefik/routing/providers/consul-catalog/
          "traefik.enable=true",
          "traefik.http.routers.dyn-http-proxy.entryPoints=https",
          "traefik.http.routers.dyn-http-proxy.rule=Host(`proxy.iddqd.uk`) && PathPrefix(`/make`)",
          "traefik.http.routers.dyn-http-proxy.tls.certResolver=lets-encrypt",
          "traefik.http.services.dyn-http-proxy.loadBalancer.server.port=${NOMAD_HOST_PORT_dyn_http}",
          "traefik.http.middlewares.dyn-http-proxy-stripprefix.stripprefix.prefixes=/make",
          "traefik.http.middlewares.dyn-http-proxy-ratelimit.ratelimit.average=200",
          "traefik.http.middlewares.dyn-http-proxy-ratelimit.ratelimit.period=1m",
          "traefik.http.routers.dyn-http-proxy.middlewares=dyn-http-proxy-stripprefix,dyn-http-proxy-ratelimit",
        ]

        # https://www.nomadproject.io/docs/job-specification/service#check-parameters
        check {
          name     = "http-alive-check"
          type     = "http"
          path     = "/live"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }
  }
}
