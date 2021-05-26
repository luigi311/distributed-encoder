#!/usr/bin/env bash

# Source: http://mywiki.wooledge.org/BashFAQ/035
die() {
    printf '%s\n' "$1" >&2
    exit 1
}

log() {
    printf '[%s] %s\n' "$(date)" "$1" >> "${LOGFILE}"
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
ENCODERIMAGE="masterofzen/av1an:master"
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
INPUTFILE=$(basename "${INPUT}")
BASEFILE=$(basename "${INPUT}" | sed 's/\(.*\)\..*/\1/')
LOGFILE="${INPUTDIRECTORY}/${BASEFILE}.log"
# Run prepared first
echo "Working on ${INPUTFILE}" > "${LOGFILE}"
log "Preparing"
scripts/prepare.sh --input "${INPUT}" "${DOCKERFLAG}" --ffmpegimage "${FFMPEGIMAGE}"
log "Preparing DONE"

FULLOUTPUT="${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mkv"
INPUTENCODE="${INPUTDIRECTORY}/de_prepared_${BASEFILE}.mkv"
COMMAND="av1an"

if [ -n "${DOCKER+x}" ]; then
    DOCKERRUN="docker run -v ${INPUTDIRECTORY}:/videos -w /videos --user $(id -u):$(id -g) -i --rm ${ENCODERIMAGE}"
    DOCKERPROBE="docker run -v ${INPUTDIRECTORY}:/videos -w /videos --user $(id -u):$(id -g) -i --rm ${FFMPEGIMAGE}"
    INPUTENCODE="/videos/de_prepared_${BASEFILE}.mkv"
    FULLOUTPUT="/videos/de_encoded_${BASEFILE}.mkv"
    COMMAND=""
fi

BASE="${DOCKERRUN} ${COMMAND} -i \"${INPUTENCODE}\" --output_file \"${FULLOUTPUT}\" ${FLAG}"
log "Encoding"
eval "${BASE}"
log "Encoding DONE"

log "Validating encode"
FFPROBE="${DOCKERPROBE} ffprobe -hide_banner -loglevel error -i \"${FULLOUTPUT}\" 2>&1"
ERROR=$(eval "${FFPROBE}")
if [ -n "$ERROR" ]; then
    #rm -rf "${INPUTDIRECTORY}/${OUTPUTBASE:?}*"
    die "${INPUT} failed"
fi
log "Validating DONE"

log "Combine"
scripts/combine.sh --input1 "${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mkv" --input2 "${INPUT}" --audioflags "${AUDIOFLAGS}" --audiostreams "${AUDIOSTREAMS}" "${DOCKERFLAG}" --ffmpegimage "${FFMPEGIMAGE}"
log "Combine DONE"

log "Cleanup"
rm -f "${INPUTDIRECTORY}/de_prepared_${BASEFILE}.mkv"
rm -f "${INPUTDIRECTORY}/de_encoded_${BASEFILE}.mkv"
log "Cleanuo DONE"
