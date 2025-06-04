#! /bin/bash -x

module use /software/easybuild/modules/all
module purge
module load "$CONDA_MODULE"

conda deactivate
test -n "$CONDA_INIT" && eval "$CONDA_INIT"
conda activate "$CONDA_ENV"

if [[ "$HAIL_VERSION" =~ 0.2.* ]]; then
    pip3 install "hail==$HAIL_VERSION"
else
    pip3 install "hail"
fi
