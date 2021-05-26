#!/usr/bin/env bash

# Source: http://mywiki.wooledge.org/BashFAQ/035
die() {
    printf '%s\n' "$1" >&2
    exit 1
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

OUTPUT="$(pwd)/output"
ERROR=-1
FFMPEGIMAGE="luigi311/encoders-docker:latest"

# Source: http://mywiki.wooledge.org/BashFAQ/035
while :; do
    case "$1" in
        -h | -\? | --help)
            help
            exit 0
            ;;
        -i | --input)
            if [ "$2" ]; then
                INPUT="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --ffmpegimage)
            if [ "$2" ]; then
                FFMPEGIMAGE="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --docker)
            DOCKER=1
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

if [ -z "${INPUT+x}" ]; then
    die "Input not set"
fi

if [ "${ERROR}" -ne -1 ]; then
    die ""
fi


INPUTDIRECTORY=$(dirname "$INPUT")
INPUTFILE=$(basename "${INPUT}")
BASEFILE=$(basename "${INPUT}" | sed 's/\(.*\)\..*/\1/')

FULLOUTPUT="${INPUTDIRECTORY}/de_prepared_${BASEFILE}.mkv"
COMMAND="ffmpeg"
FLAG=" -hide_banner -loglevel error -y -map 0:v:0 -c:v libx264 -crf 0 -preset ultrafast"

if [ -n "${DOCKER+x}" ]; then
    DOCKERRUN="docker run -v ${INPUTDIRECTORY%/}:/videos -w /videos --user $(id -u):$(id -g) -i --rm ${FFMPEGIMAGE}"
    INPUT="/videos/${INPUTFILE}"
    FULLOUTPUT="/videos/de_prepared_${BASEFILE}.mkv"
fi

BASE="${DOCKERRUN} ${COMMAND} -i \"${INPUT}\" ${FLAG} \"${FULLOUTPUT}\""
eval "${BASE}"

FFPROBE="${DOCKERRUN} ffprobe -hide_banner -loglevel error -i \"${FULLOUTPUT}\" 2>&1"
ERROR=$(eval "${FFPROBE}")
if [ -n "$ERROR" ]; then
    #rm -rf "${INPUTDIRECTORY}/${OUTPUTBASE:?}*"
    echo "$ERROR"
    die "${INPUT} failed"
fi
