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
    printf '[%s] X265: %s\n' "$(date)" "$1" >> "${LOGFILE}"
}

trap_die() {
    EXIT_CODE="$?"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        log "DONE"
    else
        MESSAGE="ERROR \"${last_command}\" command filed with exit code ${EXIT_CODE}."
        echo "X265: ${MESSAGE}"
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

THREADS=-1
TWOPASS=-1
ERROR=-1
ENCODERIMAGE="masterofzen/av1an:master"
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
        -t | --threads)
            if [ "$2" ]; then
                THREADS="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        -f | --flag)
            if [ "$2" ]; then
                FLAG="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --twopass)
            TWOPASS=1
            ;;
        --pass1)
            if [ "$2" ]; then
                PASS1="$2"
                TWOPASS=1
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --pass2)
            if [ "$2" ]; then
                PASS2="$2"
                TWOPASS=1
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --docker)
            DOCKER=1
            ;;
        --encoderimage)
            if [ "$2" ]; then
                ENCODERIMAGE="$2"
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

if [ "$THREADS" -eq -1 ]; then
    THREADS="$(nproc)" 
fi

if [ "${TWOPASS}" -eq 1 ] && [ -n "${FLAG+x}" ]; then
    if [ -z "${PASS1+x}" ]; then
        PASS1="${FLAG}"
    fi
    if [ -z "${PASS2+x}" ]; then
        PASS2="${FLAG}"
    fi
fi

INPUTDIRECTORY=$(dirname "$INPUT")
BASEFILE=$(basename "${INPUT}" | sed 's/\(.*\)\..*/\1/')
LOGFILE="${INPUTDIRECTORY}/${BASEFILE}.log"

INPUTENCODE="${INPUTDIRECTORY}/de_prepared_${BASEFILE}.mkv"
FULLOUTPUT="${INPUTDIRECTORY}/de_encoded_${BASEFILE}"

if [ -n "${DOCKER+x}" ]; then
    DOCKERRUN="docker run --privileged -v ${INPUTDIRECTORY}:/videos -w /videos --user $(id -u):$(id -g) -i --rm ${ENCODERIMAGE}"
    DOCKERPROBE="docker run --privileged -v ${INPUTDIRECTORY}:/videos -w /videos --user $(id -u):$(id -g) -i --rm ${FFMPEGIMAGE}"
    INPUTENCODE="/videos/de_prepared_${BASEFILE}.mkv"
    FULLOUTPUT="/videos/de_encoded_${BASEFILE}"
fi

log "Encoding"
BASE="${DOCKERRUN} /bin/bash -c \"ffmpeg -y -hide_banner -loglevel error -i \"${INPUTENCODE}\" -strict -1 -pix_fmt yuv420p10le -f yuv4mpegpipe - | x265 --log-level error --input - --y4m --pools ${THREADS} ${FLAG}"
if [ "${TWOPASS}" -eq -1 ]; then
    log "${BASE} -o ${FULLOUTPUT}.h265\""
    eval "${BASE} -o ${FULLOUTPUT}.h265\""
else
    log "${BASE} --pass 1 --stats \"${FULLOUTPUT}.log\" -o /dev/null ${PASS1}\"" &&
    eval "${BASE} --pass 1 --stats \"${FULLOUTPUT}.log\" -o /dev/null ${PASS1}\"" &&
    log "${BASE} --pass 2 --stats \"${FULLOUTPUT}.log\" -o \"${FULLOUTPUT}.h265\" ${PASS2}\""
    eval "${BASE} --pass 2 --stats \"${FULLOUTPUT}.log\" -o \"${FULLOUTPUT}.h265\" ${PASS2}\""
fi
log "Encoding DONE"

log "Validating encode"
FFPROBE="${DOCKERPROBE} ffmpeg -y -hide_banner -loglevel error -i \"${FULLOUTPUT}.h265\" -c copy \"${FULLOUTPUT}.mp4\" 2>&1"
log "${FFPROBE}"
ERROR=$(eval "${FFPROBE}")
if [ -n "$ERROR" ]; then
    rm -f "${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mp4"
    die "${INPUT} failed ${ERROR}"
fi
log "Validating DONE"

log "Cleanup"
rm -f "${INPUTDIRECTORY}/de_encoded_${BASEFILE}.log"
rm -f "${INPUTDIRECTORY}/de_encoded_${BASEFILE}.log.cutree"
rm -f "${INPUTDIRECTORY}/de_encoded_${BASEFILE}.h265"
log "Cleanup DONE"
