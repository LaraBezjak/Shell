#!/bin/bash

imena_datotek="AA001 AA002 AA405 AA621 AA739 AB082 AC163 AC314 AE271 AE581 AF515"
pot="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/plazmidi_secondary"
out="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi/iskani_plazmidi"
mkdir -p $out

for ime in $imena_datotek; do
  nova_mapa="$out"/"$ime"
  if [ ! -d "$nova_mapa" ]; then
    mkdir "$nova_mapa"
  fi
  find "$pot" -type f -name "$ime" -exec cp {} "$nova_mapa/" \;
done


#out="/home/storage/finished_projects/LaraB/rezultati/AMR_plazmidi"
#for f in "$out"/plazmidi/plasmid_AA002.fasta/plasmid_AA002.fastaplasmidplasmid_AA002.fasta; do
#    basename=$(echo "$f" | sed 's/.plasmid_AA002.fastaplasmid_\([^\/]plasmid_AA002.fasta\)\.fasta/\1/')
#    mkdir -p "$out/$basename"
#    cp -r "$f" "$out/$basename"/.
#done