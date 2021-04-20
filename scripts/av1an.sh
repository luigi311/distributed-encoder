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
INPUT="video.mkv"
ERROR=-1
DOCKERIMAGE="masterofzen/av1an:master"

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
        -o | --output)
            if [ "$2" ]; then
                OUTPUT="$2"
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
        --extension)
            if [ "$2" ]; then
                EXTENSION="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --docker)
            DOCKER=1
            ;;
        --dockerimage)
            if [ "$2" ]; then
                DOCKERIMAGE="$2"
                DOCKER=1
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

if [ "${ERROR}" -ne -1 ]; then
    die ""
fi

INPUTFILE=$(basename -s ".${EXTENSION}" "${INPUT}")

# Remove potentially bad characters in name
OUTPUTBASE1=$(echo "$INPUTFILE" | sed ' s/--//g; s/=//g; s/ //g; s/:/_/g')
# Get last 120 characters of flags for folder name to prevent length issues
if [ "${#OUTPUTBASE1}" -ge 120 ]; then
    OUTPUTBASE=${OUTPUTBASE1: -120}
else
    OUTPUTBASE="$OUTPUTBASE1"
fi

OUTPUTFILE="${OUTPUTBASE}_av1an.mkv"
FULLOUTPUT="${OUTPUT}/${OUTPUTFILE}"
mkdir -p "${OUTPUT}"
COMMAND="av1an"
echo "output: $OUTPUT"
if [ -n "${DOCKER+x}" ]; then
    INPUTDIRECTORY=$(dirname "$INPUT")
    DOCKERRUN="docker run -v \"${INPUTDIRECTORY}:/videos/input\" -v \"${OUTPUT}:/videos/output\" -w /videos/output --user $(id -u):$(id -g) -i --rm ${DOCKERIMAGE}"
    DOCKERPROBE="docker run -v \"${OUTPUT}:/videos/output\" --user $(id -u):$(id -g) -i --rm luigi311/encoders-docker:latest"
    INPUT="/videos/input/${INPUTFILE}.${EXTENSION}"
    FULLOUTPUT="/videos/output/${OUTPUTFILE}"
    COMMAND=""
fi

BASE="${DOCKERRUN} ${COMMAND} -i \"${INPUT}\" --output_file \"${FULLOUTPUT}\" ${FLAG}"

eval "${BASE}"

FFPROBE="${DOCKERPROBE} ffprobe -hide_banner -loglevel error -i \"${FULLOUTPUT}\" 2>&1"
ERROR=$(eval "${FFPROBE}")
if [ -n "$ERROR" ]; then
    rm -rf "${OUTPUT}/${OUTPUTBASE:?}*"
    die "${INPUT} failed"
fi
