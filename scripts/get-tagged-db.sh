#!/bin/bash
BUILD_FOLDER=$1
SRC_FOLDER=$2
BUILD_TAG=$3
#BUILD_TAG=$(cd ${SRC_FOLDER} && git describe --tags --abbrev=0)

if [ x != x$BUILD_TAG ]; then
  TAG_DATE=$(cd ${SRC_FOLDER} && git log -1 --format=%ai ${BUILD_TAG})
  TAG_DATE=${TAG_DATE:0:10}
  TAG_DATE=${TAG_DATE//-/_}
  FULL_DATABASE_FRAGMENT="${BUILD_TAG}/TDB_full_world_${BUILD_TAG/TDB/}_${TAG_DATE}"
  if [ x != x$BUILD_FOLDER -a -d "$BUILD_FOLDER" ]; then
    wget https://github.com/TrinityCore/TrinityCore/releases/download/${FULL_DATABASE_FRAGMENT}.7z -O ${BUILD_FOLDER}/bin/fulldb.7z
  else
    exit 1
  fi
else
  echo No build tag provided
  false
fi

exit $?
