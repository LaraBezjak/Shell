#!/bin/bash
set -e
user="larbez1@nlzoh.si"
start_time=$(date +%s)
#################################### PATHS #######################################################
REF_KMER="/home/storage/finished_projects/LaraB/skripte/SNP/SNPfasta/najdi_ref_kmerfinder.sh"
REF_BLASTN="/home/storage/finished_projects/LaraB/skripte/SNP/SNPfasta/najdi_ref_blast.sh"
COV="/home/storage/finished_projects/LaraB/skripte/SNP/SNPfasta/coverage.sh"
SNP="/home/storage/finished_projects/LaraB/skripte/SNP/SNPfasta/snp.sh"
#################################### ARGUMENTS ###################################################
FILTER=False  # Default value for FILTER
while getopts "i:o:r:l:f:h" opt; do
  case $opt in
    i) INPUT_DIR=$OPTARG ;;
    o) OUTPUT_DIR=$OPTARG ;;
    r) REF_FILE=$OPTARG ;;
    l) LIST=$OPTARG ;;
    f) FILTER=$OPTARG ;;
    h)
      echo -e "\nUsage: $0 -i <input_directory> [-o <output_directory>] [-r <ref_fasta_file>] [-l <text_file>] [-f <filter>] [-h]"
      echo "Required:"
      echo -e "-i    Input directory \nOR"
      echo -e "-l    List of files (optional) \n"
      echo "Optional:"
      echo "-o    Output directory (optional)"
      echo "-r    Reference in FASTA format (optional)"
      echo "-f    Filter files with less than 80% alignment to the reference (default: False)"
      echo "-h    Show this help message"
      exit 0
      ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

# Check arguments
if [ -z "${INPUT_DIR}" ]; then
  if [ -z "${LIST}" ]; then
    echo -e "\nError: Missing input directory (-i) or file list (-list).\n"
    "/home/storage/finished_projects/LaraB/skripte/SNP/SNP_analysis_fasta.sh" -h
    echo -e "\n"
    exit 1
  fi
else
  echo "Input: $INPUT_DIR"
fi

if [ -z "${OUTPUT_DIR}" ]; then
  CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
  OUTPUT_DIR="./SNP_results_${CURRENT_DATE}"
fi
mkdir -p "${OUTPUT_DIR}"
echo "Output: $OUTPUT_DIR"

if [ -n "${LIST}" ]; then
  SEARCH_DIR="${INPUT_DIR:-/home/storage/genomes}"
  TARGET_DIR="${OUTPUT_DIR}/files"
  mkdir -p "${TARGET_DIR}"

  while IFS= read -r file; do
    SOURCE_FILE=$(find "${SEARCH_DIR}" -type f -iname "${file}.fasta" | head -n 1)

    if [ -f "${SOURCE_FILE}" ]; then
      cp "${SOURCE_FILE}" "${TARGET_DIR}/."
      echo "Transferred file: ${file}"
    else
      echo -e "\nError: File ${file} was not found in ${SEARCH_DIR}."
    fi
  done < "${LIST}"
  INPUT_DIR=$TARGET_DIR
  echo "Input is in new dir: $TARGET_DIR"
fi
#################################### FUNCTIONS ###################################################
# Function to wait for job completion
wait_for_job() {
  local job_name=$1
  local user=$2
  while squeue --noheader --name="${job_name}" --user="${user}" | grep -q "${job_name}"; do
    sleep 60
  done
}

# Function to filter files
filter_files() {
  local input_file=$1
  local threshold=80.0000
  local dir_remove=$2
  
  while IFS=$'\t' read -r sample aligned_length percent std; do
    [[ "$sample" == "Summary:" ]] && break

    if [[ "$sample" != "Sample" && -n "$sample" ]]; then
      clean_percent=$(echo "$percent" | sed 's/%//g' | sed 's/[[:space:]]//g')
      if (( $(echo "$clean_percent < $threshold" | bc -l) )); then
        mkdir -p "${dir_remove}"
        mv "${INPUT_DIR}/${sample}.fasta" "${dir_remove}/."
        echo "File ${INPUT_DIR}/${sample}.fasta was moved to ${dir_remove}/."
      fi
    fi
  done < "$input_file"
}
#################################### SNP ANALYSIS #################################################
########## JOB 1: REF
echo -e "\n1: FINDING REFERENCE"
job_name="ref"
REF_DIR="${OUTPUT_DIR}/ref"
mkdir -p "${REF_DIR}"

if [ -n "${REF_FILE}" ]; then
  if [[ "${REF_FILE}" == *.fasta ]]; then
    cp "${REF_FILE}" "${REF_DIR}/$(basename "${REF_FILE}" .fasta)_ref.fasta"
  else
    echo "Error: Reference is not in FASTA format."
    exit 1
  fi
elif [ -f "${REF_DIR}"/*ref.fasta ]; then
  echo -e "Reference found: $(ls "${REF_DIR}"/*ref.fasta)"
else
  first_file=$(find "${INPUT_DIR}" -type f -name "*.fasta" | head -n 1)
  file_size=$(stat --format="%s" "${first_file}")
  if (( file_size > 1000000 )); then
    sbatch $REF_KMER "${INPUT_DIR}" "${OUTPUT_DIR}"
  else
    sbatch $REF_BLASTN "${INPUT_DIR}" "${OUTPUT_DIR}"
  fi
  wait_for_job "${job_name}" "$user"
  wait
  if [ ! -f "${REF_DIR}"/*ref.fasta ]; then
    echo "Error: Reference was not found."
    exit 1
  fi
fi

########## JOB 2: ALIGNMENT TO REF
echo -e "\n2: GENOME COVERAGE"
job_name2="aln"
alignment_summary="${REF_DIR}/alignment_summary.txt"

if [ ! -f "${alignment_summary}" ]; then
  sbatch $COV "${INPUT_DIR}" "${OUTPUT_DIR}"
  wait_for_job "${job_name2}" "$user"
fi

# Filter data based on alignment percentage <80%
if [ -f "$alignment_summary" ] && [ "$FILTER" = "True" ]; then
  filter_files "$alignment_summary" "$INPUT_DIR/removed"
fi

########## JOB 3: SNP
echo -e "\n3: SNP ANALYSIS"
job_name3="snp"
if ls "${INPUT_DIR}"/*.fasta &>/dev/null; then
  sbatch $SNP "${INPUT_DIR}" "${OUTPUT_DIR}"
  wait_for_job "${job_name3}" "$user"
else
  echo -e "\nError: All files have alignment below 80%. Analysis canceled. \nCheck file for another reference: $REF_DIR/temp_refs.txt \nand folder: $INPUT_DIR"
  exit 1
fi

if [ -f $OUTPUT_DIR/gubbins/*clean.core.fasta ]; then
  cp $OUTPUT_DIR/gubbins/*clean.core.fasta $OUTPUT_DIR/.
  echo -e "\nSNP analysis completed.\nCore SNP alignment is saved in $OUTPUT_DIR/*clean.core.fasta"
  if [ -f $OUTPUT_DIR/gubbins/filtered_out.txt ]; then
    echo -e "\nGubbins removed files with more than 25% missing sequences. List saved in $OUTPUT_DIR/gubbins/filtered_out.txt."
  fi
else
  echo -e "\nError: Final file $OUTPUT_DIR/gubbins/*clean.core.fasta was not generated. \nCheck data in folders: \n$OUTPUT_DIR/gubbins \nand \n$OUTPUT_DIR/snippy"
fi

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Duration: $((duration/3600))h $(((duration/60)%60))min"
