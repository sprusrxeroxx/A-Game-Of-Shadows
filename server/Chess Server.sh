#!/bin/sh
printf '\033c\033]0;%s\a' Chess Server
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Chess Server.x86_64" "$@"
