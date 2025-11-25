#!/bin/bash
set -euo pipefail

# Single chunk MMseqs search and reduction pipeline
# Usage: ./run_search.sh <chunk_id> [n_splits]
# Example: ./run_search.sh 0 4

if [ $# -lt 1 ]; then
    echo "Usage: $0 <chunk_id> [n_splits]"
    echo "Example: $0 0 4"
    exit 1
fi

CHUNK_ID=$1
N_SPLITS=${2:-4}

WORKDIR="/scratch/s5h/mrpython.s5h/output/uniref-exploration"
cd "$WORKDIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

CHUNK_NAME="target_split_${CHUNK_ID}_${N_SPLITS}"
QUERY_DB="$WORKDIR/mmseqs_db/queryDB"
TARGET_CHUNK_DB="$WORKDIR/mmseqs_db/target_chunks/${CHUNK_NAME}"
RESULT_DB="$WORKDIR/mmseqs_db/target_chunks/${CHUNK_NAME}_res"
TMP_DIR="$WORKDIR/tmp/${CHUNK_NAME}"
TSV_OUT="$WORKDIR/results/tsv_chunks/${CHUNK_NAME}.tsv"
SCORE_OUT="$WORKDIR/results/per_target/${CHUNK_NAME}.tsv"

# log "=========================================="
# log "Processing chunk $CHUNK_ID/$((N_SPLITS-1)): $CHUNK_NAME"
# log "PID: $$"
# log "=========================================="

# # Check if chunk database exists
# if [ ! -f "$TARGET_CHUNK_DB" ]; then
#     log "ERROR: Target chunk database not found: $TARGET_CHUNK_DB"
#     log "Make sure the database has been split properly."
#     exit 1
# fi

# mkdir -p "$TMP_DIR"
# mkdir -p "$(dirname "$TSV_OUT")"
# mkdir -p "$(dirname "$SCORE_OUT")"

# log "Step 1: Running MMseqs2 search..."
start_time=$(date +%s)
# # Run search: queries vs this target chunk
# mmseqs search "$QUERY_DB" "$TARGET_CHUNK_DB" "$RESULT_DB" "$TMP_DIR" \
#   --alignment-mode 3 \
#   -s 7.0 \
#   -e 1e5 \
#   --min-seq-id 0.0 \
#   --cov-mode 0 -c 0.3 \
#   --max-seqs 200 \
#   --threads 1

search_time=$(( $(date +%s) - start_time ))
# log "  MMseqs2 search completed in ${search_time}s"

# log "Step 2: Converting alignments to TSV..."
# # Convert alignments to TSV with continuous metrics
# mmseqs convertalis "$QUERY_DB" "$TARGET_CHUNK_DB" "$RESULT_DB" "$TSV_OUT" \
#   --format-mode 4 \
#   --format-output "query,target,fident,qcov,tcov,alnlen,bits"

convert_time=$(( $(date +%s) - start_time - search_time ))
log "  Conversion completed in ${convert_time}s"

log "Step 3: Computing per-target scores..."
# Reduce TSV to per-target scores using modified script
python3 /home/s5h/mrpython.s5h/projects/uniref-exploration/reduce_chunk_to_per_target.py "$TSV_OUT" "$SCORE_OUT"

score_time=$(( $(date +%s) - start_time - search_time - convert_time ))
log "  Scoring completed in ${score_time}s"

log "Step 4: Cleaning up intermediate files..."
# Clean up intermediate files to save space
rm -rf "$RESULT_DB"* "$TMP_DIR"

total_time=$(( $(date +%s) - start_time ))
log "=========================================="
log "Chunk $CHUNK_ID completed successfully!"
log "  Total time: ${total_time}s (search: ${search_time}s, convert: ${convert_time}s, score: ${score_time}s)"
log "  TSV output: $TSV_OUT"
log "  Score output: $SCORE_OUT"
log "=========================================="