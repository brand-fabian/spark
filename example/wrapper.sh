#! /bin/bash

# Srun wrapper for the hail script `hail-script.py`.
#
# This script writes all current environment variables to the Job log
# and executes the hail script inside the spark cluster created by
# `spark.sh`.
export
SCRIPT_DIR=$(dirname $(scontrol show job $SLURM_JOB_ID | grep "Command=" | cut -d'=' -f2))
python3 "${SCRIPT_DIR}/hail-script.py"
