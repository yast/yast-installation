FROM registry.opensuse.org/yast/head/containers/yast-ruby:latest
RUN zypper --non-interactive in --no-recommends yast2-ntp-client
COPY . /usr/src/app

