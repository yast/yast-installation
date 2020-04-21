FROM registry.opensuse.org/yast/sle-15/sp2/containers/yast-ruby
RUN zypper --non-interactive in --no-recommends yast2-ntp-client
COPY . /usr/src/app

