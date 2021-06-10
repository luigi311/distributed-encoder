#!/usr/bin/env bash

# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'trap_die' EXIT

# Source: http://mywiki.wooledge.org/BashFAQ/035
die() {
    printf '%s\n' "$1" >&2
    exit 1
}

log() {
    printf '[%s] Combine: %s\n' "$(date)" "$1" >> "${LOGFILE}"
}

trap_die() {
    EXIT_CODE="$?"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        log "DONE"
    else
        MESSAGE="ERROR \"${last_command}\" command filed with exit code ${EXIT_CODE}."
        echo "Combine: ${MESSAGE}"
        log "${MESSAGE}"
    fi
}

help() {
    help="$(cat <<EOF

Usage:
    ./encoder.sh [options]
Example:
    ./encoder.sh -i video.mkv -f "--kf-max-dist=360 --enable-keyframe-filtering=0" -t 8 --q --quality 30
Encoding Options:
    -i/--input   [file]     Video source to use                                                 (default video.mkv)
    -o/--output  [folder]   Output folder to place encoded videos and stats files               (default output)
    -f/--flag    [string]   Flag to test, surround in quotes to prevent issues                  (default baseline)
    -t/--threads [number]   Amount of threads to use                                            (default 4)
    --quality    [number]   Bitrate for vbr, cq-level for q/cq mode, crf                        (default 50)
    --preset     [number]   Set encoding preset, aomenc higher is faster, x265 lower is faster  (default 6)
    --pass       [number]   Set amount of passes                                                (default 1)
    --vbr                   Use vbr mode (applies to aomenc/x265 only)
    --crf                   Use crf mode (applies to x265 only)                                 (default)
EOF
            )"
            echo "$help"
}

FFMPEGIMAGE="luigi311/encoders-docker:latest"
AUDIOFLAGS="-c:a flac"
AUDIOSTREAMS="0"

# Source: http://mywiki.wooledge.org/BashFAQ/035
while :; do
    case "$1" in
        -h | -\? | --help)
            help
            exit 0
            ;;
        --input1)
            if [ "$2" ]; then
                INPUT1="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --input2)
            if [ "$2" ]; then
                INPUT2="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --audioflags)
            if [ "$2" ]; then
                AUDIOFLAGS="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --audiostreams)
            if [ "$2" ]; then
                AUDIOSTREAMS="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --docker)
            DOCKER=1
            ;;
        --ffmpegimage)
            if [ "$2" ]; then
                FFMPEGIMAGE="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --) # End of all options.
            shift
            break
            ;;
        -?*)
            echo "Unknown option: $1 ignored"
            ;;
        *) # Default case: No more options, so break out of the loop.
            break ;;
    esac
    shift
done

if [ -z "${INPUT1+x}" ]; then
    die "Input1 not set"
fi
if [ -z "${INPUT2+x}" ]; then
    die "Input2 not set"
fi

INPUT1DIRECTORY=$(dirname "$INPUT1")
INPUT1FILE=$(basename "${INPUT1}")

INPUT2DIRECTORY=$(dirname "$INPUT2")
INPUT2FILE=$(basename "${INPUT2}")
BASE2FILE=$(basename "${INPUT2}" | sed 's/\(.*\)\..*/\1/')

LOGFILE="${INPUT2DIRECTORY}/${BASE2FILE}.log"

IFS=',' read -r -a AUDIOSTREAMS <<< "$AUDIOSTREAMS"
AUDIOMAP=""
for STREAM in "${AUDIOSTREAMS[@]}"
do
    AUDIOMAP="${AUDIOMAP} -map 1:a:${STREAM}?"
done

FULLOUTPUT="${INPUT1DIRECTORY%/}/de_final_${BASE2FILE}"
FLAG=" -y -hide_banner -loglevel error ${AUDIOMAP} -map 1:s? -map 1:d? -map 1:t? -max_interleave_delta 0 -c copy ${AUDIOFLAGS}"

if [ -n "${DOCKER+x}" ]; then
    DOCKERRUN="docker run -v ${INPUT1DIRECTORY%/}:/videos/input1 -v ${INPUT2DIRECTORY%/}:/videos/input2  -w /videos --user $(id -u):$(id -g) -i --rm ${FFMPEGIMAGE}"
    DOCKERPROBE="docker run -v ${INPUT1DIRECTORY%/}:/videos/input1 -w /videos/input1 --user $(id -u):$(id -g) -i --rm ${FFMPEGIMAGE}"
    INPUT1="/videos/input1/${INPUT1FILE}"
    INPUT2="/videos/input2/${INPUT2FILE}"
    FULLOUTPUT="/videos/input1/de_final_${BASE2FILE}"
fi

log "Encoding Audio"
BASE="${DOCKERRUN} ffmpeg -i \"${INPUT1}\" -i \"${INPUT2}\" ${FLAG} \"${FULLOUTPUT}.mka\""
log "${BASE}"
eval "${BASE}"
log "Encoding Audio DONE"

log "Combining"
BASE="${DOCKERRUN} mkvmerge -o \"${FULLOUTPUT}.mkv\" --quiet -A \"${INPUT1}\" \"${FULLOUTPUT}.mka\""
log "${BASE}"
eval "${BASE}"
log "Combining DONE"

log "Validating"
FFPROBE="${DOCKERPROBE} ffmpeg -v error -i \"${FULLOUTPUT}.mkv\" -f null - 2>&1"
log "${FFPROBE}"
ERROR=$(eval "${FFPROBE}")
if [ -n "$ERROR" ]; then
    #rm -rf "${INPUTDIRECTORY}/${OUTPUTBASE:?}*"
    echo "$ERROR"
    die "${INPUT} failed"
fi
log "Validating DONE"
