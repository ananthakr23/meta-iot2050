#!/bin/sh
#
# Copyright (c) Siemens AG, 2023
#
# Authors:
#   Li Hua Qian <huaqian.li@siemens.com>
#
# This file is subject to the terms and conditions of the MIT License.  See
# COPYING.MIT file in the top-level directory.
#

update_json() {
    version_letter="$(echo $2 | head -c 1)"

    sed -i '/"version": ".*"/s|"V.*"|"'$2'"|g' $1
    sed -i '/"description": ".*"/s|V.*["$]|'$2\"'|g' $1
    sed -i '/"min_version": ".*"/s|"V|"'$version_letter'|g' $1

    # if the SUGGEST_PRESERVED_UBOOT_ENV is not empty, update the
    # suggest_preserved_uboot_env in the update.conf.json
    if [ ! -z "$SUGGEST_PRESERVED_UBOOT_ENV" ]; then
        original=$(grep -zoP '(?<="suggest_preserved_uboot_env": \[)[^\]]*' $1)
        indent=$(echo "$original" | sed -n '2p' | grep -oP '^\s*')

        if ! echo "$SUGGEST_PRESERVED_UBOOT_ENV" | grep -qP '^[^,]+(,[^,]+)*$'; \
        then
            echo "Error: SUGGEST_PRESERVED_UBOOT_ENV should be \"value1,value2,...\""
            exit 2
        fi
        new_value=$(echo "\n$indent\"$SUGGEST_PRESERVED_UBOOT_ENV\"" | \
            sed "s/,/\",\n$indent\"/g")

        if [ ! -z "$new_value" ]; then
            original=$(echo "$original" | sed 's/\s*$//')
            original="$original,"
            new_value="$original$new_value"

            # Remove duplicated strings from the new_value variable
            new_value=$(echo "$new_value" | awk '!seen[$0]++')

            perl -i -pe 'BEGIN{undef $/;} \
            s/(?<="suggest_preserved_uboot_env": \[).*?(?=\n\s*\])/'"$new_value"'/smg' \
            $1
        fi
    fi
}

generate_fwu_tarball() {
    echo "Generating the firmware tarball..."

    if [ ! -e $2/iot2050-pg1-image-boot.bin ] || \
       [ ! -e $2/iot2050-pg2-image-boot.bin ]; then
        echo "Error: iot2050-pg1/2-image-boot.bin doesn't exist!"
        exit 2
    fi

    if [ ! -e $2/u-boot-initial-env ]; then
        echo "Error: u-boot-initial-env doesn't exist!"
        exit 2
    fi

    mkdir -p $2/.tarball
    if [ ! -d $2/.tarball ]; then
        echo "Error: Failed to create the directory $2/.tarball"
        exit 2
    fi

    cp $1/update.conf.json.tmpl $2/.tarball/update.conf.json
    update_json $2/.tarball/update.conf.json $3
    cp $2/iot2050-pg*-image-boot.bin $2/.tarball
    cp $2/u-boot-initial-env $2/.tarball

    cd $2/.tarball
    tar -cJvf $2/IOT2050-FW-Update-PKG-$3.tar.xz *
    cd - && rm -rf $2/.tarball
}

generate_fwu_tarball $*
