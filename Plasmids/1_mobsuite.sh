#!/bin/bash
#SBATCH --job-name=mob
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=200M
#SBATCH --time=24:00:00 
#SBATCH --output=ref_%j.out

start_time=$(date +%s)


input_file="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/manjkajoci.txt"
search_dir="/home/storage/genomes"
out="mob_results"
mkdir -p ${input_file}/"$out"

output_file="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/poti.txt"
#touch "$output_file"
#> "$output_file"

#while IFS= read -r fasta_name; do
#  find "$search_dir" -type f -name "$fasta_name" -exec echo {} \; >> "$output_file"
#done < "$input_file"

source /home/nejc/miniconda3/bin/activate /home/nejc/miniconda3/envs/mobsuite
while IFS= read -r file; do
	while [ "$(jobs -p | wc -l)" -ge "$SLURM_NTASKS" ]; do
    wait -n
	done 
  ime=$(basename "$file" .fasta)
  srun --ntasks=1 --cpus-per-task=16 mob_recon -n 32 -i "$file" -o "$out"/"$ime" -p "$ime" &
done < "$output_file"
conda deactivate
end_time=$(date +%s)
duration=$((end_time - start_time))
echo $((duration/60))