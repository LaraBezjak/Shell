#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh

input_txt=$1	#.txt names of fasta files
output=${dirname $input_txt}
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
out_dir="$output/Rezultati_$timestamp"
mkdir -p "$out_dir"

while read -r filename; do
  if [[ -z $filename ]]; then
    continue
  fi
  file_path=$(find /home/storage/genomes -type f -name ${filename}* 2>/dev/null | head -n 1)
  if [[ -z $file_path ]]; then
    echo "Datoteka '$filename' ni bila najdena."
    continue
  fi
  echo "Najdena datoteka: $file_path"
  conda activate amr_env
  amrfinder -n "$file_path" -o $out_dir/"${filename}.txt" #--plus
  conda deactivate
  conda activate moj_env
  python /home/nlzoh.si/larbez1/miniconda3/envs/moj_env/lib/python3.12/site-packages/resfinder/run_resfinder.py -ifa "$file_path" -o $out_dir/"${filename}_r" -l 0.6 -t 0.8 --acquired
  mv $out_dir/${filename}_r/ResFinder_results_tab.txt $out_dir/${filename}_r.txt
  rm -rf $out_dir/${filename}_r
  conda deactivate
done < "$input_txt"

python txt_to_excel.py $out_dir  #add path to python file
