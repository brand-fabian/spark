#!/bin/bash
#SBATCH --partition=batch
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=1G
#SBATCH --cpus-per-task=4
#SBATCH --ntasks=2

# Example of using this script for running 
# `hail-script.py` on the HPC cluster Marvin of the
# University of Bonn.
#
# We assume that this bash script is started from the
# example directory (i.e. $PWD), otherwise the path to
# the spark.sh script has to be adjusted.
#
# Usage: `sbatch <submit.sh>`
SCRIPT_DIR=$(dirname $(scontrol show job $SLURM_JOB_ID | grep "Command=" | cut -d'=' -f2))
bash "${SCRIPT_DIR}/../spark.sh" --hail-version 0.2.129 \
    --spark-interface "ib0" \
    --spark-version "3.5.0" \
    --spark-module "devel/Spark" \
    --conda-module "lang/Miniconda3" \
    -Xis "${SCRIPT_DIR}/wrapper.sh"
