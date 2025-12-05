#!/bin/bash

# this is just $DOCKBASE/docking/submit/submit.csh
# but saves the SGE job id to submit.pid


#$DOCKBASE/docking/submit/subdock.csh $DOCKBASE/docking/DOCK/bin/dock.csh

#if [ ! -f "dirlist" ]; then
#    echo "Error: Cannot find dirlist, the list of subdirectories!"
#    echo "Exiting!"
#    exit 1
#fi

if [ -z ${CLUSTER_TYPE+x} ]; then
    echo "ERROR: The \${CLUSTER_TYPE} variable is not set"
    echo "ERROR: Options are 'LOCAL', 'SGE', 'SLURM'"
    echo "ERROR: Please run 'source setup_dock_environment.sh' in the project root directory"
fi

if [ -z ${DOCKBASE+x} ]; then
    echo "ERROR: The \${DOCKBASE} variable is not set"
    echo "ERROR: This should point to where `https://github.com/docking-org/DOCK/tree/main/ucsfdock`"
    echo "ERROR: lives locally in the file system"
    echo "ERROR: Please run 'source setup_dock_environment.sh' in the project root directory"
fi

if [[ ${CLUSTER_TYPE} == "SGE" ]]; then
    DIRNUM=$(wc -l dirlist)
    SUBMIT_JOB_ID=$(qsub \
      -terse \
      -t 1-$DIRNUM \
      $DOCKBASE/docking/submit/rundock.csh \
      $DOCKBASE/docking/DOCK/bin/dock.csh)
    echo "Your job-array ${SUBMIT_JOB_ID}.1-${DIRNUM}:1 (\"rundock.csh\") has been submitted"
    echo "Saving SGE job id to submit.pid"
    echo $SUBMIT_JOB_ID > submit.pid

elif [[ ${CLUSTER_TYPE} == "SLURM" ]]; then

    if [[ "$#" != 3 ]]; then
	echo "ERROR: Using the SLURM submission requires passing in three arguments like this:"
	echo "ERROR: dock_submit.sh \${DATABASE}/database.sdi \${PREPARED_STRUCTURE}/dockfiles results"
	echo "ERROR: Instead $# arguments passed"
    fi
    
    if [ -z ${SCRATCH_DIR+x} ]; then
	echo "ERROR: Using the SLURM submission, the \${SCRATCH_DIR} variable is not set"
	echo "ERROR: This should point to a point temporary results are stored"
	echo "ERROR: Please run 'source setup_dock_environment.sh' in the project root directory"
    fi

    if [ -z ${SLURM_ACCOUNT+x} ]; then
	echo "ERROR: Using the SLURM submission, the \${SLURM_ACCOUNT} variable is not set"
	echo "ERROR: Please run 'source setup_dock_environment.sh' in the project root directory"
    fi
    if [ -z ${SLURM_MAIL_USER+x} ]; then
	echo "ERROR: Using the SLURM submission, the \${SLURM_MAIL_USER} variable is not set"
	echo "ERROR: Please run 'source setup_dock_environment.sh' in the project root directory"
    fi
    if [ -z ${SLURM_MAIL_TYPE+x} ]; then
	echo "ERROR: Using the SLURM submission, the \${SLURM_MAIL_TYPE} variable is not set"
	echo "ERROR: Please run 'source setup_dock_environment.sh' in the project root directory"
    fi
    if [ -z ${SLURM_PARTITION+x} ]; then
	echo "ERROR: Using the SLURM submission, the \${SLURM_PARTITION} variable is not set"
	echo "ERROR: Please run 'source setup_dock_environment.sh' in the project root directory"
    fi
    
    # check if variables are defined
    # if the ${DOCKFILES} directory is writable, then create .shasum in in it
    # for each file in database.sdi
    #    if OUTDOCK.0 or test.mol2.gz.0 doesn't exist, add it to the joblist
    # call sbatch on rundock.bash

    export INPUT_SOURCE=$(readlink -f $1)
    export DOCKFILES=$(readlink -f $2)
    export EXPORT_DEST=$(readlink -f $3 )
    export SHRTCACHE=${SCRATCH_DIR}
    export LONGCACHE=${SCRATCH_DIR}
    export SBATCH_ARGS="--account=${SLURM_ACCOUNT} --mail-user=${SLURM_MAIL_USER} --mail-type=${SLURM_MAIL_TYPE} --partition=${SLURM_PARTITION}"

    DOCKFILES_COMMON=${SCRATCH_DIR}/DOCK_common/dockfiles.$(cat ${DOCKFILES}/* | sha1sum | awk '{print $1}')
    echo "Copying dockfiles to '${DOCKFILES_COMMON}'"
    cp -r ${DOCKFILES} ${DOCKFILES_COMMON}
    #    njobs=$(wc -l dirlist)

    #    sbatch ${SBATCH_ARGS} --signal=B:USR1@120 --array=1-${njobs} ${DOCKBASE}/docking/submit/rundock.bash
    if [[ ${DOCK_VERSION+x} && (${DOCK_VERSION} == "3.7") ]]; then
	# location of files changed in dock from 3.7 to 3.8
	export DOCKEXEC=${DOCKBASE}/docking/DOCK/bin/dock64
	bash ${DOCKBASE}/docking/submit/slurm/subdock.bash
    else
	export DOCKEXEC=${DOCKBASE}/docking/DOCK/dock64
	bash ${DOCKBASE}/docking/submit/subdock.bash
    fi
    
    echo "Check status with: squeue | grep -e \"$(whoami)\" -e \"rundock\""

elif [[ ${CLUSTER_TYPE} == "LOCAL" ]]; then
    #TODO make this work!
    export INPUT_SOURCE=$(readlink -f $1)
    export DOCKFILES=$(readlink -f $2)
    export EXPORT_DEST=$(readlink -f $3 )
    export DOCKEXEC=${DOCKBASE}/docking/DOCK/dock64
    export SHRTCACHE=${SCRATCH_DIR}
    export LONGCACHE=${SCRATCH_DIR}
    
    export JOB_ID=1
    export TASK_ID=1
else
    echo "Unrecognized cluster type '${CLUSTER_TYPE}'"
fi
