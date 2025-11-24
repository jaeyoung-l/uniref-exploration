#!/bin/bash
#SBATCH --job-name=mmseqs_batch
#SBATCH --output=/scratch/s5h/mrpython.s5h/output/uniref-exploration/logs/batch_%a.out
#SBATCH --error=/scratch/s5h/mrpython.s5h/output/uniref-exploration/logs/batch_%a.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=256G
#SBATCH --time=04:00:00

# SLURM job script for running one batch of MMseqs2 search chunks
# Each batch processes BATCH_SIZE chunks in parallel
# Usage: sbatch --array=0-N run_batch_slurm.sh <batch_size> <n_splits>

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: sbatch --array=0-N run_batch_slurm.sh <batch_size> <n_splits>"
    echo "Example: sbatch --array=0-8 run_batch_slurm.sh 32 288"
    exit 1
fi

BATCH_SIZE=$1
N_SPLITS=$2
BATCH_NUM=${SLURM_ARRAY_TASK_ID}

WORKDIR="/scratch/s5h/mrpython.s5h/output/uniref-exploration"
cd "$WORKDIR"

# Calculate chunk range for this batch
batch_start=$((BATCH_NUM * BATCH_SIZE))
batch_end=$((batch_start + BATCH_SIZE - 1))

# Don't exceed N_SPLITS
if [ $batch_end -ge $N_SPLITS ]; then
    batch_end=$((N_SPLITS - 1))
fi

batch_size=$((batch_end - batch_start + 1))

echo "=========================================="
echo "Batch $BATCH_NUM: Processing chunks $batch_start-$batch_end ($batch_size chunks)"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "=========================================="

# Launch all chunks in this batch in parallel
for chunk_id in $(seq $batch_start $batch_end); do
    echo "  Launching chunk $chunk_id..."
    "/home/s5h/mrpython.s5h/projects/uniref-exploration/run_search.sh" $chunk_id $N_SPLITS &
done

# Wait for all chunks in this batch to complete
echo "  Waiting for all $batch_size chunks to complete..."
wait

echo "=========================================="
echo "Batch $BATCH_NUM completed successfully!"
echo "  Processed chunks: $batch_start-$batch_end"
echo "=========================================="

