#!/bin/bash
#SBATCH --job-name=ref
#SBATCH --nodes=1
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=300M
#SBATCH --time=48:00:00

start_time=$(date +%s)
source ~/miniconda3/etc/profile.d/conda.sh
conda activate cge_env

INPUT=/home/storage/finished_projects/LaraB/rezultati/ZZV-C.diff/fastq/033 #$1
OUTPUT=/home/storage/finished_projects/LaraB/rezultati/ZZV-C.diff/rezultati/r033 #$2

for file in $INPUT/*R1*; do
  while [ "$(jobs -p | wc -l)" -ge "$SLURM_NTASKS" ]; do
		wait -n
	done
  SAMPLE=$(basename $file _R1.trim.fastq.gz)
  srun --ntasks=1 --cpus-per-task=10 kmerfinder.py -i ${file%R*}* -o $OUTPUT/ref/$SAMPLE -db /home/nlzoh.si/larbez1/CGE/KmerFinder_DB/db/bacteria/bacteria.ATG -q &
done
wait

temp_file=$OUTPUT/ref/temp.txt
for file in $OUTPUT/ref/*/results.spa; do
  best_nz=$(awk -F'\t' '/^NZ_/ {if ($3 > max) {max=$3; line=$1}} END {print line}' "$file")
  echo "$best_nz" >> "$temp_file"
done

most_common=$(sort "$temp_file" | uniq -c | sort -nr | head -n 1 | awk '{print $2}')
id=${most_common#NZ_}
efetch -db nucleotide -id $id -format fasta > $OUTPUT/${id}_ref.fasta
#echo "Najpogostejsa referenca: $most_common" > $OUTPUT/ref.txt

rm -rf $OUTPUT/ref

conda deactivate
end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Trajanje: $((duration/60))min"