#!/bin/bash

# Script básico para etapas de pré-processamento
#  Entradas:
#   -i | --interactive : (FALSE/0) modo interativo, qualquer outro parâmetro será ignorado!
#   -l | --log : (log.[data]) nome do arquivo de log
#   -nl | --no_log : (FALSE/0) TRUE/1 para não gerar log
#   -jl | --just_log : Apenas gerar modelo de log (não faz pré-processamento)
#
#

# Função erro
error_exit()
{
    echo -e "$1"
    exit 1
}

# Contador de avisos

warning=0

# Processamento de comandos

interactive=0
no_log=0
just_log=0
spec_study=0

NOW=`date +%d-%m-%y-%R`
logname="log."${NOW}
DIR=$HOME/Documents/fMRI_data

while [ "$1" != "" ]; do
    case $1 in
	-l | --log )              shift
			          logname=$1
			          ;;
	-nl | --no_log )          no_log=1
	                          ;;
	-jl | --just_log)         just_log=1
			          ;;
	-ss | --specific_study )  DIR=$DIR/$1
				  spec_study=1
				  study=$1
				  ;;
	-* | --* )                exit_error "\n${1} is not a valid parameter!\n"
			   exit 1
    esac
    shift
done



#Dir
cd $DIR
if [ $? = "1" ]; then
    error_exit "Study $(parentname $DIR) doen't exist!"
fi

#Criar arquivo log

>"./Logs/"${logname}".csv"
if [ $? = "1" ]; then
    error_exit "Failed creating log file!"
fi

file=$(pwd)"/Logs/"${logname}".csv"
echo -e "SUB_ERROR,STUDY,SUB,SES,TYPE,SUB_TYPE,RUN,ECHO,ORIENTATION,OBLIQUITY,X,Y,Z,VOXEL_VOLUME,I,J,K,TIME,FILE_NAME,SIZE" >> $file 

if [ $spec_study != "1" ]; then
    sub=($(find -mindepth 2 -maxdepth 2 -name "sub*" -type d))
else
    sub=($(find -maxdepth 1 -name "sub*" -type d))
fi


len=${#sub[@]}
for (( i=0; i<$len; i++ )); do

    if [ $spec_study != "1" ]; then
   
	study=${sub[$i]#*/}
        subject=${study#*-}
	study=${study%%/*}
	
    else
	
	subject=${sub[$i]#*-}
    fi
    error_tmp=$(pwd)
    cd ${sub[$i]}
    if [ $? = "1" ]; then
        error_exit "Directory ${sub[$i]} couldn't be accessed at $error_tmp!"
    fi

    subdir=($(find -maxdepth 2 -mindepth 2 \( -name "anat" -or -name "func" \) -type d))
    len2=${#subdir[@]}

    for (( j=0; j<$len2; j++ )); do
	
	ses=${subdir[$j]#*-}
	type=${ses#*/}
	ses=${ses%%/*} 

	error_tmp=$(pwd)
	cd ${subdir[$j]}
	if [ $? = "1" ]; then
	    error_exit "Directory ${subdir[$j]} couldn't be accessed at $error_tmp!"
	fi

	runs=($(find \( -name "*.nii.gz" -or -name "*.nii" \) -type f))
	len3=${#runs[@]}

	for (( k=0; k<$len3; k++ )) do

	    sub_error="FALSE"               #sub-A00000300_ses-20110101_acq-mprage_run-02_echo-01_T1w.nii.gz
	    check_sub=${runs[$k]#*-}         #A00000300_ses-20110101_acq-mprage_run-02_echo-01_T1w.nii.gz
	    check_ses=${check_sub#*-}       #20110101_acq-mprage_run-02_echo-01_T1w.nii.gz
	    check_sub=${check_sub%%_*}      #A00000300
	    check_ses=${check_ses%%_*}      #20110101
	    if [ $check_ses != $ses ]; then
	        echo -e "Warning: folder ses-${ses} doen't match file ${runs[$k]}!\n"
		warning=$[warning + 1]
		sub_error="TRUE"
	    fi
	    if [ $check_sub != $subject ]; then
	        echo -e "Warning: folder sub-${subject} doesn't match file ${runs[$k]}!\n"
		warning=$[warning + 1]
		sub_error="TRUE"
	    fi

	    sub_type=${runs[$k]#*_*_}        #acq-mprage_run-02_echo-01_T1w.nii.gz
	    sub_type=${sub_type%.*.*}       #acq-mprage_run-02_echo-01_T1w oder T2 oder task-rest_run-01_bold
	    if [ $type = "anat" ]; then

		if echo $sub_type | grep -q "_"; then
		    tmp=${sub_type%_*};          #acq-mprage_run-02_echo-01
		else
		    tmp=;
		fi
		sub_type=${sub_type##*_}    #T1w

		if [ $sub_type = "T1w" ]; then
	            if echo $tmp | grep -q "_"; then
		        tmp=${tmp#*_}           #run-02_echo-01
	            else
                    	tmp=;
                    fi
		fi

		case $tmp in

		    "" )         run=0
				 ech=0
				 ;;
		    *_* )
			         run=${tmp#*-}    #02_echo-01
				 run=${run%_*}    #02
				 ech=${tmp##*-}   #01        
			         ;;
		    * )
			         run=${tmp#*-}
			         ech=0

		esac

	    elif [ $type = "func" ]; then
		ech=0
		tmp=$sub_type
		if [ $tmp = "task-rest_bold" ]; then
		    run=0
		else
		    tmp=${tmp#*-*-}
		    tmp=${tmp%_*}
		    run=$tmp
		fi
		
		sub_type="BOLD"
	    fi
            size=$(du -k ${runs[$k]} | cut -f1)
	    info=($(3dinfo -orient -obliquity -adi -adj -adk -voxvol -n4 ${runs[$k]}))
	    echo -e "${sub_error},${study},${subject},${ses},${type},${sub_type},${run},${ech},${info[0]},${info[1]},${info[2]},${info[3]},${info[4]},${info[5]},${info[6]},${info[7]},${info[8]},${info[9]},${runs[$k]#*/},${size}" >> $file
	done

	cd ..
	cd ..
    done

    cd $DIR
done

#if [ "$(3dinfo -orient sub-A00038624_ses-20130101_acq-mprage_run-01_T1w.nii.gz)" = "RPI" ]; then echo "Sim!"; else echo "Não!"; fi
