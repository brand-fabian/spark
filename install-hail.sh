#! /bin/bash -x

module use /software/easybuild/modules/all
module purge
module load lang/Miniconda3 toolchain/foss/2021b lib/lz4

conda deactivate
conda activate "$CONDA_ENV"

mkdir -p "$(dirname $HAIL_BASE)"
git clone -b "$HAIL_VERSION" https://github.com/hail-is/hail.git $HAIL_BASE

cd "${HAIL_BASE}/hail"
make clean
make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION=2.12.13 SPARK_VERSION=$SPARK_VERSION
cd -
