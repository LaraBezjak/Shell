SNP_analysis_fasta.sh for fasta files only. It reads coverage.sh, najdi_ref_blast.sh, najdi_ref_kmerfinder.sh and snp.sh, so adjust the paths accordingly.
	FOR HELP USE: SNP_analysis_fasta.sh -h

csiphylogeny.sh $INPUT $REF

Conda environments:
- snp_env.yml (snippy, gubbins)
- cge_env.yml (blastn, kmerfinder, CSIPhylogeny)
