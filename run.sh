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
    ./run.sh -i /home/luigi311/Videos --extension mkv -enc av1an -f "-enc x265 -v ' -p slower --crf 25 -D 10 -F 2 ' --target_quality 94 --vmaf --mkvmerge" --docker --distribute
Options:
    -h/--help                   Print this help screen
    -i/--input        [file]    Video source to use                                                        (default video.mkv)
    -e/--enc          [string]  Encoder to use                                                             (default av1an)
    --encworkers      [number]  Amount of encoders to run in parallel on each machine                      (default encoding threads/cpu threads)
    -t/--threads      [number]  Amount of threads to use in encoder                                        (default av1an:nproc, x265:4)
    --extension       [string]  Video extension of videos to encode                                        (default mkv)
    --twopass                   Enable two pass encoding for x265                                          (default false)
    --pass1           [string]  Flags to use for first pass when encoding, enables twopass
    --pass2           [string]  Flags to use for second pass when encoding, enables twopass
    -f/--flag         [string]  Flags for encoder to use
    --distribute                Parallelize across multiple computers based on ~/.parallel/sshloginfile    (default false)
    --resume                    Resume option for parallel, will use encoding.log and vmaf.log             (default false)
    --docker                    Enable the use of docker to run all commands                               (default false)
    --encoderimage    [string]  Docker image to use for encoder, enables docker                            (default av1an:masterofzen/av1an:master,x265:luigi311/encoders-docker:latest)
    --ffmpegimage     [string]  Docker image to use for validation, prepare and combine, enables docker    (defualt luigi311/encoders-docker:latest)
    --audioflags      [string]  Flags to use when encoding audio during the combine stage                  (default -c:a flac)
    --audiostreams    [string]  Audio streams to keep and encode during hte combine stage, comma seperated (default 0)
EOF
)"
    echo "$help"
}

EXTENSION="mkv"
ENC_WORKERS=-1
ENCODER="av1an"
SUPPORTED_ENCODERS="x265:av1an"
AUDIOFLAGS="-c:a flac"
AUDIOSTREAMS="0"
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
                INPUT="${2%/}"
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
            RESUME="--resume --resume-failed"
            ;;
        --docker)
            DOCKER="--docker"
            ;;
        --encoderimage)
            if [ "$2" ]; then
                ENOCDERMANUAL=1
                ENCODERIMAGE="$2"
                DOCKER="--docker"
                shift
            else
                die "ERROR: $1 requires a non-empty argument."
            fi
            ;;
        --ffmpegimage)
            if [ "$2" ]; then
                FFMPEGIMAGE="$2"
                DOCKER="--docker"
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

if [ -z "${ENOCDERMANUAL+x}" ]; then
    if [ "${ENCODER}" == "av1an" ]; then
        ENCODERIMAGE="masterofzen/av1an:master"
    else
        ENCODERIMAGE="luigi311/encoders-docker:latest"
    fi
fi

if [ -z "${THREADS+x}" ]; then
    if [ "${ENCODER}" == "x265" ]; then
        THREAD="$(( 4 < $(nproc) ? 4 : $(nproc) ))"
        THREADS="--threads ${THREAD}"
    elif [ "${ENCODER}" == "av1an" ]; then
        THREAD=$(nproc)
        ENC_WORKERS=1
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

echo "Starting encoding"
find "${INPUT}" -name "*.${EXTENSION}" ! -path "*/.*/encode/*" ! -path "*/.*/split/*" ! -path "*/de_final_*" ! -path "*/de_prepared_*" ! -path "*/de_encoded_*"  | parallel -j "${ENC_WORKERS}" --joblog encoding.log $DISTRIBUTE $RESUME --bar "scripts/main.sh" --input "{}" --encoder "${ENCODER}" "${THREADS}" "${ENCODING}" "${FLAG}" "${TWOPASS}" "${PASS1}" "${PASS2}" "${DOCKER}" --encoderimage "\"${ENCODERIMAGE}\"" --ffmpegimage "\"${FFMPEGIMAGE}\"" --audioflags "\"${AUDIOFLAGS}\"" --audiostreams "\"${AUDIOSTREAMS}\""
