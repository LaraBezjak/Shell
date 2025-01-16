#!/bin/bash
#SBATCH --job-name=ref
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=5G
#SBATCH --time=24:00:00

start_time=$(date +%s)
source /home/nlzoh.si/larbez1/miniconda3/etc/profile.d/conda.sh
conda activate cge_env

INPUT=$1
OUTPUT=$2
mkdir -p $OUTPUT/ref

for file in $INPUT/*fasta; do
  while [ "$(jobs -p | wc -l)" -ge "$SLURM_NTASKS" ]; do
		wait -n
	done
  SAMPLE=$(basename $file .fasta)
  srun --ntasks=1 --cpus-per-task=10 blastn -num_threads 10 -query $file -db nt -outfmt "7 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen" -out $OUTPUT/ref/${SAMPLE}.tsv -perc_identity 90 -max_target_seqs 5 &
done
wait

temp_file=$OUTPUT/ref/temp.txt
for file in $OUTPUT/ref/*.tsv; do
  awk -F'\t' '
  !/^#/ {
    alignment_percentage = $NF
    if (alignment_percentage > max_alignment) {
      max_alignment = alignment_percentage
      lines = $0 "\n"
    } else if (alignment_percentage == max_alignment) {
      lines = lines $0 "\n"
    }
  }
  END {
    printf "%s", lines
  }' "$file" >> "$temp_file"
done

most_common=$(awk -F'\t' '{print $2}' "$temp_file" | sort | uniq -c | sort -nr | head -n 1 | awk '{print $2}')
if [ -z "$most_common" ]; then
  echo "Referenca ni bila najdena."
  rm -rf $OUTPUT/ref/*tsv
else
  echo "Najpogostejsa referenca: $most_common"
  efetch -db nucleotide -id $most_common -format fasta > $OUTPUT/ref/${most_common}_ref.fasta
  rm -rf $OUTPUT/ref/*tsv
fi

conda deactivate
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Trajanje: $((duration/60))min"