# NewjeansOnce

Fan Wall — a real-time message board built with Phoenix LiveView, Neo-Brutalism UI, and Phoenix Presence.

---

## Local development

```bash
# Install dependencies and set up the database
mix setup

# Start the dev server (hot reload enabled)
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000).

---

## Docker

### Build

```bash
docker build -t newjeans_once .
```

Build with a specific version (shows in the navbar):

```bash
docker build --build-arg APP_VERSION=1.2.3 -t newjeans_once:1.2.3 .
```

### Run

```bash
docker run -p 4000:80 newjeans_once
```

Visit [http://localhost:4000](http://localhost:4000).

Run with a persistent database (survives container restarts):

```bash
docker run -p 4000:80 \
  -v $(pwd)/storage:/storage \
  newjeans_once
```

Run in the background:

```bash
docker run -d -p 4000:80 \
  -v $(pwd)/storage:/storage \
  --name fanwall \
  newjeans_once
```

Stop and remove:

```bash
docker stop fanwall && docker rm fanwall
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `80` | HTTP port the server listens on |
| `DATABASE_PATH` | `/storage/newjeans_once.db` | SQLite database file path |
| `PHX_SERVER` | `true` | Start the HTTP server on boot |
| `SECRET_KEY_BASE` | — | Required in production (64+ byte secret) |

Example with a custom port and secret:

```bash
docker run -p 8080:8080 \
  -e PORT=8080 \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  -v $(pwd)/storage:/storage \
  newjeans_once:1.2.3
```

### Build-time arguments

| Argument | Default | Description |
|---|---|---|
| `APP_VERSION` | `0.1.0` | Version string shown in the navbar |
| `ELIXIR_VERSION` | `1.19.5` | Elixir version used for the build |
| `OTP_VERSION` | `28.5` | Erlang/OTP version used for the build |
