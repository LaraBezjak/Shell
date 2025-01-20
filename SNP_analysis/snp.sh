#!/bin/bash
#SBATCH --job-name=snp
#SBATCH --nodes=1
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=200M
#SBATCH --time=48:00:00
#SBATCH --output=snp_%j.out

start_time=$(date +%s)
source /home/nlzoh.si/larbez1/miniconda3/etc/profile.d/conda.sh
conda activate snp_env

squeue --format="%.i %.j" | while read -r job_id job_name; do
    if [[ "$job_name" == "snp" ]]; then
    	 input_file=$(scontrol show job $job_id | grep StdOut)
    fi
done

INPUT_DIR=$1
OUTPUT_DIR=$2
REF=$OUTPUT_DIR/ref/*_ref.fasta
NAME=$(basename $OUTPUT_DIR)
mkdir -p $OUTPUT_DIR/{snippy,gubbins}

echo "Snippy"
for FILE in ${INPUT_DIR}/*fasta; do
  while [ "$(jobs -p | wc -l)" -ge "$SLURM_NTASKS" ]; do
		wait -n
	done
  SAMPLE=$(basename $FILE .fasta)
  srun --ntasks=1 --cpus-per-task=10 snippy --cpus 10 --ctgs $FILE --outdir $OUTPUT_DIR/snippy/$SAMPLE --reference $REF --force --cleanup &
	#-R1 $QUERY -R2 ${QUERY%R1.trim.fastq.gz}R2.trim.fastq.gz
done
wait

echo "Snippy - core"
cd $OUTPUT_DIR/snippy/
snippy-core --ref $REF $OUTPUT_DIR/snippy/*
sed '/^>Reference$/,/^>/ {/^>Reference$/d; /^>/!d}' $OUTPUT_DIR/snippy/core.full.aln > $OUTPUT_DIR/snippy/core_no_ref.full.aln
snippy-clean_full_aln $OUTPUT_DIR/snippy/core_no_ref.full.aln > $OUTPUT_DIR/snippy/clean.full.aln
rm $OUTPUT_DIR/snippy/core_no_ref.full.aln

echo "Gubbins"
cd $OUTPUT_DIR/gubbins/
srun --ntasks=1 --cpus-per-task=10 run_gubbins.py -c 10 --prefix gubb $OUTPUT_DIR/snippy/clean.full.aln
wait
snp-sites -c -o $OUTPUT_DIR/gubbins/${NAME}_clean.core.fasta $OUTPUT_DIR/gubbins/gubb.filtered_polymorphic_sites.fasta

if grep -q "Excluded sequence" "$input_file"; then
    awk '/Excluded sequence\.\.\./,/\.{3}done\./' "$input_file" > "$OUTPUT_DIR/gubbins/filtered_out.txt"
fi

#iqtree -s $OUTPUT_DIR/gubbins/*clean.core.fasta -m GRT+G -nt AUTO --redo --prefix tree --keep-ident --alrt 1000 --ufboot 1000
conda deactivate

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Trajanje: $((duration/3600))h $((duration/60))min"