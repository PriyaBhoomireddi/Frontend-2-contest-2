#!/bin/sh

streamTag=%STREAMTAG
realApp="%APPLICATION"
destfolder="%DESTINATION"

STREAMERSDIR="$HOME/Library/Application Support/Autodesk/webdeploy/$streamTag"

if "${destfolder}" == "" ; then
    for ver in $(ls -t "${STREAMERSDIR}"); do
        STREAMERPATH="${STREAMERSDIR}/${ver}/$realApp.app"
        if [ -x "$STREAMERPATH" ]; then
            break
        fi
        STREAMERPATH=""
    done
else
    STREAMERPATH="$destfolder/$realApp.app"
fi

exec "$STREAMERPATH/Contents/MacOS/$realApp" "$@"
