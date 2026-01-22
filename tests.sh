#!/usr/bin/env bash

IFS=
while true; do
    read -rsn1 key

    case "$key" in
    ' ') echo space ;;
    c) echo c ;;
    *) echo other ;;
    esac
done
