#! /bin/bash -x
source "${SCRIPT_DIR}/ood-helpers.sh"

# Use base dir since we dont have module available yet
export base_dir="${SCRATCH_ROOT}/spark"
export spark_home="${SCRATCH_ROOT}/spark/${SLURM_JOBID}"
export HAIL_BASE="${SCRATCH_ROOT}/hail/$SLURM_JOBID"

module load "$CONDA_MODULE"
test -n "$CONDA_INIT" && eval "$CONDA_INIT"
conda activate --no-stack "$CONDA_ENV"

function clean {
  if [ $KEEP_TMP -eq 0 ]; then
    rm -rf "${spark_home}"
    rm -rf "${HAIL_BASE}"
  fi
}

function stop {
  # $1 - PID to stop
  echo -e "handling stop signal for spark cluster"
  test -n "$1" && kill -9 "$1"
}

# Retrieve the correct interface number, in case we are
# dealing with `ibs*`.
if [ "$SPARK_INTERFACE" == "ibs" ]; then
  SPARK_INTERFACE=$(ip a | grep ibs | head -n 1 | cut -d' ' -f2 | cut -d':' -f1)
fi

if [ "$1" != 'worker' ]; then
  this=$SCRIPT_DIR/start-spark.sh
  script="${spark_home}_$(basename -- "$0")"
  mkdir -p "$spark_home"
  cp "$this" "$script"
  chmod +x "$script"

  module load "$SPARK_MODULE"

  # Install s3 connector jars
  if [ $INSTALL_S3_CONNECTOR -eq 0 ]; then
    source "${SCRIPT_DIR}/install-s3-connector.sh"
  fi

  export spark_logs="${spark_home}/logs"
  export remote_tmp="${spark_home}/tmp"
  export spark_tmp="$remote_tmp"
  mkdir -p -- "$spark_logs"  "$spark_tmp"

  # Set temporary directory to shared file system
  export TMPDIR="${spark_home}/tmp"
  export SPARK_LOCAL_DIRS="$(mktemp -d)" 
  export TMPDIR=$(mktemp -d)

  export SPARK_WORKER_DIR="$spark_logs"
  export SPARK_MASTER_PORT=$(find_port ${host})
  export SPARK_MASTER_WEBUI_PORT=$(find_port ${host})
  export SPARK_WORKER_CORES=$SLURM_CPUS_PER_TASK
  if [ -n "$SLURM_MEM_PER_CPU" ]; then
    export SPARK_DAEMON_MEMORY=$(( $SLURM_MEM_PER_CPU * $SLURM_CPUS_PER_TASK - 500 ))m
  else
    export SPARK_DAEMON_MEMORY=$(( $SLURM_MEM_PER_NODE - 500 ))m
  fi
  export SPARK_MEM=$SPARK_DAEMON_MEMORY
  export SPARK_WORKER_MEMORY=$SPARK_DAEMON_MEMORY
  export SPARK_CONF_DIR="${spark_home}/conf"

  srun --export=ALL "$script" "worker"
else
  source "$SPARK_HOME/sbin/spark-config.sh"
  source "$SPARK_HOME/bin/load-spark-env.sh"

  if [ "$SLURM_PROCID" -eq 0 ]; then
    MASTER_NODE=$(scontrol show hostname $SLURM_NODELIST | head -n 1)
    if [ -z "$IPOIB_DOMAIN" ]; then
      export SPARK_MASTER_HOSTNAME=${MASTER_NODE/eth/ib}
    else
      export SPARK_MASTER_HOSTNAME="${MASTER_NODE}.${IPOIB_DOMAIN}"
    fi
    export SPARK_MASTER_IP="$(dig +short +search $SPARK_MASTER_HOSTNAME)"

    export TMPDIR="${spark_home}/tmp"
    export SPARK_LOCAL_DIRS="$(mktemp -d)" 
    export TMPDIR=$(mktemp -d)
    export SPARK_LOCAL_IP="$SPARK_MASTER_IP"
    
    export PYSPARK_SUBMIT_ARGS="--master spark://${SPARK_MASTER_IP}:${SPARK_MASTER_PORT} pyspark-shell"

    echo "spark://${SPARK_MASTER_IP}:${SPARK_MASTER_PORT}" > "$spark_home/${SLURM_JOB_ID}_spark_master"
    echo "Running spark-master on ${SPARK_MASTER_IP}:${SPARK_MASTER_PORT} (webui: ${SPARK_MASTER_WEBUI_PORT})"
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.master.Master \
      --ip  "$SPARK_MASTER_IP" \
      --port "$SPARK_MASTER_PORT" \
      --webui-port "$SPARK_MASTER_WEBUI_PORT" &
    export MASTER_PROC_ID="$!"

    echo "Running spark-worker on $(hostname) to connect to ${SPARK_MASTER_IP}:${SPARK_MASTER_PORT}"
    # Reduce memory and cpu ressource usage of the worker colocated with the master
    export SPARK_WORKER_CORES=$(( $SPARK_WORKER_CORES - $MASTER_RESERVED_CORES ))
    if [ -n "$SLURM_MEM_PER_CPU" ]; then
      export SPARK_DAEMON_MEMORY=$(( $SLURM_MEM_PER_CPU * $SLURM_CPUS_PER_TASK - $MASTER_RESERVED_MEMORY ))m
    else
      export SPARK_DAEMON_MEMORY=$(( $SLURM_MEM_PER_NODE - $MASTER_RESERVED_MEMORY ))m
    fi
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.worker.Worker -h "$SPARK_MASTER_IP" "spark://$SPARK_MASTER_IP:$SPARK_MASTER_PORT" &
    export WORKER_PROC_ID="$!"

    if [ $INSTALL_HAIL -eq 0 ]; then
      echo "Installing hail on top of spark cluster"
      source $SCRIPT_DIR/install-hail.sh
    fi

    trap "clean" EXIT
    trap "sleep 10 && stop $WORKER_PROC_ID && sleep 1 && stop $MASTER_PROC_ID" SIGUSR1

    sleep 10
    if [ $USE_SRUN -eq 0 ]; then
      srun --overlap --export=ALL "$SCRIPT"
    else
      eval "$SCRIPT"
    fi

    # After finishing force the job to exit
    sleep 30
    echo -e "job finished, cleaning up spark cluster."
    scancel --signal=USR1 $SLURM_JOB_ID
    sleep 30
    scancel --signal=USR1 --batch $SLURM_JOB_ID
    echo -e "finished cleaning up child jobs."
else
    export SPARK_MASTER_IP=$(scontrol show hostname $SLURM_NODELIST | head -n 1)
    if [ -z "$IPOIB_DOMAIN" ]; then
      export SPARK_MASTER_HOSTNAME=${SPARK_MASTER_IP/eth/ib}
    else
      export SPARK_MASTER_HOSTNAME="${SPARK_MASTER_IP}.${IPOIB_DOMAIN}"
    fi
    export SPARK_MASTER_IP="$(dig +short +search $SPARK_MASTER_HOSTNAME)"

    export CURRENT_WORKER_HOSTNAME=$(hostname)
        if [ -z "$IPOIB_DOMAIN" ]; then
      export CURRENT_WORKER_HOSTNAME=${CURRENT_WORKER_HOSTNAME/eth/ib}
    else
      export CURRENT_WORKER_HOSTNAME="${CURRENT_WORKER_HOSTNAME}.${IPOIB_DOMAIN}"
    fi
    export CURRENT_WORKER_IP="$(dig +short +search $CURRENT_WORKER_HOSTNAME)"
    
    export TMPDIR="${spark_home}/tmp"
    export SPARK_LOCAL_DIRS="$(mktemp -d)" 
    export TMPDIR="$(mktemp -d)"
    export SPARK_LOCAL_IP="$CURRENT_WORKER_IP"

    echo "Running spark-worker on ${CURRENT_WORKER_HOSTNAME} to connect to ${SPARK_MASTER_IP}:${SPARK_MASTER_PORT}"
    MASTER_NODE="spark://$SPARK_MASTER_IP:$SPARK_MASTER_PORT"
    "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.worker.Worker -h ${CURRENT_WORKER_IP} $MASTER_NODE &
    export WORKER_PROC_ID="$!"
    trap "stop $WORKER_PROC_ID" SIGUSR1
    wait
  fi
fi
