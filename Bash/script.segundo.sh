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

# Função header

header()
{
    if [ $no_log = 0 ]; then

        >"./Logs/"${logname}".csv"
	if [ $? = "1" ]; then
    		error_exit "Failed creating log file!"
	fi
	file=$(pwd)"/Logs/"${logname}".csv"
	echo -n "SUB_ERROR,STUDY,SUB,SES,TYPE,SUB_TYPE,RUN,ECHO,ORIENTATION,OBLIQUITY,X,Y,Z,VOXEL_VOLUME,I,J,K,TIME,FILE_NAME,SIZE" >> $file
	
	echo >> $file
    fi
    
    if [ $observate = 1 ]; then
	
        echo "Observation mode on! If you didn't request this command, then this is because the preprocessing step requested needs quality control!"
	local signal
	echo "Type Yes/No to continue."
	read signal
	local go_on
	go_on=0
	while [ $go_on != 1 ]; do
	    
	    if [ $signal = "Yes" ]; then 
		go_on=1
	    fi

	    if [ $signal = "No" ]; then
		exit 0
	    fi

	    if [ (( $signal != "Yes" )) && (( $signal != "No" )) ]; then
		echo "TYPE __Yes/No__! (Ò_Ó)"
		echo "DON'T MESS WITH ME, I CAN REMOVE YOUR HOME DIRECTORY!"
		read signal
	    fi

	done

	echo "Wish to continue an unfinished work? (Yes/No)"
	read signal
        
	go_on=0
        while [ $go_on != 1 ]; do

            if [ $signal = "Yes" ]; then 
                go_on=1
		new_file=0
		file = "!"
		while [ ! -a ${DIR}/Logs/${file}.csv ]; do

			echo "Type the name of observation file: (in "${DIR}"/Logs)"
			read file
			if [ ! -a ${DIR}/Logs/${file}.csv ]; then
				echo "File does not exist! Make sure file is *.csv and the extention is omitted"
			fi

		done
		file=$(pwd)"/Logs/"${file}".csv"
            fi

            if [ $signal = "No" ]; then

                go_on=1
		new_file=1
		NOW=`date +%d-%m-%y-%R`
       		>"./Logs/Qc"${NOW}".csv"
	        if [ $? = "1" ]; then
              	     error_exit "Failed creating observation file!"
       	        fi
       		file=$(pwd)"/Logs/Qc"${NOW}".csv"

            fi

            if [ $signal != "Yes" ] && [ $signal != "No" ]; then

                echo "TYPE __Yes/No__! (Ò_Ó)"
                echo "DON'T MESS WITH ME, I CAN REMOVE YOUR HOME DIRECTORY!"
                read signal

            fi

        done

	echo "STATUS,OBSERVATION,OUTPUT_FILE,ORIGINAL_FILE" >> $file

    fi
}


# Função show_interact

show_interact()
{

    if [ $# = 0 ]; then
	error_exit "show_interact: Missing arguments!"
    fi
    case $1 in
	-new )          afni ${runs[$k]#*/} >& /dev/null &
			echo "Looking at:"
			echo "Study: ${study},Subject id: ${subject},Session: ${ses},Type: ${type},Sub Type: ${sub_type},Run: ${run},Echo: ${ech}"
			local go_on=0
			while [ "$go_on" != 1 ]; do
		            echo "You can always stop the job with Ctrl-c...and continue later."
			    echo "Give a new status to file. (0 = good to go / 1 = some problem / 2 = a lot of problem / 3 = unusable)"
		            read new_status
			    while [ "$new_status" < 0 ] && [ "new_status" > 3 ]; do
			        echo "Typed status does not exists! Type again:"
			        read new_status
			    done
			    echo "Type new observation:"
			    read new_obs
			    echo "Is that correct? (Y/n)"
			    read is_ok
			    if [ "$is_ok" = "Y" ]; then
			        go_on=1
			    fi
			done    
			echo "${new_status},${new_obs},${runs[$k]#*/},${runs[$k]#*/}" >> $file
	                ;;
	-replace )   	afni ${runs[$k]#*/} >& /dev/null &
			echo "Looking at:"
			echo "Study: ${study},Subject id: ${subject},Session: ${ses},Type: ${type},Sub Type: ${sub_type},Run: ${run},Echo: ${ech}"
			echo "Current status and observation:"
			echo "${status}, ${obs}"
			local go_on=0
			while [ "$go_on" != 1 ]; do
		            echo "You can always stop the job with Ctrl-c...and continue later."
			    echo "Give a new status to file. (0 = good to go / 1 = some problem / 2 = a lot of problem / 3 = unusable)"
		            read new_status
			    while [ "$new_status" < 0 ] && [ "new_status" > 3 ]; do
			        echo "Typed status does not exists! Type again:"
			        read new_status
			    done
			    echo "Type new observation:"
			    read new_obs
			    echo "Is that correct? (Y/n)"
			    read is_ok
			    if [ "$is_ok" = "Y" ]; then
			        go_on=1
			    fi
			done    
			sed -i '${line}/.*/${new_status},${new_obs},${runs[$k]#*/},${runs[$k]#*/}/' $file
			
    esac
}


# Função action
action()
{

	 if [ $no_log = 0 ]; then
              echo -n "${sub_error},${study},${subject},${ses},${type},${sub_type},${run},${ech},${info[0]},${info[1]},${info[2]},${info[3]},${info[4]},${info[5]},${info[6]},${info[7]},${info[8]},${info[9]},${runs[$k]#*/},${size}" >> $file
         fi

	 if [ $observate = 1 ]; then

	      if [ $new_file = 1 ]; then
	          show_interact -new
	      else
		  local input
		  input=${runs[$k]#*/}
		  local token
		  token=($(grep -n $input < $file))
		  case ${#token[@]} in
		      1 )
			              local line=${token[0]%%:*}
                                      local status=${token[0]#*:}
				      status=${status%,*,*}
				      local obs=${status#*,}
				      status=${status%,*}
			              show_interact -replace
		                      ;;
                      0 )             show_interact -new
		                      ;;
		      * )             error_exit "ERROR: ${input} has multiple entries! Bad file!"  
		  esac	  
              fi

	 fi

 	 if [ $reorient != 0 ]; then
	      local input
	      input=${runs[$k]#*/}
	      if [ ${info[0]} != $reorient ]; then
		  3dresample -orient $reorient -prefix ${input%%*.}+$reorient.nii.gz -input $input
	      else
		  cp $input ${input%%*.}+$reorient.nii.gz
	 fi 
              

}


# Contador de avisos

warning=0

# Processamento de comandos

interactive=0
no_log=0
observate=0
reorient=0
new_fov=0
spec_study=0
deoblique=0
head_crop=0


NOW=`date +%d-%m-%y-%R`
logname="log."${NOW}
DIR=$HOME/Documents/fMRI_data

while [ $1 != "" ]; do
    case $1 in
	-l | --log )                shift
	                            logname=$1
			            ;;
	-nl | --no_log )            no_log=1
	                            ;;
	-obs | --observate )        no_log=1
			            observate=1
				    ;;
        -fov | --less_fov )         new_fov=1
				    ;;
	-deoblique | --deoblique )  deoblique=1
                                    ;;
        -head_crop | --head_crop )  head_crop=1
                                    observate=1
        			    ;;
	-orient | --reorient )      shift
	                            reorient=$1
			            if [ "$reorient" != "" ]; then
				    	exit_error "Missing new orientation!"
				    fi
				    ;;
	-ss | --specific_study )    shift
	                            DIR=$DIR"/"$1
				    spec_study=1
				    study=$1
				    ;;
	* )                         error_exit "$1 is not a valid command!"
    esac
done



#Dir
cd $DIR
if [ $? = "1" ]; then
    error_exit "\nStudy $(parentname $DIR) doen't exist!\n"
fi

header 

if [ $spec_study = "0" ]; then
    sub=($(find -mindepth 2 -maxdepth 2 -name "sub*" -type d))
else
    sub=($(find -maxdepth 1 -name "sub*" -type d))
fi


len=${#sub[@]}

for (( i=0; i<$len; i++ )); do

    if [ $spec_study = "0" ]; then
   
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
	        echo "Warning: folder ses-${ses} doen't match file ${runs[$k]#*/}!"
		warning=$[warning + 1]
		sub_error="TRUE"
	    fi

	    if [ $check_sub != $subject ]; then
	        echo "Warning: folder sub-${subject} doesn't match file ${runs[$k]#*/}!"
		warning=$[warning + 1]
		sub_error="TRUE"
	    fi

	    sub_type=${runs[$k]#*_*_}        #acq-mprage_run-02_echo-01_T1w.nii.gz
	    sub_type=${sub_type%%.*}       #acq-mprage_run-02_echo-01_T1w oder T2 oder task-rest_run-01_bold
	    if [ $type = "anat" ]; then

		if echo $sub_type | grep -q "_"; then
		    tmp=${sub_type%_*};          #acq-mprage_run-02_echo-01
		else
		    tmp=;
		fi
		sub_type=${sub_type##*_}    #T1w
		sub_type=${sub_type%%+*}    #Garante retirada de sufixo com +

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
		tmp=${sub_type%%+*}
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

            if [ $? != 0 ]; then
		error_exit "Something went wrong in 3dinfo!"
	    fi

	    action
 
	done

	cd ..
	cd ..
    done

    cd $DIR
done

echo "The end...There was ${warning} warnings!"
exit 0
