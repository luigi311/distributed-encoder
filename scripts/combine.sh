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
BASE1FILE=$(basename "${INPUT1}" | sed 's/\(.*\)\..*/\1/')

INPUT2DIRECTORY=$(dirname "$INPUT2")
INPUT2FILE=$(basename "${INPUT2}")
BASE2FILE=$(basename "${INPUT2}" | sed 's/\(.*\)\..*/\1/')

FULLOUTPUT="${INPUT1DIRECTORY%/}/de_final_${BASE2FILE}.mkv"
COMMAND="ffmpeg"

IFS=',' read -r -a AUDIOSTREAMS <<< "$AUDIOSTREAMS"
AUDIOMAP=""
for STREAM in "${AUDIOSTREAMS[@]}"
do
    AUDIOMAP="${AUDIOMAP} -map 1:a:${STREAM}?"
done

FLAG=" -y -hide_banner -loglevel error -map 0:v:0 ${AUDIOMAP} -map 1:s? -map 1:d? -map 1:t? -max_interleave_delta 0 -c copy ${AUDIOFLAGS}"

if [ -n "${DOCKER+x}" ]; then
    DOCKERRUN="docker run -v ${INPUT1DIRECTORY%/}:/videos/input1 -v ${INPUT2DIRECTORY%/}:/videos/input2  -w /videos --user $(id -u):$(id -g) -i --rm ${FFMPEGIMAGE}"
    DOCKERPROBE="docker run -v ${INPUT1DIRECTORY%/}:/videos/input1 -w /videos/input1 --user $(id -u):$(id -g) -i --rm ${FFMPEGIMAGE}"
    INPUT1="/videos/input1/${INPUT1FILE}"
    INPUT2="/videos/input2/${INPUT2FILE}"
    FULLOUTPUT="/videos/input1/de_final_${BASE2FILE}.mkv"
fi

BASE="${DOCKERRUN} ${COMMAND} -i ${INPUT1} -i ${INPUT2} ${FLAG} ${FULLOUTPUT}"
eval "${BASE}"

FFPROBE="${DOCKERPROBE} ffprobe -hide_banner -loglevel error -i ${FULLOUTPUT} 2>&1"
ERROR=$(eval "${FFPROBE}")
if [ -n "$ERROR" ]; then
    #rm -rf "${INPUTDIRECTORY}/${OUTPUTBASE:?}*"
    echo "$ERROR"
    die "${INPUT} failed"
fi
