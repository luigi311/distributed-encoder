# distributed-encoder
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/e821a66282354c2f827ad23823b63cce)](https://www.codacy.com/gl/Luigi311/distributed-encoder/dashboard?utm_source=gitlab.com&amp;utm_medium=referral&amp;utm_content=Luigi311/distributed-encoder&amp;utm_campaign=Badge_Grade)  

Mass encode videos using gnu parallel to automate mass folder encoding and distributing across machines

## supported encoders
- av1an
- x265

## Usage

```bash
Usage:
    ./run.sh -i {Folder location} {Options}
Example:
    ./run.sh -i /home/luigi311/Videos --extension mkv -enc av1an -f "-e x265 -v ' -p slower --crf 25 -D 10 -F 2 ' --target-quality 94 --vmaf --mkvmerge" --docker --distribute --audioflags "-c:a aac -b:a 192k" --audiostreams "0,2"
```

### Options

```bash
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
    --shared                    Do not transfer video to other servers, use with network storage           (default false)
```
