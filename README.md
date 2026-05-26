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

---

## Version display

The navbar shows the app version (e.g. `v1.2.3`). It reads from `Application.spec(:newjeans_once, :vsn)` which is baked into the compiled `.app` file at build time — it always reflects the version of the code that is actually running.

### How it works

`mix.exs` reads the version from the `APP_VERSION` environment variable at compile time:

```elixir
version: System.get_env("APP_VERSION", "0.1.0")
```

The value is stamped into the compiled release. At runtime the navbar reads it from the compiled artifact, not from any env var — so the version shown is always truthful.

### In development

The version is compiled into the app on `mix compile`. Changing `APP_VERSION` at runtime has no effect because the compiled `.app` file is not regenerated unless you force a recompile.

In development you will always see `v0.1.0` (the default in `mix.exs`). This is intentional — version display is a deployment concern, not a development one.

If you need to verify a specific version locally:

```bash
APP_VERSION=2.0.0 mix compile --force && mix phx.server
```

### In Docker

`--build-arg APP_VERSION=...` sets the env var before `mix compile` runs inside the builder stage, so the version is correctly stamped into the release:

```bash
docker build --build-arg APP_VERSION=1.2.3 -t newjeans_once:1.2.3 .
```

The running container does not need `APP_VERSION` set — the version is already baked in.
