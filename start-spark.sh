#! /bin/bash
source $SCRIPT_DIR/ood-helpers.sh

# Use base dir since we dont have module available yet
export base_dir="${HOME}/scratch/spark"
export spark_home="${HOME}/scratch/spark/${SLURM_JOBID}"
export HAIL_BASE="$HOME/scratch/hail/$SLURM_JOBID"

module use /software/easybuild/modules/all
module load Anaconda3
conda activate --no-stack "$CONDA_ENV"

function clean {
  rm -rf "${spark_home}"
  rm -rf "${HAIL_BASE}"
}

if [ "$1" != 'worker' ]; then
  this=$SCRIPT_DIR/start-spark.sh
  script="${spark_home}_$(basename -- "$0")"
  mkdir -p "$spark_home"
  cp "$this" "$script"
  chmod +x "$script"

  export spark_logs="${spark_home}/logs"
  export remote_tmp="${spark_home}/tmp"
  export spark_tmp="$remote_tmp"
  mkdir -p -- "$spark_logs"  "$spark_tmp"

  # Set temporary directory to shared file system
  export TMPDIR="${spark_home}/tmp"
  export TMPDIR=$(mktemp -d)

  export SPARK_WORKER_DIR="$spark_logs"
  export SPARK_LOCAL_DIRS="$spark_tmp"
  export SPARK_MASTER_PORT=$(find_port ${host})
  export SPARK_MASTER_WEBUI_PORT=$(find_port ${host})
  export SPARK_WORKER_CORES=$SLURM_CPUS_PER_TASK
  export SPARK_DAEMON_MEMORY=$(( $SLURM_MEM_PER_CPU * $SLURM_CPUS_PER_TASK - 500 ))m
  export SPARK_MEM=$SPARK_DAEMON_MEMORY
  export SPARK_WORKER_MEMORY=$SPARK_DAEMON_MEMORY

  srun "$script" "worker"
else
  source "$SPARK_HOME/sbin/spark-config.sh"
  source "$SPARK_HOME/bin/load-spark-env.sh"

  if [ "$SLURM_PROCID" -eq 0 ]; then
    MASTER_NODE=$(scontrol show hostname $SLURM_NODELIST | head -n 1)
    export SPARK_MASTER_IP=${MASTER_NODE/eth/ib}
    export PYSPARK_SUBMIT_ARGS="--master spark://${SPARK_MASTER_IP}:${SPARK_MASTER_PORT} pyspark-shell"

    echo "spark://${SPARK_MASTER_IP}:${SPARK_MASTER_PORT}" > "$spark_home/${SLURM_JOB_ID}_spark_master"
    echo "Running spark-master on ${SPARK_MASTER_IP}:${SPARK_MASTER_PORT} (webui: ${SPARK_MASTER_WEBUI_PORT})"
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.master.Master \
      --ip  0.0.0.0 \
      --port "$SPARK_MASTER_PORT" \
      --webui-port "$SPARK_MASTER_WEBUI_PORT" &
    
    echo "Running spark-worker on $(hostname) to connect to ${SPARK_MASTER_IP}:${SPARK_MASTER_PORT}"
    export SPARK_WORKER_CORES=$(( $SPARK_WORKER_CORES - $MASTER_RESERVED_CORES ))
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.worker.Worker "spark://$SPARK_MASTER_IP:$SPARK_MASTER_PORT" &

    if [ $INSTALL_HAIL -eq 0 ]; then
      echo "Installing hail on top of spark cluster"
      source $SCRIPT_DIR/install-hail.sh
    fi

    trap clean EXIT
    eval "$SCRIPT"
    # After finishing force the job to exit
    scancel "$SLURM_JOB_ID"
  else
    export SPARK_MASTER_IP=$(scontrol show hostname $SLURM_NODELIST | head -n 1)
    export SPARK_MASTER_IP=${SPARK_MASTER_IP/eth/ib}
    echo "Running spark-worker on $(hostname) to connect to ${SPARK_MASTER_IP}:${SPARK_MASTER_PORT}"
    MASTER_NODE="spark://$SPARK_MASTER_IP:$SPARK_MASTER_PORT"
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.worker.Worker $MASTER_NODE
  fi
fi
