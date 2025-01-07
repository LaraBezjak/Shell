#!/bin/bash

imena_datotek=$1
mapa=$2

out=${mapa}/reference
mkdir -p $out

[ -f "$output_file" ] && rm "$output_file"

for i in "${!imena_datotek[@]}"; do
  find ${mapa}/mob_results -type f -name "*.contig_report.txt" | while read -r file; do
      awk -v beseda=${imena_datotek[i]} '
      BEGIN {OFS="\t"} 
      $3 == beseda {print $1, $20}
      ' "$file" >> $out/ref_"${iskana_beseda}.txt
  done
done

most_common=$(awk -F'\t' '{print $2}' $out/ref_"${iskana_beseda}.txt | sort | uniq -c | sort -nr | head -n 1 | awk '{print $2}')
if [ -z "$most_common" ]; then
  echo "Referenca ni bila najdena."
else
  echo "Najpogostejsa referenca: $most_common"
  efetch -db nucleotide -id $most_common -format fasta > out/${most_common}_ref.fasta
  #rm -rf $out/ref*txt
fi