#!/bin/bash

module use /software/easybuild/modules/all
module purge
module load Anaconda3 foss/2021b lz4
conda activate --no-stack "$CONDA_ENV"

mkdir -p "$(dirname $HAIL_BASE)"
git clone -b "$HAIL_VERSION" https://github.com/hail-is/hail.git $HAIL_BASE

cd "${HAIL_BASE}/hail"
make clean
make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION=2.12.13 SPARK_VERSION=3.1.2
cd -
