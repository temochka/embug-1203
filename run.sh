docker build - --tag embug:latest < Dockerfile
docker run -ti --cap-add SYS_PTRACE --security-opt seccomp=unconfined -v $(pwd):/checkout embug:latest bash
