#!/bin/bash
#SBATCH --job-name=ani          
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=100M     
#SBATCH --time=24:00:00
#SBATCH --output=%j.out

start_time=$(date +%s)
source ~/miniconda3/etc/profile.d/conda.sh
conda activate moj_env

parent_directory="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/iskani_plazmidi/AA002"
for subdir in "$parent_directory"/*; do
  average_nucleotide_identity.py -i "$subdir" -o "$subdir/ANIm" -m ANIm -g --gformat png
done

conda deactivate
end_time=$(date +%s)
duration=$((end_time - start_time))
echo $((duration/60))
