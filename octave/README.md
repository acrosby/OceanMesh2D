# Octave setup

Support for linux/unix like systems already having netcdf and c++ compiler system libraries installed.

tldr; Run the following scripts:

Run once to install/build required dependencies.

```bash
bash setup_octave.sh
# setup_octave.sh has completed successfully!

```

Run along with `setup_oceanmesh2d` to add some extra paths to the environment in Octave console or scripts.

```bash
octave --no-gui --eval "setup_octave"
```

## `setup_octave.sh`

1. Bootstrap `ann_wrapper` from a forked version of [MatlabSupport](https://github.com/acrosby/MatlabSupport/tree/octave) that supports compiling for Octave.
2. Install the `netcdf` package from Octave forge with `pkg`

You will see the "completed successfully" message, if the steps were completed without error.
_NB: May require `pkg` to also be added/installed to your Octave installation_

```bash
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
```

## `setup_octave.m

The `setup_octave` function calls `pkg load netcdf` and adds ann_wrapper to your environments path, so that they are available to the routines in OM2D.

From the Octave REPL or ".m" script:

```octave
setup_oceanmesh2d
setup_octave
```
