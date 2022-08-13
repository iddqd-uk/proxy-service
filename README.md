# Proxy service


[![Tests Status][badge_tests]][link_actions]
[![Deploy Status][badge_deploy]][link_deploy]

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
