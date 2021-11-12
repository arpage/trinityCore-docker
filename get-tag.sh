#!/bin/bash
SRC_FOLDER=$1
BUILD_TAG=`cd ${SRC_FOLDER} && git describe --tags --abbrev=0`
echo $BUILD_TAG

