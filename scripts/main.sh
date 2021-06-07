#!/usr/bin/env bash

# Source: https://intoli.com/blog/exit-on-errors-in-bash-scripts/
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
    printf '[%s] Main: %s\n' "$(date)" "$1" >> "${LOGFILE}"
}

trap_die() {
    EXIT_CODE="$?"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        log "DONE"
    else
        MESSAGE="ERROR \"${last_command}\" command filed with exit code ${EXIT_CODE}."
        echo "Main: ${MESSAGE}"
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

OUTPUT="$(pwd)/output"
ENCODERIMAGE="masterofzen/av1an:master"
FFMPEGIMAGE="luigi311/encoders-docker:latest"
AUDIOFLAGS="-c:a flac"
AUDIOSTREAMS="0"
ENCODER="av1an"

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
                THREADS="--threads $2"
                shift
            else
                die "ERROR: $1 requires a non-empty option argument."
            fi
            ;;
        -f | --flag)
            if [ "$2" ]; then
                FLAG="--flag \"$2\""
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --twopass)
            TWOPASS="--twopass"
            ;;
        --pass1)
            if [ "$2" ]; then
                PASS1="--pass1 \"$2\""
                TWOPASS="--twopass"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --pass2)
            if [ "$2" ]; then
                PASS2="--pass2 \"$2\""
                TWOPASS="--twopass"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --docker)
            DOCKER=1
            DOCKERFLAG="--docker"
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
        --encoder)
            if [ "$2" ]; then
                ENCODER="$2"
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

INPUTDIRECTORY=$(dirname "${INPUT}")
INPUTFILE=$(basename "${INPUT}")
BASEFILE=$(basename "${INPUT}" | sed 's/\(.*\)\..*/\1/')
LOGFILE="${INPUTDIRECTORY}/${BASEFILE}.log"
TEMP="${INPUTDIRECTORY}/.av1an-$(md5sum ${INPUT} | awk '{ print $1 }')"

# Prepare videos to ensure consistent encoding
echo "${HOSTNAME}: Working on ${INPUTFILE}" > "${LOGFILE}"
log "Preparing"
PREPARE="scripts/prepare.sh --input \"${INPUT}\" ${DOCKERFLAG} --ffmpegimage \"${FFMPEGIMAGE}\""
log "${PREPARE}"
eval "${PREPARE}"
log "Preparing DONE"

# Encode
log "Runing Encoder"
ENCODE="scripts/${ENCODER}.sh --input \"${INPUT}\" ${THREADS} ${ENCODING} ${FLAG} ${TWOPASS} ${PASS1} ${PASS2} ${DOCKERFLAG} --encoderimage \"${ENCODERIMAGE}\" --ffmpegimage \"${FFMPEGIMAGE}\""
log "${ENCODE}"
eval "${ENCODE}"
log "Encoding DONE"

# Combine encoded video with audio
log "Combine"
COMBINE="scripts/combine.sh --input1 \"${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mkv\" --input2 \"${INPUT}\" --audioflags \"${AUDIOFLAGS}\" --audiostreams \"${AUDIOSTREAMS}\" --ffmpegimage \"${FFMPEGIMAGE}\" ${DOCKERFLAG}"
log "${COMBINE}"
eval "${COMBINE}"
log "Combine DONE"

# Cleanup
log "Cleanup"
log "Deleting: ${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mp4"
rm -f "${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mp4"

log "Deleting: ${INPUTDIRECTORY}/de_prepared_${BASEFILE}.mkv"
rm -f "${INPUTDIRECTORY}/de_prepared_${BASEFILE}.mkv"

log "Deleting: ${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mkv"
rm -f "${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mkv"

log "Deleting: ${TEMP:?}"
rm -rf "${TEMP:?}"
log "Cleanup DONE"
