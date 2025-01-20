#!/bin/bash
#SBATCH --job-name=csi
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=400M
#SBATCH --time=48:00:00

INPUT_DIR=$1
REF=$2

OUTPUT=$INPUT_DIR/csi_phylo_results
mkdir -p $OUTPUT

source ~/miniconda3/etc/profile.d/conda.sh
conda activate cge_env

python /home/nlzoh.si/larbez1/CGE/CSIPhylogeny/csi_phylogeny.py -i $INPUT_DIR/*fasta -r $REF -o $OUTPUT

conda deactivate
wait
rm -rf cromwell* slurm*
