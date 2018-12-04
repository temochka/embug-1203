FROM ubuntu:18.04

RUN apt-get update && apt-get install -y build-essential cmake libc++-dev libc++abi-dev clang git vim ruby ruby-bundler ruby-dev strace gdb

WORKDIR /checkout
