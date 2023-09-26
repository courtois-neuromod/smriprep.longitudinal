#!/bin/bash
#SBATCH --account=rrg-pbellec
#SBATCH --job-name=smriprep_sub-02.job
#SBATCH --output=/lustre04/scratch/bpinsard/smriprep.longitudinal/code/smriprep_sub-02.out
#SBATCH --error=/lustre04/scratch/bpinsard/smriprep.longitudinal/code/smriprep_sub-02.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4096M
#SBATCH --tmp=100G
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=basile.pinsard@gmail.com

 
set -e -u -x


export LOCAL_DATASET=$SLURM_TMPDIR/${SLURM_JOB_NAME//-/}/
export SINGULARITYENV_TEMPLATEFLOW_HOME="${LOCAL_DATASET}/sourcedata/templateflow/"
flock --verbose /lustre03/project/rrg-pbellec/ria-beluga/alias/cneuromod.anat.smriprep.longitudinal/.datalad_lock datalad clone ria+file:///lustre03/project/rrg-pbellec/ria-beluga#~cneuromod.anat.smriprep.longitudinal@dev $LOCAL_DATASET
cd $LOCAL_DATASET
datalad get -s ria-beluga-storage -J 4 -n -r -R1 . # get sourcedata/* containers
datalad get -s ria-beluga-storage -J 4 -r sourcedata/templateflow/tpl-{MNI152NLin2009cAsym,OASIS30ANTs,fsLR,fsaverage,MNI152NLin6Asym}
if [ -d sourcedata/smriprep ] ; then
    datalad get -n sourcedata/smriprep sourcedata/smriprep/sourcedata/freesurfer
fi
git submodule foreach --recursive git annex dead here
git checkout -b $SLURM_JOB_NAME
if [ -d sourcedata/freesurfer ] ; then
  git -C sourcedata/freesurfer checkout -b $SLURM_JOB_NAME
fi

git submodule foreach  --recursive git-annex enableremote ria-beluga-storage

datalad containers-run -m 'fMRIPrep_sub-02/ses-*' -n bids-fmriprep --input sourcedata/templateflow/tpl-MNI152NLin2009cAsym/ --input sourcedata/templateflow/tpl-OASIS30ANTs/ --input sourcedata/templateflow/tpl-fsLR/ --input sourcedata/templateflow/tpl-fsaverage/ --input sourcedata/templateflow/tpl-MNI152NLin6Asym/ --output . --input 'sourcedata/cneuromod.anat.raw/sub-02/ses-*/anat/*_T1w.nii.gz' --input 'sourcedata/cneuromod.anat.raw/sub-02/ses-*/anat/*_T2w.nii.gz' --input 'sourcedata/cneuromod.anat.raw/sub-02/ses-*/anat/*_FLAIR.nii.gz' -- -w ./workdir --participant-label 02 --anat-only --bids-filter-file code/bids_filters.json --output-layout bids --output-spaces MNI152NLin2009cAsym T1w:res-iso2mm MNI152NLin6Asym --cifti-output 91k --skip_bids_validation --write-graph --omp-nthreads 8 --nprocs 8 --mem_mb 32768 --fs-license-file code/freesurfer.license  --fs-subjects-dir sourcedata/cneuromod.anat.freesurfer_longitudinal sourcedata/cneuromod.anat.raw ./ participant 
fmriprep_exitcode=$?

flock --verbose /lustre03/project/rrg-pbellec/ria-beluga/alias/cneuromod.anat.smriprep.longitudinal/.datalad_lock datalad push -d ./ --to origin
if [ -d sourcedata/freesurfer ] ; then
    flock --verbose /lustre03/project/rrg-pbellec/ria-beluga/alias/cneuromod.anat.smriprep.longitudinal/.datalad_lock datalad push -J 4 -d sourcedata/freesurfer --to origin
fi 
if [ -e $LOCAL_DATASET/workdir/fmriprep_wf/resource_monitor.json ] ; then cp $LOCAL_DATASET/workdir/fmriprep_wf/resource_monitor.json /scratch/bpinsard/smriprep_sub-02_resource_monitor.json ; fi 
if [ $fmriprep_exitcode -ne 0 ] ; then cp -R $LOCAL_DATASET /scratch/bpinsard/smriprep_sub-02 ; fi 
exit $fmriprep_exitcode 
