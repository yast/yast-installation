partitions:
  config:
    label: gpt
    initial_gap: 1MB
  devices:
    /dev/vda:
      partitions:
        - number: 1
          size: 256MB
          type: efi
        - number: 2
          size: 512MB
          type: swap
        - number: 3
          size: rest
          type: linux
filesystems:
  /dev/vda1:
    filesystem: vfat
    mountpoint: /boot/efi
    fat: 32
  /dev/vda2:
    filesystem: swap
  /dev/vda3:
    filesystem: btrfs
    mountpoint: /
    subvolumes:
      prefix: '@'
      subvolume:
        - path: home
        - path: opt
        - path: root
        - path: srv
        - path: tmp
        - path: usr/local
        - path: var
          copy_on_write: no
        - path: boot/grub2/i386-pc
        - path: boot/grub2/x86_64-efi

software:
  config:
    enabled: yes
    autorefresh: yes
    gpgcheck: yes
  repositories:
    repo-oss:
      url: "http://download.opensuse.org/tumbleweed/repo/oss/"
      name: openSUSE-Tumbleweed
  packages:
    - product:openSUSE
    - pattern:enhanced_base
    - glibc-locale

users:
  - username: root
    # Set the password as 'linux'. Do not do that in production
    password: "$6$aS7uEM4QRbFExc4Z$hinOelrXzdN9tUoFZbSmAag1YBE/ACbLnuhaQ0DNs04Ou.7Wgpscu6cuCWkk2sc2/pZXDTX0Ay67k2wfWbiI3."

bootloader:
  device: /dev/vda
  theme: yes

config:
  events: no
  reboot: no
  snapper: yes
  locale: es_ES.UTF-8
  keymap: es
  timezone: UTC
  hostname: myhost

services:
  enabled:
    - salt-minion
