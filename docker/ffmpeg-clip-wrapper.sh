#!/bin/sh
# ffmpeg shim, installed as /usr/local/bin/ffmpeg (ahead of /usr/bin in PATH).
#
# Why: the bot remuxes streamlink's MPEG-TS into MP4 with "-c copy". A live
# recording usually starts with audio slightly ahead of the first video
# keyframe (and sometimes with undecodable non-key frames). The resulting MP4
# then has an empty edit / gap at the start of the video track, so Telegram's
# server-side thumbnailer grabs "nothing" at t=0 and the client shows a black
# square until the video is downloaded.
#
# What: ONLY for the exact clip-remux call made by ClipProcesses.ffmpegPrepareClip
#   ffmpeg -i IN.ts -t N -c copy -movflags +faststart -loglevel quiet OUT.mp4
# it seeks to the first video keyframe, so both tracks start at 0 with a
# decodable IDR frame. Every other invocation is passed through untouched.
# Still stream copy: no re-encode, CPU cost is one extra ffprobe pass.
#
# Disable with CLIP_PREVIEW_FIX=0 in .env.

set -eu

REAL_FFMPEG=/usr/bin/ffmpeg
REAL_FFPROBE=/usr/bin/ffprobe

passthrough() { exec "$REAL_FFMPEG" "$@"; }

[ "${CLIP_PREVIEW_FIX:-1}" = "1" ] || passthrough "$@"

# strict match of the bot's remux call; anything else goes straight to ffmpeg
if [ "$#" -ne 11 ] || [ "$1" != "-i" ] || [ "$3" != "-t" ] || [ "$5" != "-c" ] ||
   [ "$6" != "copy" ] || [ "$7" != "-movflags" ] || [ "$9" != "-loglevel" ]; then
    passthrough "$@"
fi

IN=$2
DUR=$4
MOVFLAGS=$8
LOGLEVEL=${10}
OUT=${11}

case "$IN"  in *.ts)  ;; *) passthrough "$@" ;; esac
case "$OUT" in *.mp4) ;; *) passthrough "$@" ;; esac
case "$DUR" in ''|*[!0-9]*) passthrough "$@" ;; esac
[ -f "$IN" ] || passthrough "$@"

# input start (earliest stream, usually audio) and first video keyframe, in seconds
START=$("$REAL_FFPROBE" -v error -show_entries format=start_time -of csv=p=0 -- "$IN" 2>/dev/null || true)
KEYFRAME=$("$REAL_FFPROBE" -v error -select_streams v:0 -read_intervals '%+#900' \
    -show_entries packet=pts_time,flags -of csv=p=0 -- "$IN" 2>/dev/null |
    awk -F, '$1 != "N/A" && $2 ~ /K/ { print $1; exit }' || true)

# no video / unparsable timestamps -> behave exactly like before
case "$START"    in ''|N/A) passthrough "$@" ;; esac
case "$KEYFRAME" in ''|N/A) passthrough "$@" ;; esac

# +1 ms so seeking lands on this keyframe, never on the junk before it
OFFSET=$(awk -v k="$KEYFRAME" -v s="$START" 'BEGIN { o = k - s + 0.001; if (o < 0) o = 0; printf "%.3f", o }')

exec "$REAL_FFMPEG" -nostdin -n \
    -ss "$OFFSET" -i "$IN" \
    -t "$DUR" \
    -map 0:v:0 -map '0:a:0?' \
    -c copy \
    -avoid_negative_ts make_zero \
    -movflags "$MOVFLAGS" \
    -loglevel "$LOGLEVEL" \
    "$OUT"
