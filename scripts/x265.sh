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
THREADS=-1
TWOPASS=-1
DOCKERIMAGE="registry.gitlab.com/luigi311/encoders-docker:latest"

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

INPUTFILE=$(basename -s ".${EXTENSION}" "${INPUT}")

# Remove potentially bad characters in name
OUTPUTBASE1=$(echo "$INPUTFILE" | sed ' s/--//g; s/=//g; s/ //g; s/:/_/g')
# Get last 120 characters of flags for folder name to prevent length issues
if [ "${#OUTPUTBASE1}" -ge 120 ]; then
    OUTPUTBASE=${OUTPUTBASE1: -120}
else
    OUTPUTBASE="$OUTPUTBASE1"
fi

OUTPUTFILE="${OUTPUTBASE}_x265.h265"
FULLOUTPUT="${OUTPUT}/${OUTPUTFILE}"
mkdir -p "${OUTPUT}"

if [ -n "${DOCKER+x}" ]; then
    DOCKERRUN="docker run -v $(dirname "${INPUT}"):/videos/input -v ${OUTPUT}:/videos/output --user $(id -u):$(id -g) -i --rm ${DOCKERIMAGE}"
    INPUT="/videos/input/${INPUTFILE}.${EXTENSION}"
    FULLOUTPUT="/videos/output/${OUTPUTFILE}"
fi

BASE="${DOCKERRUN} /bin/bash -c \"ffmpeg -y -hide_banner -loglevel error -i ${INPUT} -strict -1 -pix_fmt yuv420p10le -f yuv4mpegpipe - | x265 --log-level error --input - --y4m --pools ${THREADS} ${FLAG}"

if [ "${TWOPASS}" -eq -1 ]; then
    eval "${BASE} -o ${FULLOUTPUT}\""
else
    eval "${BASE} --pass 1 --stats ${OUTPUT}/${OUTPUTBASE}.log -o /dev/null ${PASS1}\"" &&
    eval "${BASE} --pass 2 --stats ${OUTPUT}/${OUTPUTBASE}.log -o ${FULLOUTPUT} ${PASS2}\""
fi

ERROR=$(${DOCKERRUN} ffprobe -hide_banner -loglevel error -i "${FULLOUTPUT}" 2>&1)
if [ -n "$ERROR" ]; then
    rm -rf "${OUTPUT}/${OUTPUTBASE:?}*"
    die "${FLAG} failed"
fi

rm -f "${OUTPUT}/${OUTPUTBASE}.log"
rm -f "${OUTPUT}/${OUTPUTBASE}.log.cutree"
