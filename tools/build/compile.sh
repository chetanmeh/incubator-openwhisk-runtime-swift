#!/bin/bash
set -e

if [ -z "$1" ] ; then
    echo 'Error: Missing action name'
    exit 1
fi
if [ -z "$2" ] ; then
    echo 'Error: Missing runtime docker image name, for example openwhisk/action-swift-v4.0'
    exit 2
fi

BASE_PATH="/swift3Action"
DEST_SOURCE="$BASE_PATH/spm-build"
RUNTIME="openwhisk/action-swift-v3.1.1"
if [ ${2} == "swift:3.1.1" ]; then
  OUTPUT_DIR="build/swift311"
elif [ ${2} == "swift:4.0" ]; then
  RUNTIME="action-swift-v4.0"
  BASE_PATH="/swift4Action"
  DEST_SOURCE="/$BASE_PATH/spm-build/Sources/Action"
  OUTPUT_DIR="build/swift4.0"
elif [ ${2} == "swift:4.1" ]; then
  RUNTIME="action-swift-v4.1"
  BASE_PATH="/swift4Action"
  DEST_SOURCE="/$BASE_PATH/spm-build/Sources/Action"
  OUTPUT_DIR="build/swift4.1"
else
  echo "Error: Kind $2 not recognize"
  exit 3
fi
DEST_PACKAGE_SWIFT="$BASE_PATH/spm-build/Package.swift"

BUILD_FLAGS=""
if [ -n "$3" ] ; then
    BUILD_FLAGS=${3}
fi


echo "Using runtime $RUNTIME to compile swift"
docker run --rm --name=compile-ow-swift -it -v "$(pwd):/owexec" $RUNTIME bash -ex -c "

if [ -f \"/owexec/$OUTPUT_DIR/$1.zip\" ] ; then
    rm \"/owexec/$OUTPUT_DIR/$1.zip\"
fi

echo 'Setting up build...'
cp /owexec/actions/$1/Sources/*.swift $DEST_SOURCE/

# action file can be either {action name}.swift or main.swift
if [ -f \"$DEST_SOURCE/$1.swift\" ] ; then
    echo 'renaming $DEST_SOURCE/$1.swift $DEST_SOURCE/main.swift'
    mv \"$DEST_SOURCE/$1.swift\" $DEST_SOURCE/main.swift
fi
# Add in the OW specific bits
cat $BASE_PATH/epilogue.swift >> $DEST_SOURCE/main.swift
echo '_run_main(mainFunction:main)' >> $DEST_SOURCE/main.swift

echo \"Compiling $1...\"
cd /$BASE_PATH/spm-build
cp /owexec/actions/$1/Package.swift $DEST_PACKAGE_SWIFT
# we have our own Package.swift, do a full compile
swift build ${BUILD_FLAGS} -c release

echo 'Creating archive $1.zip...'
#.build/release/Action
mkdir -p /owexec/$OUTPUT_DIR
zip \"/owexec/$OUTPUT_DIR/$1.zip\" .build/release/Action

"