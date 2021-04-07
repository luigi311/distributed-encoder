#!/usr/bin/env bash

# Source: http://mywiki.wooledge.org/BashFAQ/035
die() {
    printf '%s\n' "$1" >&2
    exit 1
}

help() {
    help="$(cat <<EOF
Test x265 flag, will gather stats such as file size, duration of first pass and second pass and put them in a csv.
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
THREADS=-1
TWOPASS=-1

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

if [ "$THREADS" -eq -1 ]; then
    THREADS=$(( 4 < $(nproc) ? 4 : $(nproc) ))
fi

if [ "${TWOPASS}" -eq 1 ] && [ -n "${FLAG+x}" ]; then
    if [ -z "${PASS1+x}" ]; then
        PASS1="${FLAG}"
    fi
    if [ -z "${PASS2+x}" ]; then
        PASS2="${FLAG}"
    fi
fi

FOLDER=$(basename -s ".${EXTENSION}" "${INPUT}")
OUTPUTFILE="$OUTPUT/${FOLDER}/${FOLDER}_x265.mkv"

mkdir -p "${OUTPUT}/${FOLDER}"
BASE="ffmpeg -y -hide_banner -loglevel error -i ${INPUT} -strict -1 -pix_fmt yuv420p10le -f yuv4mpegpipe - | x265 --input - --y4m"

if [ "$TWOPASS" -eq -1 ]; then
    eval "${BASE}" --pools "${THREADS}" -o "${OUTPUTFILE}" "${FLAG}"
else
    eval "${BASE}" --pools "${THREADS}" --pass 1 --stats "$OUTPUT/${FOLDER}/${FOLDER}.log" -o /dev/null "${PASS1}" "${FLAG}" &&
    eval "${BASE}" --pools "${THREADS}" --pass 2 --stats "$OUTPUT/${FOLDER}/${FOLDER}.log" -o "${OUTPUTFILE}" "${PASS2}" "${FLAG}"
fi

ERROR=$(ffprobe -hide_banner -loglevel error -i "${OUTPUTFILE}" 2>&1)
if [ -n "$ERROR" ]; then
    rm -rf "${OUTPUT}/${FOLDER:?}"
    die "${FLAG} failed"
fi

rm -f "${OUTPUT}/${FOLDER}/${FOLDER}.log"
rm -f "${OUTPUT}/${FOLDER}/${FOLDER}.log.cutree"
