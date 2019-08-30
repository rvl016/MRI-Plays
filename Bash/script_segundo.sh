#!/bin/bash

# Script básico para etapas de pré-processamento
#  Entradas:
#   -i | --interactive : (FALSE/0) modo interativo, qualquer outro parâmetro será ignorado!
#   -l | --log : (log.data]) nome do arquivo de log
#   -nl | --no_log : (FALSE/0) TRUE/1 para não gerar log
#   -jl | --just_log : Apenas gerar modelo de log (não faz pré-processamento)
#
#


# trap 'kill_all' INT


# FUNCTIONS {{{1

# Função erro {{{2
error_exit()
{
    echo -e "$1"
    exit 1
}

# }}}2

# Função killall {{{2

kill_all() 
{
    trap '' INT TERM     # ignore INT and TERM while shutting down
    echo "**** Shutting down... ****"     # added double quotes
    kill -TERM 0         # fixed order, send TERM not INT
    wait
    exit 1
}

# }}}2

# Função interface {{{2

#interface()
#{
#
#
#
#}    


# }}}2


# Função cpu_queue {{{2
cpu_queue()
{
    local i
    local status
    local go=0
 
    while [[ $go = 0 ]]; do
        
        for (( i=0; i<$cpu_credits; i++ )) ; do
            
            status=$(jobs -l | awk -v var=${cpu_pid[$i]} '$2==var {print $3}')
#           echo OLHA
#           echo $status
#           echo ${cpu_pid[@]}
            if [[ ! $status ]] || [[ $status == "Done" ]] ; then
                go=1
                break
            fi    
        
        done
        
        if [[ $go = 1 ]] ; then break ; fi
        sleep .3
    done    
    pid_fit=$i

}
# }}}2

# Função exe_backup {{{2

exe_backup()
{

    # $1 = arquivo original
    # $2 = nome do processo
    # $3 = PID do processo
    tail --pid=${cpu_pid[$3]} -f /dev/null
       

    if [ "$?" != 0 ]; then 
        error_exit "${2} failed for ${1}! Giving up..."
    fi
    if [ ! -d tmp ]; then
        mkdir tmp
    fi
    mv $1 ./tmp
 

}
    
# }}}2

# Função header {{{2

header()
{
#################NO_LOG
     if [ $no_log = 0 ]; then

        rep=""
        while [ -f ./Logs/${logname}.csv ] && [ "$rep" != "Y" ]; do

            echo "Log file ${logname}.csv already exixts, replace? (Y/n)"
            read rep
            if [ "$rep" != "n" ]; then exit 127; fi

        done

        [[ -d ./Logs ]] || mkdir Logs
        >"./Logs/"${logname}".csv"

	    [[ $? != 0 ]] && error_exit "Failed creating log file!"
    	   

	    file=$(pwd)"/Logs/"${logname}".csv"
	    echo "SITE_ERROR,SUB_ERROR,STUDY,SUB,SES,TYPE,SUB_TYPE,RUN,ECHO,ORIENTATION,OBLIQUITY,X,Y,Z,VOXEL_VOLUME,I,J,K,TIME,FILE_NAME,SIZE,FIELD,MODEL,SITE,INSTITUTION,ADDRESS,PHASE_DIR,PHAS_DIR_PLANE,FOV,THICK,SPACE_BTW_SLC,ECHO_TIME,EFF_ECHO,REP_TIME" >> $file

	 fi
#################OBSERVATE
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
                while [ $(ps -a | awk '$4=="afni"') ]; do
                    echo "I still don't know how to deal with multiple instances of AFNI =(...Close then and press any key."
                    read
                done
                echo "It may take a WHILE to load AFNI...zzZzzZZ"
                #################fifo
                mkfifo in
                in_afni=$(pwd)"/in"

                mkfifo out
                out_plug=$(pwd)"/in"

                #################AFNI
                TPC_PORT=$(afni -list_ports | awk '$2=="AFNI_PLUGOUT_TCP_0" {print $5}')
                afni -YESplugouts -R -v &>/dev/null &                      #FALTA CRIAR UM ARQUIVO DE LOG COM A SAÍDA DO AFNI
                wait # ESPERAR O AFNI INICIAR

                [[ $? != 0 ]] && error_exit "Something went wrong with AFNI!"
                PID_AFNI=$(ps -a | awk '$4=="afni" {printf "%d",$1}')

                while [ $(ps -a | awk '$4=="plugout_drive"') ]; do
                    echo "I still don't know how to deal with multiple instances of plugout_drive =(...Close then and press any key."
                    read
                done

                [[ $verb ]] && echo "Starting plugout_drive..."

                #################PLUGOUT_DRIVE
                tail -n +1 -f in_afni | plugout_drive -p ${TPC_PORT} &> /dev/null &    #AQUI PRECISA REDIRECIONAR O SDTERR, MAS TEMOS PROBLEMAS, BAD E DEPOIS OK
                #wait      #NÃO DÁ PRA ESPERAR, ELE VAI ESPERAR O TAIL, NÃO O PLUGOUT
                [[ $? != 0 ]] && error_exit "Something went wrong with plugout_drive!"
                if [ verb ]; then echo "OK!"; fi
                PID_PLUG=$(ps -a | awk '/p]lugout_drive/ {printf "%d",$1}')


            fi

            if [ $signal = "No" ]; then
                exit 0
            fi

            if [[ $signal != "Yes" ]] && [[ $signal != "No" ]]; then
                echo "TYPE __Yes/No__! (Ò_Ó)"
                echo "DON'T MESS WITH ME, I CAN REMOVE YOUR HOME DIRECTORY!"
                read signal
            fi
#################
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
                [[ $? != 0 ]] && error_exit "Failed creating observation file!"
              	   
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

# }}}2

# Função register {{{2

register ()
{
    local go_on="n"
    while [[ "$go_on" != "Y" ]]; do
        echo "You can always stop the job with Ctrl-c and...continue later."
        echo "Give a new status to file. (0 = good to go / 1 = some problem / 2 = a lot of problem / 3 = unusable)"
            read new_status
        while [[ "$new_status" < 0 ]] && [[ "$new_status" > 3 ]]; do
            echo "Typed status does not exists! Type again:"
            read new_status
        done
        echo "Type new observation:"
        read new_obs
        echo "Is that correct? (Y/n)"
        read go_on
    done
}

# }}}2

# Função show_interact {{{2

show_interact()
{

    if [ $# = 0 ]; then
	    error_exit "show_interact: Missing arguments!"
    fi

    if [ "$sub_error" = "TRUE" ]; then 
        echo error_exit "File ${runs[$k]#*/} is in wrong path! (Subject: ${subject}, Session: ${ses})"
    fi

    if [ $specific_study = "1" ]; then
        echo "SWITCH_DIRECTORY A.${study}/ses-${ses}/sub-${sub}/${type}\n" > $in_afni
    else
        echo "SWITCH_DIRECTORY A.ses-${ses}/sub-${sub}/${type}\n" > $in_afni
    fi

    echo "SWITCH_UNDERLAY A.${runs[$k]#*/}.nii.gz"
    echo "Looking at:"
    echo "Study: ${study},Subject id: ${subject},Session: ${ses},Type: ${type},Sub Type: ${sub_type},Run: ${run},Echo: ${ech}"

    if [ "$1" != "-new" ] && [ "$1" != "-replace" ]; then
        error_exit "show_interact: wrong or null parameters! Giving up..."
    fi

    if [ "$1" = "-replace" ]; then
        echo "Current status and observation:"
        echo "${status}, ${obs}"
    fi

    register

    if [ "$1" = "-new" ]; then
        echo "${new_status},${new_obs},${runs[$k]#*/},${runs[$k]#*/}" >> $file
    fi
    if [ "$1" = "-replace" ]; then
        sed -i '${line}/.*/${new_status},${new_obs},${runs[$k]#*/},${runs[$k]#*/}/' $file
    fi

}

# }}}2

# Função action {{{2
action(){

    	if [ $no_log = 0 ]; then
          
            echo ${site_error},${sub_error},${study},${subject},${ses},${type},${sub_type},${run},${ech},${info[0]},${info[1]},${info[2]},${info[3]},${info[4]},${info[5]},${info[6]},${info[7]},${info[8]},${info[9]},${runs[$k]#*/},${size},${json[0]},${json[1]},${site},${json[2]},${json[3]},${json[4]},${json[5]},${json[6]},${json[7]},${json[8]},${json[9]},${json[10]},${json[11]} >> $file

        fi

    	if [ $observate = 1 ]; then

    		local input
    		input=${cur_file}
    		local token
    		token=($(grep -n $input < $file))
    		case ${#token[@]} in

    		    1 )     if [ $new_file = 1 ]; then
                            error_exit "Something went wrong! The script is trying to overwrite content."
                        fi
    			        local line=${token[0]%%:*}
                        local status=${token[0]#*:}
    				    status=${status%,*,*}
    				    local obs=${status#*,}
    				    status=${status%,*}
    			        show_interact -replace
    		            ;;

                0 )     show_interact -new
    		            ;;

    		    * )     error_exit "ERROR: ${input} has multiple entries! Bad file!"

    		esac

    	fi

     	if [ $reorient != 0 ]; then
            re_orient
        fi

        if [ $new_fov ]; then

            fov_red

        fi
}

# }}}2

# Função read_json {{{2

read_json()
{
    if [ "$#" = 0 ]; then
        error_exit "read_json: Any parameters! Giving up..."
    fi
    local fields=(MagneticFieldStrength ManufacturersModelName InstitutionName InstitutionAddress PhaseEncodingDirection InPlanePhaseEncodingDirectionDICOM PercentPhaseFOV SliceThickness SpacingBetweenSlices EchoTime EffectiveEchoSpacing RepetitionTime)
    if [ "$1" = "all" ]; then
        local l

#       echo RUNS
#       echo ${runs[$k]%.*.*}
        for (( l=0; l<${json_len}; l++ )); do
            json[$l]=$(python -c 'import json; fp = open("'${runs[$k]%.*.*}'.json", "r"); obj = json.load(fp); fp.close(); print (obj["'${fields[$l]}'"])' 2>/dev/null)
            
#           echo ${json[$l]}
#           echo "RETURN:"$?

            if [ "$?" != 0 ]; then
                json[$l]=""
#               echo JSONERROR
            fi
#           echo ${json[$l]}
        done
    else
        l=$1
        if [ "$l" < 0 ] || [ "$l" > "${json_len}" ]; then
            error_exit "read_json: There is no field for index ${l}! Giving up..."
        fi
        json[$l]=$(python -c 'import json; fp = open("'${runs[$k]%.*.*}'.json", "r"); obj = json.load(fp); fp.close(); print (obj["'${fields[$l]}'"])' 2>/dev/null)
        if [ "$?" != 0 ]; then
            json[$l]=""
        fi

    fi

}

# }}}2

# Função fov_red {{{2

fov_red()
{

    local pid_fit

    if [[ $type = "anat" ]]; then

        if [[ ! -f "${cur_file%%+*}+fov.nii.gz" ]] ; then

            echo "Running...${cur_file%%+*}.nii.gz"
            cpu_queue
#           echo $pid_fit
#           exit
            robustfov -i ${cur_file} -r "${cur_file%%.*}+fov.nii.gz" &>/dev/null &
            cpu_pid[$pid_fit]=$!
            exe_backup ${cur_file} "RobustFov" ${pid_fit} &
            
        else

            echo "${cur_file%%+*}+fov.nii.gz already exists!"
       
        fi    
    fi
}

# }}}2

# Função bias_off {{{2

bias_off(){

    local input
    input=$cur_file

    if [ "$#" = 0 ]; then
        error_exit "bias_off: Any parameters! Giving up..."
    fi

    if [ "$1" < 0 ] || [ "$1" > 1 ]; then
        error_exit "bias_off: Either is a T1w or a T2w. There is no T${1}w! Giving up..."
    fi

    fast $input -t ${1} -n  -B [corrected file name]
}

# }}}2

# Função Reorient {{{2

re_orient()
{
    local input
    input=${cur_file}
    if [ ${info[0]} != $reorient ]; then
        3dresample -orient $reorient -prefix ${input%%*.}+$reorient.nii.gz -input $input
    else
        cp $input ${input%%*.}+$reorient.nii.gz
    fi
    if [ ! -d tmp ]; then
        mkdir tmp
    fi
    mv $input tmp
}

# }}}2

# Função to_std {{{2

to_std()
{
    local input
    input=${cur_file}

    fslreorint2sdt $cur_file ${cur_file%%*.}+$reorient.nii.gz


}

# }}}2

# }}}1

# Variáveis de ambiente {{{1

warning=0
json_len=11

# CPU Vars {{{2

cpu_credits=$(grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}')
declare -a cpu_pid 
for (( i=0; i<$cpu_credits; i++ )) ; do cpu_pid[$i]=0 ; done

# }}}2

# Set interface type

command -v dialog && has_dialog=1 || has_dialog=0

# }}}1

# Processamento de comandos

interactive=0
no_log=0
observate=0
reorient=0
new_fov=0
spec_study=0
deoblique=0
head_crop=0
verb=0


NOW=`date +%d-%m-%y-%R`
logname="log."${NOW}
DIR=$HOME/Documents/fMRI_data

# Options {{{1

while [ "$1" != "" ]; do
    case $1 in

	    -l | --log )                    shift
	                                    logname=$1
    			                        if [ "$logname" = "" ]; then
    				    	                exit_error "--log: Missing filename!"
    				                    fi
			                            ;;

    	-nl | --no_log )                no_log=1
    	                                ;;

    	-obs | --observate )            no_log=1
    			                        observate=1
    				                    ;;

        -fov | --less_fov )             new_fov=1
                                        ;;

    	-deoblique | --deoblique )      deoblique=1
                                        ;;

        -head_crop | --head_crop )      head_crop=1
                                        observate=1
            			                ;;

    	-orient | --reorient )          shift
    	                                reorient=$1
    			                        if [ "$reorient" = "" ]; then
    				    	                exit_error "--reorient: Missing new orientation!"
    				                    fi
    				                    ;;

        -dir | --directory )            shift
                                        DIR=$1            
                                        ;;

    	-ss | --specific_study )        shift
    	                                DIR=$DIR"/"$1
    				                    spec_study=1
    				                    study=$1
    			                        if [ "$study" = "" ]; then
    				    	                exit_error "--specific_study: Missing studyname!"
    				                    fi
    				                    ;;
        -v | --verbose )                verb=1
                                        ;;

    	* )                             error_exit "$1 is not a valid command!"

    esac
    shift
done

# }}}1

#Dir
cd $DIR
[[ $? != 0 ]] && error_exit "Study $(dirname $DIR) doen't exist!"

# Main {{{1

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
    [[ $? != 0 ]] && error_exit "Directory ${sub[$i]} couldn't be accessed at $error_tmp!"

    subdir=($(find -maxdepth 2 -mindepth 2 \( -name "anat" -or -name "func" \) -type d))
    len2=${#subdir[@]}

    for (( j=0; j<$len2; j++ )); do

    	ses=${subdir[$j]#*-}
    	type=${ses#*/}
    	ses=${ses%%/*}

    	error_tmp=$(pwd)
    	cd ${subdir[$j]}
    	[[ $? != 0 ]] && error_exit "Directory ${subdir[$j]} couldn't be accessed at $error_tmp!" 

    	runs=($(find -maxdepth 1 \( -name "*.nii.gz" -or -name "*.nii" \) -type f))
    	len3=${#runs[@]}

    	for (( k=0; k<$len3; k++ )); do

            site_error="FALSE"
#           echo "NOW:"$(pwd)
            cd ..
#           echo "AFTER:"$(pwd)
            site=$(cat sub-${subject}_ses-${ses}_scans.tsv | grep -m 1 ${subject}_ses-${ses} | awk '{print $(NF)}')
            if [ "$site" = "" ]; then
                echo "Warning: sub-${subject}/ses-${ses} doen't have scan site information!"
                warning=$((warning + 1))
                site_error="TRUE"
            fi
            cd -

    	    sub_error="FALSE"               #sub-A00000300_ses-20110101_acq-mprage_run-02_echo-01_T1w.nii.gz
    	    check_sub=${runs[$k]#*-}         #A00000300_ses-20110101_acq-mprage_run-02_echo-01_T1w.nii.gz
    	    check_ses=${check_sub#*-}       #20110101_acq-mprage_run-02_echo-01_T1w.nii.gz
    	    check_sub=${check_sub%%_*}      #A00000300
    	    check_ses=${check_ses%%_*}      #20110101

    	    if [ $check_ses != $ses ]; then
    	        echo "Warning: folder ses-${ses} doesn't match file ${runs[$k]#*/}!"
              warning=$((warning + 1))
    		      sub_error="TRUE"
    	    fi

    	    if [ $check_sub != $subject ]; then
    	        echo "Warning: folder sub-${subject} doesn't match file ${runs[$k]#*/}!"
              warning=$((warning + 1))
    		      sub_error="TRUE"
    	    fi

    	    sub_type=${runs[$k]#*_*_}        #acq-mprage_run-02_echo-01_T1w.nii.gz
    	    sub_type=${sub_type%%.*}       #acq-mprage_run-02_echo-01_T1w oder T2 oder task-rest_run-01_bold
    	    if [ $type = "anat" ]; then

            if [[ $(echo $sub_type | grep -q "_") ]]; then
                    tmp=${sub_type%_*};          #acq-mprage_run-02_echo-01
                else
                    tmp=;
                fi
                sub_type=${sub_type##*_}    #T1w
                sub_type=${sub_type%%+*}    #Garante retirada de sufixo com +

                if [[ $sub_type = "T1w" ]]; then
                  if [[ $(echo $tmp | grep -q "_") ]]; then
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
            
            if [[ ! $no_log ]]; then

	            size=$(du -k ${runs[$k]} | cut -f1)
	    	    info=($(3dinfo -orient -obliquity -adi -adj -adk -voxvol -n4 ${runs[$k]}))
	
	    	    read_json all
	#           echo "RETURN"$?
	            [[ $? != 0 ]] && error_exit "Something went wrong in 3dinfo!"

            fi

            cur_file=${runs[$k]#*/}
    	    action

    	done

	    cd ..
	    cd ..
    done

    cd $DIR
done

# }}}1

wait 

echo "The end...There was ${warning} warnings!"

exit 0
