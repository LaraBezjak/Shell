#!/bin/bash
#SBATCH --job-name=ref
#SBATCH --nodes=1
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=300M
#SBATCH --time=48:00:00

start_time=$(date +%s)
source /home/nlzoh.si/larbez1/miniconda3/etc/profile.d/conda.sh
conda activate cge_env

INPUT=$1
OUTPUT=$2

for file in $INPUT/*fasta; do
  while [ "$(jobs -p | wc -l)" -ge "$SLURM_NTASKS" ]; do
		wait -n
	done
  SAMPLE=$(basename $file .fasta)
  srun --ntasks=1 --cpus-per-task=10 kmerfinder.py -i $file -o $OUTPUT/ref/$SAMPLE -db /home/nlzoh.si/larbez1/CGE/KmerFinder_DB/db/bacteria/bacteria.ATG -q &
done
wait

temp_file=$OUTPUT/ref/temp.txt
for file in $OUTPUT/ref/*/results.spa; do
  best_nz=$(awk -F'\t' '/^NZ_/ {if ($3 > max) {max=$3; line=$1}} END {print line}' "$file")
  echo "$best_nz" >> "$temp_file"
done

most_common=$(sort "$temp_file" | uniq -c | sort -nr | head -n 1 | awk '{print $2}')
id=${most_common#NZ_}
if [ -z "$id" ]; then
  echo "Referenca ni bila najdena. Preglej $OUTPUT/ref/temp.txt"
  find "$OUTPUT/ref/" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
else
  echo "Najpogostejsa referenca: $most_common"
  efetch -db nucleotide -id $id -format fasta > $OUTPUT/ref/${id}_ref.fasta
  find "$OUTPUT/ref/" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
fi

conda deactivate
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Trajanje: $((duration/60))min"