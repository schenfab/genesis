# shellcheck shell=bash
# Common to every host: base system, pacman, shell tools, ssh, printing/scanning daemons.
CopyFile /etc/sudoers.d/10-wheel 440
