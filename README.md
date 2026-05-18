# X-Forwarded-For nginx chain lab

Тестовый стенд для задания на позицию DevOps.

В составе стенда:

- `nginx1`, `nginx2`, `nginx3` в режиме reverse proxy;
- простое HTTP-приложение на Python, которое выводит полученный `X-Forwarded-For`;
- статическая docker-сеть, чтобы nginx могли доверять только IP друг друга;
- curl-протокол для проверки прямых и цепочечных запросов.

## Идея решения

Каждый nginx формирует `X-Forwarded-For` сам:

- если запрос пришел не от доверенного nginx, входящий `X-Forwarded-For` сбрасывается;
- если запрос пришел от доверенного nginx, текущая цепочка сохраняется;
- текущий nginx добавляет в конец цепочки свой IP.

Доверенными считаются только контейнеры nginx:

- `nginx1`: `172.31.240.11`;
- `nginx2`: `172.31.240.12`;
- `nginx3`: `172.31.240.13`.

В результате приложение получает в `X-Forwarded-For` IP пользователя и все nginx, через которые прошел запрос. В локальном Docker-стенде IP пользователя отображается как адрес Docker gateway. На Docker Desktop это часто `192.168.65.1`, на Linux с bridge-сетью это может быть `172.31.240.1`.

## Запуск

```bash
docker compose up --build -d
```

Порты:

- `http://localhost:8081` -> `nginx1`;
- `http://localhost:8082` -> `nginx2`;
- `http://localhost:8083` -> `nginx3`.

## Протокол тестирования curl

### 1. Запрос через один nginx

```bash
curl -s http://localhost:8081/app
```

Ожидаемый `x_forwarded_for`:

```text
<client-ip>, 172.31.240.11
```

Проверка остальных входных nginx:

```bash
curl -s http://localhost:8082/app
curl -s http://localhost:8083/app
```

Ожидаемо:

```text
<client-ip>, 172.31.240.12
<client-ip>, 172.31.240.13
```

### 2. Запрос по цепочке nginx1 -> nginx2 -> nginx3 -> приложение

```bash
curl -s http://localhost:8081/via/nginx2/via/nginx3/app
```

Ожидаемый `x_forwarded_for`:

```text
<client-ip>, 172.31.240.11, 172.31.240.12, 172.31.240.13
```

### 3. Запрос по цепочке nginx2 -> nginx3 -> приложение

```bash
curl -s http://localhost:8082/via/nginx3/app
```

Ожидаемый `x_forwarded_for`:

```text
<client-ip>, 172.31.240.12, 172.31.240.13
```

### 4. Пользователь подставляет ложный X-Forwarded-For

```bash
curl -s \
  -H 'X-Forwarded-For: 1.2.3.4, 5.6.7.8' \
  http://localhost:8081/via/nginx2/via/nginx3/app
```

Ожидаемый результат: адреса `1.2.3.4` и `5.6.7.8` отсутствуют, потому что первый nginx сбрасывает пользовательский `X-Forwarded-For`.

Ожидаемый `x_forwarded_for`:

```text
<client-ip>, 172.31.240.11, 172.31.240.12, 172.31.240.13
```

### 5. Автоматический прогон всех curl-проверок

```bash
sh scripts/curl-protocol.sh
```

## Остановка стенда

```bash
docker compose down
```

## Затраченное время

Ориентировочно: 1.5-2 часа чистого времени.
