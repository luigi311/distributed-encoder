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
    printf '[%s] Av1an: %s\n' "$(date)" "$1" >> "${LOGFILE}"
}

trap_die() {
    EXIT_CODE="$?"
    if [ "${EXIT_CODE}" -eq 0 ]; then
        log "DONE"
    else
        MESSAGE="ERROR \"${last_command}\" command filed with exit code ${EXIT_CODE}."
        echo "Av1an: ${MESSAGE}"
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
            echo "ERROR: $1 not supported in av1an, use --flag to set av1an flags"
            ERROR=1
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
            echo "ERROR: $1 not supported in av1an, use --flag to set av1an flags"
            ERROR=1
            ;;
        --pass1)
            echo "ERROR: $1 not supported in av1an, use --flag to set av1an flags"
            ERROR=1
            ;;
        --pass2)
            echo "ERROR: $1 not supported in av1an, use --flag to set av1an flags"
            ERROR=1
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

if [ "${ERROR}" -ne -1 ]; then
    die ""
fi

INPUTDIRECTORY=$(dirname "${INPUT}")
BASEFILE=$(basename "${INPUT}" | sed 's/\(.*\)\..*/\1/')
LOGFILE="${INPUTDIRECTORY}/${BASEFILE}.log"

FULLOUTPUT="${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mkv"
INPUTENCODE="${INPUTDIRECTORY}/de_prepared_${BASEFILE}.mkv"
TEMP="${INPUTDIRECTORY}/.av1an-$(md5sum "${INPUT}")"
COMMAND="av1an"

if [ -n "${DOCKER+x}" ]; then
    DOCKERRUN="docker run -v ${INPUTDIRECTORY}:/videos -w /videos --user $(id -u):$(id -g) -i --rm ${ENCODERIMAGE}"
    DOCKERPROBE="docker run -v ${INPUTDIRECTORY}:/videos -w /videos --user $(id -u):$(id -g) -i --rm ${FFMPEGIMAGE}"
    INPUTENCODE="/videos/de_prepared_${BASEFILE}.mkv"
    FULLOUTPUT="/videos/de_encoded_${BASEFILE}.mkv"
    TEMP="/videos/.av1an-$(md5sum "${INPUT}" | awk '{ print $1 }')"
    COMMAND=""
fi

BASE="${DOCKERRUN} ${COMMAND} -i \"${INPUTENCODE}\" -o \"${FULLOUTPUT}\" --temp \"${TEMP}\" --keep ${FLAG}"
log "${BASE}"
eval "${BASE}"
log "Encoding DONE"

log "Validating encode"
FFPROBE="${DOCKERPROBE} ffprobe -hide_banner -loglevel error -i \"${FULLOUTPUT}\" 2>&1"
log "${FFPROBE}}"
ERROR=$(eval "${FFPROBE}")
if [ -n "$ERROR" ]; then
    #rm -rf "${INPUTDIRECTORY}/${OUTPUTBASE:?}*"
    die "${INPUT} failed"
fi
log "Validating DONE"
