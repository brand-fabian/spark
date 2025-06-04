function vercomp() {
  [ "$1" = "`echo -e "$1\n$2" | sort -V | head -n 1`" ]
}
export -f vercomp

# If hail is being installed, we overwrite the Spark module
# environments to fit the hail dependencies to the launched
# tools.
if [ $INSTALL_HAIL -eq 0 ]; then
  if [ "$HAIL_VERSION" = "main" ]; then
    SPARK_VERSION="3.5.0"
    JAVA_MIN_VERSION="11"
    JAVA_MAX_VERSION="12"
    PYTHON_MIN_VERSION="3.9"
    PYTHON_MAX_VERSION="3.10"
  elif vercomp "0.2.130" "$HAIL_VERSION"; then
    SPARK_VERSION="3.5.0"
    JAVA_MIN_VERSION="11"
    JAVA_MAX_VERSION="12"
    PYTHON_MIN_VERSION="3.9"
    PYTHON_MAX_VERSION="3.10"
  elif vercomp "0.2.110" "$HAIL_VERSION"; then
    SPARK_VERSION="3.3.1"
    JAVA_MIN_VERSION="11"
    JAVA_MAX_VERSION="12"
    PYTHON_MIN_VERSION="3.9"
    PYTHON_MAX_VERSION="3.10"
  else
    SPARK_VERSION="3.1.1-foss-2020b-hadoop3"
    JAVA_MIN_VERSION="8"
    JAVA_MAX_VERSION="9"
    PYTHON_MIN_VERSION="3.7"
    PYTHON_MAX_VERSION="3.8"
  fi
else
  SPARK_VERSION="3.5.0"
  JAVA_MIN_VERSION="11"
  JAVA_MAX_VERSION="12"
  PYTHON_MIN_VERSION="3.9"
  PYTHON_MAX_VERSION="3.10"
fi

if [ -z "$SPARK_VERSION" ]; then
  export SPARK_MODULE="$SPARK_MODULE"
else
  export SPARK_MODULE="$SPARK_MODULE/$SPARK_VERSION"
fi

module load "$CONDA_MODULE"
test -n "$CONDA_INIT" && eval "$CONDA_INIT"

if `conda info --envs | grep -qP "^$CONDA_ENV" >/dev/null`; then
  echo "Environment $CONDA_ENV already installed. Skipping."
else
  echo "Creating environment $CONDA_ENV"
  conda create -c conda-forge -c bioconda -y -n "$CONDA_ENV" \
    liblapack \
    lapack \
    lapackpp \
    libopenblas \
    openblas-devel \
    openblas \
    lz4-c \
    "python>=$PYTHON_MIN_VERSION,<$PYTHON_MAX_VERSION" \
    pip \
    "openjdk>=$JAVA_MIN_VERSION,<$JAVA_MAX_VERSION" \
    rust \
    uv

  conda deactivate
  
  conda activate "$CONDA_ENV"
  pip3 install \
    jupyterlab \
    "pyspark==$SPARK_VERSION" \
    "jinja2==3.0.3" \
    build
  conda deactivate
fi

module use /software/easybuild/modules/all
module load $CONDA_MODULE \
  $SPARK_MODULE
