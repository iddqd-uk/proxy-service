# Proxy service


[![Tests Status][badge_tests]][link_actions]
[![Deploy Status][badge_deploy]][link_deploy]
![HTTP proxy][status_http_proxy]
![TG proxy][status_tg_proxy]
![DYN proxy][dyn_proxy]

Stack of the services for proxying different kinds (such as `HTTP` and `TCP`) of traffic. Namely:

- Telegram Proxy ([mtg](https://github.com/9seconds/mtg), for the network providers, traffic looks like a regular TLS, so DPI should go fuck off)
- HTTP proxy for the internet surfing ([3proxy](https://github.com/3proxy/3proxy), lightweight and fast)
- Dynamic proxy daemon ([http-proxy-daemon](https://github.com/tarampampam/http-proxy-daemon) for the stories, when the software can't use proxy servers for the simple HTTP requests)

## Links

- [RKN & Telegram Fake TLS](https://habr.com/ru/news/t/469335/)

[badge_tests]:https://img.shields.io/github/workflow/status/iddqd-uk/proxy-service/tests/main?logo=github&logoColor=white&label=tests
[badge_deploy]:https://img.shields.io/github/workflow/status/iddqd-uk/proxy-service/deploy/main?logo=github&logoColor=white&label=deploy
[link_actions]:https://github.com/iddqd-uk/proxy-service/actions
[link_deploy]:https://github.com/iddqd-uk/proxy-service/actions/workflows/deploy.yml

[status_http_proxy]:https://img.shields.io/uptimerobot/ratio/7/m780835931-7fafec18f37e5c0f2af31eba?label=http%20proxy
[status_tg_proxy]:https://img.shields.io/uptimerobot/ratio/7/m783731735-69f67915d9e1c54811db33a4?label=tg%20proxy
[dyn_proxy]:https://img.shields.io/uptimerobot/ratio/7/m785533659-6b8dee8fa9f5100f5a4ad278?label=dyn%20proxy
