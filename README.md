<p align="center">
  <a href="https://t.me/twitchviewer_bot">
    <img src="https://helltar.com/projects/twitchviewer-bot/img/t-me-qr-code-1.png" alt="Telegram bot QR code" width="35%"/>
  </a>
</p>

## Installation

### Docker Compose

Download the configuration files:

```bash
mkdir twitchbot && cd twitchbot && curl -fsSLO \
  "https://github.com/Helltar/twitchviewer-bot/raw/master/{compose.yaml,.env.example}" && \
  mv .env.example .env
```

Edit `.env` and fill in your values (and keep it private: `chmod 600 .env`):

- `CREATOR_ID`: your Telegram user ID
- `BOT_TOKEN`: Telegram bot token ([BotFather](https://t.me/BotFather))
- `BOT_USERNAME`: Telegram bot username ([BotFather](https://t.me/BotFather))
- `TWITCH_CLIENT_ID`: Twitch app client ID ([Twitch Developer Console](https://dev.twitch.tv/console/apps))
- `TWITCH_CLIENT_SECRET`: Twitch app client secret ([Twitch Developer Console](https://dev.twitch.tv/console/apps))
- optional `MAX_CONCURRENT_CLIPS`: max clips recorded at once across all users (default 6, extra requests are queued)
- optional `BOT_MEM_LIMIT` / `BOT_TMP_SIZE` / `BOT_CPUS`: container limits, see `compose.yaml`

Start the bot:

```bash
docker compose up -d
```

> **Note:**
> Data is stored in a single SQLite file on the `bot-data` volume (`/data/twitchbot.db`), no external database needed.
> Backup: `docker run --rm -v twitchbot_bot-data:/data -v "$PWD":/b alpine cp /data/twitchbot.db /b/` (stop the bot first,
> or copy the `-wal` file too).

## Commands

**`/clip`** - record clips

- `/clip` - from all tracked channels
- `/clip <channel>` - from a specific channel (even if it isn't in your list)
- `/clip <prefix>.` - only from tracked channels whose name starts with `<prefix>`, e.g. `/clip em.`
- `/clip !<prefix>.` - from all tracked channels **except** those starting with `<prefix>`, e.g. `/clip !em.`

**`/screenshot`** - capture screenshots

- `/screenshot` - from all tracked channels
- `/screenshot <channel>` - from a specific channel

**Other**

- `/add` - Add channel to favorites
- `/list` - Show your favorite channels
- `/cancel` - Cancel your active background tasks

## Notes

- The bot requires `ffmpeg` and `streamlink` (already included in the provided Docker image).
- The image ships an `ffmpeg` shim (`docker/ffmpeg-clip-wrapper.sh`) that starts each clip on the first video
  keyframe, so Telegram shows a preview instead of a black square. Disable with `CLIP_PREVIEW_FIX=0`.
- The container runs as a non-root user with a read-only root filesystem, no capabilities and `/tmp` on tmpfs.
