#!/bin/bash
set -e
user="larbez1@nlzoh.si"

start_time=$(date +%s)
#################################### ARGUMENTI ###################################################
while getopts "i:o:ref:list:h" opt; do
  case $opt in
    i) INPUT_DIR=$OPTARG ;;
    o) OUTPUT_DIR=$OPTARG ;;
    ref) REF_FILE=$OPTARG ;;
    list) LIST=$OPTARG ;;
    h) 
      echo "Uporaba: $0 -i <input_directory> [-o <output_directory>] [-ref <ref_fasta_file>] [-list <text_file>]"
      echo "-i    Vhodna mapa"
      echo "-o    Izhodna mapa (opcijsko)"
      echo "-ref  Referenca v fasta obliki (opcijsko)"
      echo "-list Seznam datotek (opcijsko)"
      exit 0
      ;;
  esac
done

# Preveri argumente
if [ -z "${INPUT_DIR}" ]; then
  if [ -z "${LIST}" ]; then
    echo -e "\nError: Manjka vhodna mapa (-i) oziroma seznam z imeni datotek (-list).\n"
    "/home/storage/finished_projects/LaraB/skripte/SNP/SNP_analiza_genome_fasta.sh" -h
    echo -e "\n"
    exit 1
  fi
else
  echo "Vhodni podatki: $INPUT_DIR"
fi

if [ -z "${OUTPUT_DIR}" ]; then
  CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
  OUTPUT_DIR="./Rezultati_${CURRENT_DATE}"
fi
mkdir -p "${OUTPUT_DIR}"
echo "Shranjuje v: $OUTPUT_DIR"

if [ -n "${LIST}" ]; then
  SEARCH_DIR="${INPUT_DIR:-/home/storage/genomes}"
  TARGET_DIR="${OUTPUT_DIR}/files"
  mkdir -p "${TARGET_DIR}"

  while IFS= read -r file; do
    SOURCE_FILE=$(find "${SEARCH_DIR}" -type f -iname "${file}.fasta" | head -n 1)

    if [ -f "${SOURCE_FILE}" ]; then
      cp "${SOURCE_FILE}" "${TARGET_DIR}/."
      echo "Prenesena datoteka: ${file}"
    else
      echo -e "\nError: Datoteka ${file} ni bila najdena v ${SEARCH_DIR}."
    fi
  done < "${LIST}"
  INPUT_DIR=$TARGET_DIR
  echo "Vhodni podatki so v novi mapi: $TARGET_DIR"
fi

#################################### FUNKCIJE ###################################################
# Funkcija za èakanje na zakljuèek naloge
wait_for_job() {
  local job_name=$1
  local user=$2
  while squeue --noheader --name="${job_name}" --user="${user}" | grep -q "${job_name}"; do
    sleep 60
  done
}

# Funkcija za filtriranje datotek
filter_files() {
  local input_file=$1
  local threshold=80.0000 
  local dir_remove=$2
  
  local already_filtered=true
  while IFS=$'\t' read -r sample aligned_length percent std; do
    if [[ "$sample" != "Sample" && "$sample" != "Summary:" ]]; then
      if [ -f "${INPUT_DIR}/${sample}.fasta" ]; then
        already_filtered=false
        break
      fi
    fi
  done < "$input_file"

  if $already_filtered; then
    echo -e "\nFiltriranje ni potrebno."
    return 0
  fi

  while IFS=$'\t' read -r sample aligned_length percent std; do
    if [[ "$sample" != "Sample" && "$sample" != "Summary:" ]]; then
      clean_percent=$(echo "$percent" | sed 's/%//g' | sed 's/[[:space:]]//g')
      if (( $(echo "$clean_percent < $threshold" | bc -l) )); then
        mkdir -p "${dir_remove}"
        mv "${INPUT_DIR}/${sample}.fasta" "${dir_remove}/."
      fi
    fi
  done < "$input_file"
}

#################################### SNP ANALIZA #################################################
########## JOB 1: REF
job_name="ref"
REF_DIR="${OUTPUT_DIR}/ref"
mkdir -p "${REF_DIR}"

if [ -n "${REF_FILE}" ]; then
  if [[ "${REF_FILE}" == *.fasta ]]; then
    cp "${REF_FILE}" "${REF_DIR}/$(basename "${REF_FILE}" .fasta)_ref.fasta"
  else
    echo "Error: Referenca ni v FASTA obliki."
    exit 1
  fi
elif [ -f "${REF_DIR}"/*ref.fasta ]; then
  echo -e "Najdena referenca: $(ls "${REF_DIR}"/*ref.fasta)"
else
  first_file=$(find "${INPUT_DIR}" -type f -name "*.fasta" | head -n 1)
  file_size=$(stat --format="%s" "${first_file}")
  if (( file_size > 1000000 )); then
    sbatch /home/storage/finished_projects/LaraB/skripte/SNP/najdi_ref_kmerfinder.sh "${INPUT_DIR}" "${OUTPUT_DIR}"
  else
    sbatch /home/storage/finished_projects/LaraB/skripte/SNP/najdi_ref_blast.sh "${INPUT_DIR}" "${OUTPUT_DIR}"
  fi
  wait_for_job "${job_name}" "$user"
  wait
  if [ ! -f "${REF_DIR}"/*ref.fasta ]; then
    echo "Error: Referenca ni bila najdena."
    exit 1
  fi
fi

########## JOB 2: PORAVNAVA NA REF
job_name2="aln"
alignment_summary="${REF_DIR}/alignment_summary.txt"

if [ ! -f "${alignment_summary}" ]; then
  sbatch /home/storage/finished_projects/LaraB/skripte/SNP/coverage.sh "${INPUT_DIR}" "${OUTPUT_DIR}"
  wait_for_job "${job_name2}" "$user"
fi

# Filtriranje podatkov glede na odstotek poravnave <80%
#dodaj možnost za filtriranje
if [ -f "${alignment_summary}" ]; then
  filter_files "${alignment_summary}" "${INPUT_DIR}/removed"
else
  echo "Error: Datoteka ${alignment_summary} ne obstaja."
  exit 1
fi

########## JOB 3: SNP
job_name3="snp"
if ls "${INPUT_DIR}"/*.fasta &>/dev/null; then
  sbatch /home/storage/finished_projects/LaraB/skripte/SNP/snp.sh "${INPUT_DIR}" "${OUTPUT_DIR}"
  wait_for_job "${job_name3}" "$user"
else
  echo -e "\nError: Vse datoteke imajo poravnavo na referenco pod 80%. Analiza je prekinjena. \nPreveri datoteko za drugo referenco: ${REF_DIR}/ref/temp.txt \nin \nmapo:$INPUT_DIR"
  exit 1
fi

if [ -f $OUTPUT_DIR/gubbins/*clean.core.fasta ]; then
  cp $OUTPUT_DIR/gubbins/*clean.core.fasta $OUTPUT_DIR/.
  echo -e "\nSNP analiza je koncana.\nCore SNP poravnava je shranjena v $OUTPUT_DIR/*clean.core.fasta"
  if [ -f $OUTPUT_DIR/gubbins/filtered_out.txt ]; then
    echo -e "\nGubbins je iz analize odstranil datoteke, pri katerih manjka vec kot 25% sekvence, seznam je shranjen v $OUTPUT_DIR/gubbins/filtered_out.txt."
  fi
else
  echo -e "\nError: Koncna datoteka $OUTPUT_DIR/gubbins/*clean.core.fasta ni bila generirana. \nPreveri podatke v mapah: \n$OUTPUT_DIR/gubbins \nin \n$OUTPUT_DIR/snippy"
fi

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Trajanje: $((duration/3600))h $(((duration/60)%60))min"
