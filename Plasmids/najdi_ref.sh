#!/bin/bash
#SBATCH --job-name=ref
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
#SBATCH --time=24:00:00 
#SBATCH --output=ref_%j.out

source ~/miniconda3/etc/profile.d/conda.sh
conda activate moj_env

# Nastavitve
query_dir="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/iskani_plazmidi/AA001/AH523"
reference_db="/home/nlzoh.si/larbez1/blast_db/nt"
output_dir="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi"
summary_file="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/ref_AH523.txt"

mkdir -p "$output_dir"

for file in "$query_dir"/*.fasta; do
  filename=$(basename "$file" .fasta)
  awk -v prefix="${filename}_" '/^>/ {print ">" prefix substr($0, 2); next} {print}' "$file" > "${file%.fasta}_i.fasta" && mv "${file%.fasta}_i.fasta" "$file" 
done
cat "$query_dir"/*.fasta > "$files"

for fasta_file in "$query_dir"/*.fasta; do
    base_name=$(basename "$fasta_file" .fasta)
    output_file="$output_dir/${base_name}_blast.txt"
    
    echo "Processing $base_name"
    blastn -num_threads 32 -query "$fasta_file" -db "$reference_db" -out "$output_file" -outfmt "6 qseqid sseqid pident length qlen slen" -perc_identity 90 #-max_target_seqs 1 -evalue 1e-5
done

echo -e "Reference\tCount\tAverage_Pident\tAverage_Length" > "$summary_file"
awk '{print $2, $3, $4}' "$output_dir"/*_blast.txt | \
    awk '{count[$1]++; pident[$1]+=$2; length[$1]+=$3;} 
        END {
            for (ref in count) 
                printf "%s\t%d\t%.2f\t%.2f\n", ref, count[ref], pident[ref]/count[ref], length[ref]/count[ref];
        }' | sort -k2,2nr -k3,3nr -k4,4nr >> "$summary_file"

best_reference=$(awk 'NR==2 {print $1}' "$summary_file")

echo "Najboljsa referenca: $best_reference"
conda deactivate