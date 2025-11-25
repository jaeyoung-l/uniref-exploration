#!/bin/bash
set -euo pipefail

# Complete MMseqs2 filtering pipeline for development/testing
# Runs from scratch starting with FASTA files in data/ directory
WORKDIR="/scratch/s5h/mrpython.s5h/output/uniref-exploration"
cd "$WORKDIR"

echo "=== MMseqs2 Filtering Pipeline ==="
echo "Working directory: $WORKDIR"
echo

# Check for required input files
if [ ! -f "data/query.fasta" ] || [ ! -f "data/target.fasta" ]; then
    echo "ERROR: Required FASTA files not found!"
    echo "Please ensure data/query.fasta and data/target.fasta exist"
    exit 1
fi

# echo "Input files:"
# echo "  - Queries: $(grep -c '^>' data/query.fasta) sequences in data/query.fasta"
# echo "  - Targets: $(grep -c '^>' data/target.fasta) sequences in data/target.fasta"
# echo

# # Step 0: Database creation and splitting
# echo "Step 0: Creating MMseqs2 databases and splitting targets..."

# # Create directories if they don't exist
# mkdir -p mmseqs_db/target_chunks tmp results/{tsv_chunks,per_target,thresholds,final} logs

# # Create query database
# if [ ! -f "mmseqs_db/queryDB" ]; then
#     echo "  Creating query database..."
#     mmseqs createdb data/query.fasta mmseqs_db/queryDB
# else
#     echo "  Query database already exists, skipping..."
# fi

# # Create target database
# if [ ! -f "mmseqs_db/targetDB" ]; then
#     echo "  Creating target database..."
#     mmseqs createdb data/target.fasta mmseqs_db/targetDB
# else
#     echo "  Target database already exists, skipping..."
# fi

# Split target database into chunks
# N_SPLITS=288  # Adjust for production (e.g., 128 for large datasets)
# if [ ! -f "mmseqs_db/target_chunks/target_split_0_${N_SPLITS}" ]; then
#     echo "  Splitting target database into $N_SPLITS chunks..."
#     mmseqs splitdb mmseqs_db/targetDB mmseqs_db/target_chunks/target_split --split $N_SPLITS
# else
#     echo "  Target database already split, skipping..."
# fi

# echo "  Database setup complete!"
# echo

# # Step 1: Run MMseqs searches and per-target scoring on all chunks
# echo "Step 1: Running MMseqs searches and per-target scoring..."

# # ============================================================================
# # PARALLEL EXECUTION SECTION (SLURM BATCH JOBS)
# #
# # Submit batches as SLURM jobs
# # Each batch job processes BATCH_SIZE chunks in parallel
# # ============================================================================

# BATCH_SIZE=32  # Match with SLURM cpus-per-task
# TOTAL_BATCHES=$(( (N_SPLITS + BATCH_SIZE - 1) / BATCH_SIZE ))

# echo "  Submitting $N_SPLITS chunks as $TOTAL_BATCHES SLURM batch jobs (batch size: $BATCH_SIZE)..."

# Submit job array: one job per batch
# JOB_ID=$(sbatch --parsable --array=0-$((TOTAL_BATCHES-1)) \
#     "/home/s5h/mrpython.s5h/projects/uniref-exploration/run_batch_slurm.sh" $BATCH_SIZE $N_SPLITS)

# echo "  Submitted SLURM job array: Job ID $JOB_ID"
# echo "  Number of batch jobs: $TOTAL_BATCHES"
# echo "  Chunks per batch: $BATCH_SIZE"
# echo "  Monitor progress with: squeue -j $JOB_ID"
# echo "  Check logs in: logs/batch_*.out"
# echo

# # Wait for all batch jobs to complete
# echo "  Waiting for all batches to complete..."
# echo "  Logging to: logs/batch_*.out and logs/chunk_*.log"
# echo
# last_completed=0
# while squeue -j $JOB_ID 2>/dev/null | grep -q $JOB_ID; do
#     # Count completed chunks by checking for output files
#     completed=$(ls -1 results/per_target/target_split_*_${N_SPLITS}.tsv 2>/dev/null | wc -l)
#     completed_batches=$(( completed / BATCH_SIZE ))
#     percent=$(( completed * 100 / N_SPLITS ))
    
#     # Show progress update
#     if [ $completed -ne $last_completed ]; then
#         timestamp=$(date '+%Y-%m-%d %H:%M:%S')
#         echo "    [$timestamp] Progress: $completed/$N_SPLITS chunks ($percent%) - ~$completed_batches/$TOTAL_BATCHES batches"
#         last_completed=$completed
#     fi
    
#     sleep 30
# done

# # Final verification
# echo
# echo "  All SLURM jobs finished. Verifying results..."
# completed=$(ls -1 results/per_target/target_split_*_${N_SPLITS}.tsv 2>/dev/null | wc -l)
# if [ $completed -eq $N_SPLITS ]; then
#     echo "  ✓ All $N_SPLITS chunks completed successfully!"
# else
#     echo "  ✗ WARNING: Only $completed/$N_SPLITS chunks completed!"
#     echo "  Check logs in logs/ directory for failed chunks"
# fi
# echo

# Step 2: Compute threshold and generate final flags
echo "Step 2: Computing threshold and generating exclusion flags..."
python3 compute_threshold_and_flags.py
echo

# Step 3: Show summary
echo "=== Pipeline Complete ==="
echo "Results:"
echo "  - Raw TSV chunks: results/tsv_chunks/"
echo "  - Per-target scores: results/per_target/"
echo "  - Final output: results/final/target_scores_and_flags.tsv"
echo "  - Threshold log: results/thresholds/threshold_log.txt"
echo

if [ -f "results/final/target_scores_and_flags.tsv" ]; then
    echo "Final results summary:"
    echo "  Total records: $(tail -n +2 results/final/target_scores_and_flags.tsv | wc -l)"
    echo "  Excluded records: $(tail -n +2 results/final/target_scores_and_flags.tsv | cut -f4 | grep -c True || echo 0)"
    echo
    echo "Threshold log:"
    cat results/thresholds/threshold_log.txt
fi