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

OUTPUT="output"
INPUT="video.mkv"
ERROR=-1

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

FOLDER=$(basename -s ".${EXTENSION}" "${INPUT}")
# Remove potentially bad characters in name
FOLDER1=$(echo "$FOLDER" | sed ' s/--//g; s/=//g; s/ //g; s/:/_/g')
# Get last 120 characters of flags for folder name to prevent length issues
if [ "${#FOLDER1}" -ge 120 ]; then
    FOLDER=${FOLDER1: -120}
else
    FOLDER="$FOLDER1"
fi

OUTPUTFILE="$OUTPUT/${FOLDER}/${FOLDER}_av1an.mkv"

mkdir -p "${OUTPUT}/${FOLDER}"

av1an -i "${INPUT}" --output_file "${OUTPUTFILE}" ${FLAG}

ERROR=$(ffprobe -hide_banner -loglevel error -i "${OUTPUTFILE}" 2>&1)
if [ -n "$ERROR" ]; then
    rm -rf "${OUTPUT}/${FOLDER:?}"
    die "${FLAG} failed"
fi

rm -f "${OUTPUT}/${FOLDER}/${FOLDER}.log"
rm -f "${OUTPUT}/${FOLDER}/${FOLDER}.log.cutree"
