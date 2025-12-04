#!/bin/bash
####################################################
# This script downloads clones                     #
#                                                  #
# Requires git                                     #
#                                                  #
####################################################

ScriptPath=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$ScriptPath" || exit 1

if [ -d "MatlabSupport" ]; then
    echo "\"MatlabSupport\" directory already exists"
else
    echo "Setting up ann_wrapper by cloning github.com/acrosby/MatlabSupport fork of github.com/jefferislab/MatlabSupport"
    git clone -b octave https://github.com/acrosby/MatlabSupport.git || exit 1
fi
pushd MatlabSupport/ann_wrapper
echo running ann_class_compile.m
octave --no-gui --eval ann_class_compile || exit 1
popd
octave --no-gui --eval "pkg install -forge netcdf" || exit 1
echo "setup_octave.sh has completed successfully!"
