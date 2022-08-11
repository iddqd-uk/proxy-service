variable "tg_secret" {
  type        = string
  description = "Generate a new secret: `docker run --rm nineseconds/mtg:2 generate-secret example.iddqd.uk`"
  default     = "7pX02uliNE9fu23IlUbTFYNwcm94eS5pZGRxZC51aw"
}

variable "tg_domain" {
  type = string
}

locals {
  # renovate: source=github-releases name=9seconds/mtg
  mtg_version = "2.1.6"
}

# https://www.nomadproject.io/docs/job-specification/job
job "proxy-service" {
  type        = "service"
  datacenters = ["primary-dc"]
  namespace   = "apps"
  priority    = 25

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
        cpu        = 450 # in MHz
        memory     = 128 # in MB
        memory_max = 256 # in MB
      }

      # https://www.nomadproject.io/docs/job-specification/service
      service {
        name = "mtg"
        tags = [
          "telegram", "proxy",

          # Traefik tag examples: https://doc.traefik.io/traefik/routing/providers/consul-catalog/
          "traefik.enable=true",
          "traefik.tcp.routers.mtg.entrypoints=https",
          "traefik.tcp.routers.mtg.rule=HostSNI(`${ var.tg_domain }.iddqd.uk`)",
          "traefik.tcp.routers.mtg.tls.passthrough=true",
          "traefik.tcp.services.mtg.loadbalancer.server.port=${NOMAD_HOST_PORT_tg}",
        ]
      }
    }
  }
}
