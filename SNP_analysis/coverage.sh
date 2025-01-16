#!/bin/bash
#SBATCH --job-name=aln
#SBATCH --nodes=1
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=200M
#SBATCH --time=24:00:00

source /home/nlzoh.si/larbez1/miniconda3/etc/profile.d/conda.sh
conda activate cge_env

input_dir=$1
output_dir=$2
ref=$output_dir/ref/*ref.fasta

bwa index $ref
samtools faidx $ref

for file in "$input_dir"/*fasta; do
  while [ "$(jobs -p | wc -l)" -ge "$SLURM_NTASKS" ]; do
		wait -n
	done
  ime=$(basename "$file" .fasta)
  srun --ntasks=1 --cpus-per-task=10 bwa mem $ref $file > $input_dir/${ime}.sam &
done
wait

for file in "$input_dir"/*sam; do
  ime=$(basename "$file" .sam)
  coverage_file=$input_dir/${ime}_"cov_stat.txt"
  samtools view -bS $input_dir/${ime}.sam -o $input_dir/${ime}.bam
  samtools sort -o $input_dir/${ime}.sorted.bam $input_dir/${ime}.bam
  genomeCoverageBed -ibam $input_dir/${ime}.sorted.bam -d > "$coverage_file"
done

reference_length=$(awk '{print $2}' $(ls "$input_dir"/*cov_stat.txt | head -n 1) | sort -n | tail -n 1)

output_file=$output_dir/ref/"alignment_summary.txt"
echo -e "Sample\tAligned_Length\t%\tStd" > "$output_file"
for file in "$input_dir"/*cov_stat.txt; do
    sample=$(basename "$file" _cov_stat.txt)
    aligned_length=$(awk '$3 > 0 {count++} END {print count}' "$file")
    std=$(awk '{sum+=$3; sumsq+=$3*$3} END {print sqrt(sumsq/NR - (sum/NR)**2)}' "$file")
    percentage_aligned=$(awk -v aligned="$aligned_length" -v ref="$reference_length" 'BEGIN {printf "%.4f", (aligned / ref) * 100}')
    echo -e "$sample\t$aligned_length\t$percentage_aligned%\t$std" >> "$output_file"
done

paste "$input_dir"/*cov_stat.txt | awk '{
    pos=$2; all_positive=1;
    for (i=3; i<=NF; i+=3) if ($i <= 0) all_positive=0;
    if (all_positive) print pos;
}' > "$input_dir"/shared_positions.txt

shared_count=$(wc -l < "$input_dir"/shared_positions.txt)
percentage=$(awk "BEGIN {print ($shared_count / $reference_length * 100)}")

echo -e "\nSummary:" >> "$output_file"
echo -e "Total Reference Length:\t$reference_length" >> "$output_file"
echo -e "Positions Aligned in All Samples:\t$shared_count" >> "$output_file"
echo -e "Percentage of All-Aligned Positions:\t$percentage%" >> "$output_file"

rm $input_dir/*.sam $input_dir/*.bam $input_dir/*.txt
conda deactivate