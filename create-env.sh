
if conda info --envs | grep "$CONDA_ENV" >/dev/null; then
  echo "Environment $CONDA_ENV already installed. Skipping."
else
  echo "Creating environment $CONDA_ENV"
  conda create -y -n "$CONDA_ENV" \
    make "python>3" pip "openjdk>=8,<9"

  conda activate "$CONDA_ENV"
  pip3 install jupyterlab "pyspark==3.1.1"
  conda deactivate
fi