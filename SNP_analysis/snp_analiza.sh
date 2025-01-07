#!/bin/bash
#SBATCH --job-name=snp
#SBATCH --nodes=1
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=200M
#SBATCH --time=48:00:00

start_time=$(date +%s)
source ~/miniconda3/etc/profile.d/conda.sh

dir="/home/storage/finished_projects/LaraB/rezultati/ZZV-C.diff"
INPUT_DIRS=("150" "255-258") 
OUTPUT_DIRS=("r150" "r255-258")

# Iteracija skozi mape
for i in "${!INPUT_DIRS[@]}"; do
  INPUT="$dir"/fastq/${INPUT_DIRS[i]}
  OUTPUT="$dir"/rezultati/${OUTPUT_DIRS[i]}
  mkdir -p "$OUTPUT"
  
  echo "Obdelujem mapo $INPUT in shranjujem rezultate v $OUTPUT"
  echo "Išèem referenco"
  NAME=$(basename $INPUT)
  mkdir -p $OUTPUT/{snippy,gubbins}
  conda activate cge_env
  for file in $INPUT/*R1*; do
    while [ "$(jobs -p | wc -l)" -ge "$SLURM_NTASKS" ]; do
  		wait -n
  	done
    SAMPLE=$(basename $file _R1.trim.fastq.gz)
    srun --ntasks=1 --cpus-per-task=10 kmerfinder.py -i ${file%R*}* -o $OUTPUT/ref/$SAMPLE -db /home/nlzoh.si/larbez1/CGE/KmerFinder_DB/db/bacteria/bacteria.ATG -q
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
  rm -rf $OUTPUT/ref
  conda deactivate
  wait
  
  REF=$OUTPUT/*_ref.fasta
  conda activate snp_env
  echo "Snippy"
  for QUERY in $INPUT/*R1.trim.fastq.gz; do
    while [ "$(jobs -p | wc -l)" -ge "$SLURM_NTASKS" ]; do
  		wait -n
  	done
    SAMPLE=$(basename $QUERY _R1.trim.fastq.gz)
    srun --ntasks=1 --cpus-per-task=10 snippy --cpus 10 -R1 $QUERY -R2 ${QUERY%R1.trim.fastq.gz}R2.trim.fastq.gz --outdir $OUTPUT/snippy/$SAMPLE --reference $REF --force --cleanup &
  done
  wait
  
  echo "Snippy - core"
  cd $OUTPUT/snippy/
  snippy-core --ref $REF $OUTPUT/snippy/*
  sed '/^>Reference$/,/^>/ {/^>Reference$/d; /^>/!d}' $OUTPUT/snippy/core.full.aln > $OUTPUT/snippy/core_no_ref.full.aln
  snippy-clean_full_aln $OUTPUT/snippy/core_no_ref.full.aln > $OUTPUT/snippy/clean.full.aln
  
  echo "Gubbins"
  cd $OUTPUT/gubbins/
  run_gubbins.py --prefix gubb $OUTPUT/snippy/clean.full.aln
  snp-sites -c -o $OUTPUT/gubbins/${NAME}_clean.core.fasta $OUTPUT/gubbins/gubb.filtered_polymorphic_sites.fasta
  cp $OUTPUT/gubbins/*clean.core.fasta $dir/.
  
  #iqtree -s $OUTPUT/gubbins/*clean.core.fasta -m GRT+G -nt AUTO --redo --prefix tree --keep-ident --alrt 1000 --ufboot 1000 
done

conda deactivate

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Trajanje: $((duration/3600))h $((duration/60))min"