#!/bin/bash

input_file="iskani.txt"
search_dir="/home/storage/genomes"
out=""
imena_plazmidov=""
novi_out="$out/iskani_plazmidi"

sbatch /home/storage/finished_projects/LaraB/skripte/Plazmidi/1_mobsuite.sh $input_file $search_dir $out
job_id=$(squeue --name=mob --noheader --format=%i)
if [[ -n $job_id ]]; then
    echo "Èakam, da se naloga 1_mobsuite.sh (ID: $job_id) zakljuèi..."
    while squeue --job "$job_id" &> /dev/null; do
        sleep 600
    done
fi
./home/storage/finished_projects/LaraB/skripte/Plazmidi/2_premik_plazmidov.sh $imena_plazmidov $out $novi_out
./home/storage/finished_projects/LaraB/skripte/Plazmidi/3_najdi_ref_mobsuite.sh $imena_plazmidov $out
