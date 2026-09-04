#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    printf 'Usage: %s SOURCE_ISO [OUTPUT_ISO]\n' "$(basename "$0")" >&2
    exit 64
fi

source_iso="$1"
output_iso="${2:-Windows10-Gaming.iso}"
repository_root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if [[ ! -f "$source_iso" ]]; then
    printf 'The source ISO does not exist or is not a regular file.\n' >&2
    exit 66
fi

if [[ "$source_iso" == "$output_iso" ]]; then
    printf 'The output ISO must differ from the source ISO.\n' >&2
    exit 65
fi

if [[ -e "$output_iso" ]]; then
    printf 'The output path already exists; refusing to overwrite it.\n' >&2
    exit 73
fi

if ! command -v xorriso >/dev/null 2>&1; then
    printf 'xorriso is required but was not found.\n' >&2
    exit 69
fi

xorriso \
    -quiet \
    -indev "$source_iso" \
    -outdev "$output_iso" \
    -map "$repository_root/autounattend.xml" /autounattend.xml \
    -map "$repository_root/oem/\$OEM\$" '/sources/$OEM$' \
    -boot_image any replay

printf 'ISO created successfully.\n'
