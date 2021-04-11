#!/usr/bin/env bash

# Source: http://mywiki.wooledge.org/BashFAQ/035
die() {
    printf '%s\n' "$1" >&2
    exit 1
}

help() {
    help="$(cat <<EOF
Description
Usage:
    ./run.sh [options]
Example:
    ./run.sh 
General Options:
    -h/--help                       Print this help screen
    -i/--input          [file]      Video source to use                                             (default video.mkv)
    -o/--output         [folder]    Output folder to place all encoded videos and stats files       (default output)
    -e/--encworkers     [number]    Number of encodes to run simultaneously                         (defaults threads/encoding threads)
    --resume                        Resume option for parallel, will use encoding.log and vmaf.log  (default false)
Encoding Settings:
    --enc               [string]    Encoder to test, supports aomenc and x265                       (default aomenc)
    -f/--flags          [file]      File with different flags to test. Each line is a seperate test (default arguments.aomenc)
EOF
)"
    echo "$help"
}

OUTPUT="output"
EXTENSION="mkv"
ENC_WORKERS=-1
ENCODER="x265"
SUPPORTED_ENCODERS="x265:av1an"

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
                die "ERROR: $1 requires a non-empty option argument."
            fi
            ;;
        -o | --output)
            if [ "$2" ]; then
                OUTPUT="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty option argument."
            fi
            ;;
        -e | --enc)
            if [ "$2" ]; then
                ENCODER="$2"
                # https://stackoverflow.com/questions/8063228/how-do-i-check-if-a-variable-exists-in-a-list-in-bash#comment91727359_46564084
                if [[ ":$SUPPORTED_ENCODERS:" != *:${ENCODER}:* ]]; then
                    die "Encoder $2 not supported"
                fi
                shift
            else
                die "ERROR: $1 requires a non-empty option argument."
            fi
            ;;
        --encworkers)
            if [ "$2" ]; then
                ENC_WORKERS="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty option argument."
            fi
            ;;
        -t | --threads)
            if [ "$2" ]; then
                THREAD="$2"
                THREADS="--threads ${THREAD}"
                shift
            else
                die "ERROR: $1 requires a non-empty option argument."
            fi
            ;;
        --extension)
            if [ "$2" ]; then
                EXTENSION="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty option argument."
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
        -f | --flag)
            if [ "$2" ]; then
                FLAG="--flag \"$2\""
                FLAGVAR="$2"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --distribute)
            DISTRIBUTE="--sshloginfile .. --workdir . --sshdelay 0.2"
            ;;
        --resume)
            RESUME="--resume"
            ;;
        --) # End of all options.
            shift
            break
            ;;
        -?*)
            die "Error: Unknown option : $1"
            ;;
        *) # Default case: No more options, so break out of the loop.
            break ;;
    esac
    shift
done

if [ -z "${INPUT+x}" ]; then
    die "Input not set"
fi

if [ -z "${THREADS+x}" ]; then
    if [ "${ENCODER}" == "aomenc" ]; then
        THREAD=4
        THREADS="--threads ${THREAD}"
    elif [ "${ENCODER}" == "svt-av1" ]; then
        THREAD=4
        THREADS="--threads ${THREAD}"
    elif [ "${ENCODER}" == "x265" ]; then
        THREAD=4
        THREADS="--threads ${THREAD}"
    elif [ "${ENCODER}" == "x264" ]; then
        THREAD=4
        THREADS="--threads ${THREAD}"
    elif [ "${ENCODER}" == "av1an" ]; then
        THREAD=$(nproc)
    else
        die "ERROR: thread not set"
    fi
fi

if [ -n "${TWOPASS+x}" ] && [ -n "${FLAGVAR+x}" ]; then
    if [ -z "${PASS1+x}" ]; then
        PASS1="-pass1 \"${FLAGVAR}\""
    fi
    if [ -z "${PASS2+x}" ]; then
        PASS2="--pass2 \"${FLAGVAR}\""
    fi
fi

# Set job amounts for encoding
if [ "${ENC_WORKERS}" -eq -1 ]; then
    ENC_WORKERS=$(( (100 / "${THREAD}") ))
    ENC_WORKERS="${ENC_WORKERS}%"
fi

echo "Encoding"
find "${INPUT}" -name "*.${EXTENSION}" | parallel -j "${ENC_WORKERS}" --joblog encoding.log $DISTRIBUTE $RESUME --bar "scripts/${ENCODER}.sh" --input {}  --extension "${EXTENSION}" --output "${OUTPUT}" "${THREADS}" "${ENCODING}" "${FLAG}" "${TWOPASS}" "${PASS1}" "${PASS2}"
