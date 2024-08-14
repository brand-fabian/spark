function vercomp() {
  [ "$1" = "`echo -e "$1\n$2" | sort -V | head -n 1`" ]
}

if [ $INSTALL_HAIL -eq 0 ]; then
  if [ "$HAIL_VERSION" = "main" ]; then
    SPARK_VERSION="3.5.0"
    JAVA_MIN_VERSION="11"
    JAVA_MAX_VERSION="12"
    PYTHON_MIN_VERSION="3.9"
  elif [ vercomp("0.2.130", "$HAIL_VERSION") ]; then
    SPARK_VERSION="3.5.0"
    JAVA_MIN_VERSION="11"
    JAVA_MAX_VERSION="12"
    PYTHON_MIN_VERSION="3.9"
  elif [ vercomp("0.2.110", "$HAIL_VERSION") ]; then
    SPARK_VERSION="3.3.1"
    JAVA_MIN_VERSION="11"
    JAVA_MAX_VERSION="12"
    PYTHON_MIN_VERSION="3.9"
  else
    SPARK_VERSION="3.1.3"
    JAVA_MIN_VERSION="8"
    JAVA_MAX_VERSION="9"
    PYTHON_MIN_VERSION="3.6"
  fi
else
  SPARK_VERSION="3.5.0"
  JAVA_MIN_VERSION="11"
  JAVA_MAX_VERSION="12"
  PYTHON_MIN_VERSION="3.9"
fi

if [ -z "$SPARK_VERSION" ]; then
  export SPARK_MODULE="$SPARK_MODULE"
else
  export SPARK_MODULE="$SPARK_MODULE/$SPARK_VERSION"
fi

if conda info --envs | grep "$CONDA_ENV" >/dev/null; then
  echo "Environment $CONDA_ENV already installed. Skipping."
else
  echo "Creating environment $CONDA_ENV"
  conda create -y -n "$CONDA_ENV" \
    make \
    "python>=$PYTHON_MIN_VERSION" \
    pip \
    "openjdk>=$JAVA_MIN_VERSION,<$JAVA_MAX_VERSION"

  conda activate "$CONDA_ENV"
  pip3 install jupyterlab "pyspark==$SPARK_VERSION"
  conda deactivate
fi

module use /software/easybuild/modules/all
module load toolchain/foss/2021b \
  lib/lz4 \
  lang/Rust \
  lang/Miniconda3 \
  $SPARK_MODULE
