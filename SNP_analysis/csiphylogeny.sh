#!/bin/bash
#SBATCH --job-name=csi
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=400M
#SBATCH --time=48:00:00

INPUT_DIR="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/iskani_plazmidi/AH539"
REF="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/ref/CP018717_AH539.fasta"
OUTPUT=$INPUT_DIR/rezultati/csi_phylo
mkdir -p $OUTPUT

source ~/miniconda3/etc/profile.d/conda.sh
conda activate cge_env

python /home/nlzoh.si/larbez1/CGE/CSIPhylogeny/csi_phylogeny.py -i $INPUT_DIR/*fasta -r $REF -o $OUTPUT

conda deactivate
wait

rm -rf cromwell* slurm*