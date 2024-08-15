#! /bin/bash

# Srun wrapper for the hail script `hail-script.py`.
export
SCRIPT_DIR=$(dirname $(scontrol show job $SLURM_JOB_ID | grep "Command=" | cut -d'=' -f2))
python3 "${SCRIPT_DIR}/hail-script.py"
