#!/bin/bash

# Script básico para etapas de pré-processamento
#  Entradas:
#   -i | --interactive : (FALSE/0) modo interativo, qualquer outro parâmetro será ignorado!
#   -l | --log : (log.data]) nome do arquivo de log
#   -nl | --no_log : (FALSE/0) TRUE/1 para não gerar log
#   -jl | --just_log : Apenas gerar modelo de log (não faz pré-processamento)
#
#

 trap 'kill_all' INT
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
    kill $PID_TAIL
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
    # $4 = AFNI to NIFTI
    # $5 = tmp ( for $4 )

    tail --pid=${cpu_pid[$3]} -f /dev/null
       

    if [ "$?" != 0 ]; then 
        error_exit "${2} failed for ${1}! Giving up..."
    fi
    if [ ! -d tmp ]; then
        mkdir tmp
    fi
    
    if [[ $4 = 1 ]]; then 

        3dAFNItoNIFTI -prefix ${1%%.*}+${2}.nii.gz $5 &>/dev/null        
        [[ $? != 0 ]] && error_exit "3dAFNItoNIFTI: Something went wrong!"

    fi

    mv ${1}.meta ${1%%.*}+${2}.nii.gz.meta
    [[ $? != 0 ]] && error_exit "Moving metafile: Something went wrong!"
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
	 #   local signal
	 #   echo "Type Yes/No to continue."
	 #   read signal
	 #   local go_on
	 #   go_on=0
	 #   while [ $go_on != 1 ]; do

     #       if [ $signal = "Yes" ]; then

     #           go_on=1
                local skip_afni
                while [ $(ps -a | awk '$4=="afni" {print $4}') ]; do
                    echo "I still don't know how to deal with multiple instances of AFNI =(...Close then or type Yes if there is only one and is oppened in the right paths."
                    read skip_afni
                    [[ $skip_afni = "Yes" ]] && break
                done
                [[ $skip_afni != "Yes" ]] && echo "It may take a WHILE to load AFNI...zzZzzZZ"
                #################fifo
                
                
                [[ ! -p inpipe ]] && mkfifo inpipe
               #[[ $? != 0 ]] && error_exit "Pipe could not be touched!"
                in_afni=$(pwd)"/inpipe"

                [[ ! -p outpipe ]] && mkfifo outpipe
               #[[ $? != 0 ]] && error_exit "Pipe could not be touched!"
                out_plug=$(pwd)"/outpipe"

                #################AFNI
                TPC_PORT=$(afni -list_ports | awk '$2=="AFNI_PLUGOUT_TCP_0" {print $5}')
                [[ $? != 0 ]] && error_exit "TPC_PORT could not be get!"
               


     #       fi

     #       if [ $signal = "No" ]; then
     #           exit 0
     #       fi

     #       if [[ $signal != "Yes" ]] && [[ $signal != "No" ]]; then
     #           echo "TYPE __Yes/No__! (Ò_Ó)"
     #           echo "DON'T MESS WITH ME, I CAN REMOVE YOUR HOME DIRECTORY!"
     #           read signal
     #       fi
#################
     #   done

        if [[ $file_notes = 0 ]]; then

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
    fi
}

# }}}2
# Função update_afni {{{2

update_afni()
{
    
   #[[ $PID_AFNI ]] && kill $PID_AFNI
   #[[ $PID_PLUG ]] && kill $PID_PLUG
   #[[ $PID_TAIL ]] && kill $PID_TAIL
    kill $PID_AFNI
    kill $PID_PLUG
    kill $PID_TAIL
    
    while [ $(ps -e | awk '$4=="plugout_drive" {print $4}') ]; do
        echo "I still don't know how to deal with multiple instances of plugout_drive =(...Close then and press any key."
        read
    done
    
    [[ $afni_compare = 1 ]] && afni -yesplugout -R3 -com "OPEN_WINDOW B" &>/dev/null & 
    [[ $afni_compare = 0 ]] && afni -yesplugout -R2 -com "OPEN_WINDOW A.axialimage geom=${afni_size}x${afni_size}+0+22" -com "OPEN_WINDOW A.coronalimage geom=${afni_size}x${afni_size}+${afni_size}+22" -com "OPEN_WINDOW A.sagittalimage geom=${afni_size}x${afni_size}+$((2*${afni_size}))+22" &>/dev/null & 
    wait 

    #FALTA CRIAR UM ARQUIVO DE LOG COM A SAÍDA DO AFNI
    # ESPERAR O AFNI INICIAR
#   echo "Press any key when AFNI is ready..."
#   read

    [[ $? != 0 ]] && error_exit "Something went wrong with AFNI!"
    
    PID_AFNI=$(ps -e | awk '$4=="afni" {printf "%d",$1}')
    [[ $PID_AFNI = "" ]] && error_exit "AFNI PID could not be gotten!"
    

    echo "Starting plugout_drive..."

    #################PLUGOUT_DRIVE
    tail -n +1 -f $in_afni | plugout_drive &>/dev/null &    
   
    PID_TAIL=$! 
    #AQUI PRECISA REDIRECIONAR O SDTERR, MAS TEMOS PROBLEMAS, BAD E DEPOIS OK
    #wait      #NÃO DÁ PRA ESPERAR, ELE VAI ESPERAR O TAIL, NÃO O PLUGOUT
    [[ $? != 0 ]] && error_exit "Something went wrong with plugout_drive!"
    
#   echo -e "OPEN_WINDOW A.axialimage geom=${afni_size}x${afni_size}+0+22\n" > $in_afni
#   echo -e "OPEN_WINDOW A.coronalimage geom=${afni_size}x${afni_size}+${afni_size}+22\n" > $in_afni
#   echo -e "OPEN_WINDOW A.sagittalimage geom=${afni_size}x${afni_size}+$((2*${afni_size}))+22\n" > $in_afni
#    [[ $afni_compare = 1 ]] && echo -e "OPEN_WINDOW B\n" > $in_afni
    

    PID_PLUG=$(ps -e | awk '$4=="plugout_drive" {printf "%d",$1}')
}

# }}}2        
# Função check_notes {{{2

check_notes()
{
    local type=$1
    local index=$2
    local data_flags file_flags  
    local files
    local i

    if [[ $type = "file" ]]; then

        data_flags=${runs[$index]%%.*}
        data_flags=${data_flags#*+}
        [[ $data_flags = "sub-"* ]] && data_flags="none"
        file_flags=$(cat ${runs[$index]}.meta | awk 'END{print $1}')
        
        [[ $file_flags != $data_flags ]] && return 0 || return 1

    fi    
    if [[ $type = "subject" ]]; then

        
        files=($(find . -mindepth 3 -maxdepth 3 \( -name *.nii.gz -or -name *.nii \) -type f))
        for (( i=0; i<${#files[@]}; i++ )); do
            
            [[ ! -f ${files[$i]}".meta" ]] && return 0    
        done
        no_afni=1
        return 1
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
# Função remove_sub_condition {{{2
remove_sub_condition()
{

    local files t1w_check=0 t2w_check=0 bold_check=0 tmp i

    files=($(find -maxdepth 3 -mindepth 3 \( -name "*.nii.gz" -or -name "*.nii" \) -type f))

    files=(${files[@]##*_})
    files=(${files[@]%%+*}) 
    files=(${files[@]%%.*}) 

    for i in ${files[@]}; do

        [[ $i = "T1w" ]] && t1w_check=1
        [[ $i = "T2w" ]] && t2w_check=1
        [[ $i = "bold" ]] && bold_check=1

    done

    [[ ! -f "sub-"$subject".meta" ]] && touch "sub-"$subject".meta"
    tmp="$(date +%D_%R) Missing" 

    [[ $t1w_check = 0 ]] && tmp="${tmp}+T1w" 
    [[ $t2w_check = 0 ]] && tmp="${tmp}+T2w" 
    [[ $bold_check = 0 ]] && tmp="${tmp}+bold" 
    echo $tmp >> "sub-"$subject".meta"

    if [[ $t1w_check = 0 ]] || [[ $bold_check = 0 ]]; then
        
        cd ..
        mv "sub-"$subject "DEAD.sub"$subject
        cd "DEAD.sub"$subject
        
    fi

}    
# }}}2
# Função load_sub_notes {{{2
load_sub_notes() 
{
    local meta_files some_bad i
    local reject_flag=$1
    some_bad=0
    [[ $anat_notes = 1 ]] && meta_files=($(find ./ses-*/anat -maxdepth 1 -mindepth 1 \( -name "*.nii.gz.meta" -or -name "*.nii.meta" \) -type f))
    [[ $func_notes = 1 ]] && meta_files=($(find ./ses-*/func -maxdepth 1 -mindepth 1 \( -name "*.nii.gz.meta" -or -name "*.nii.meta" \) -type f))
    [[ $anat_notes = 0 ]] && [[ $func_notes = 0 ]] && meta_files=($(find -maxdepth 3 -mindepth 3 \( -name "*.nii.gz.meta" -or -name "*.nii.meta" \) -type f))

    for i in ${meta_files[@]}; do
        [[ $ignore_flag = 1 ]] && [[ $(cat $i | awk -v check="$reject_flag" 'END{ if( $2 == 2 && $1 !~ check ){ {print 1}}}') = 1 ]] && some_bad=1 && break
        [[ $ignore_flag = 0 ]] && [[ $(cat $i | awk 'END{ if( $2 == 2 ){ {print 1}}}') = 1 ]] && some_bad=1 && break
    done

    return $some_bad

}    

# }}}2
# Função Notes {{{2

Notes()
{

### $1 = notetype
### $2 = index (For directory access)

    local notetype=$1
    local index=$2

    if [[ $notetype = "ses_notes" ]]; then
        $NOTE_DIR/take_notes.sh --type ses --directory $(pwd)
    fi
    
    if [[ $notetype = "file_notes" ]]; then    
        if [[ $ignore_notes = 1 ]]; then
            
            check_notes file ${index} 
            if [[ $? = 0 ]]; then $NOTE_DIR/take_notes.sh --type file --file ${runs[$index]} --directory $(pwd) ; fi
        
        else    
            $NOTE_DIR/take_notes.sh --type file --file ${runs[$index]} --directory $(pwd) 
        fi     
    fi    
    
    [[ $? != 0 ]] && error_exit "Something went wrong with 'take_notes.sh'!"

}    

# }}}2
# Função show_interact {{{2

show_interact()
{

#### $1 = 


    if [ $# = 0 ]; then
	    error_exit "show_interact: Missing arguments!"
    fi

    if [ "$sub_error" = "TRUE" ]; then 
        echo error_exit "File ${runs[$l]#*/} is in wrong path! (Subject: ${subject}, Session: ${ses})"
    fi

    echo -e "SWITCH_DIRECTORY A.ses-${ses}/${type}\n" > $in_afni
    [[ $afni_compare = 1 ]] && echo -e "SWITCH_DIRECTORY B.ses-${ses}/${type}/tmp\n" > $in_afni
  

    echo -e "SWITCH_UNDERLAY A.${runs[$l]}\n" > $in_afni
    [[ $afni_compare = 1 ]] && echo -e "SWITCH_UNDERLAY B.${runs[$l]%+*}.nii.gz\n" > $in_afni

    echo -e "OPEN_WINDOW A.axialimage geom=${afni_size}x${afni_size}+0+22\n" > $in_afni
    echo -e "OPEN_WINDOW A.coronalimage geom=${afni_size}x${afni_size}+${afni_size}+22\n" > $in_afni
    echo -e "OPEN_WINDOW A.sagittalimage geom=${afni_size}x${afni_size}+$((2*${afni_size}))+22\n" > $in_afni
    echo -e "OPEN_WINDOW B.axialimage geom=${afni_size}x${afni_size}+1+$((${afni_size} + 22))\n" > $in_afni
    echo -e "OPEN_WINDOW B.coronalimage geom=${afni_size}x${afni_size}+${afni_size}+$((${afni_size} + 22))\n" > $in_afni
    echo -e "OPEN_WINDOW B.sagittalimage geom=${afni_size}x${afni_size}+$((2*${afni_size}))+$((${afni_size} + 22))\n" > $in_afni
    
    echo "Looking at:"
    echo "Study: ${study},Subject id: ${subject},Session: ${ses},Type: ${type},Sub Type: ${sub_type},Run: ${run},Echo: ${echo}"

    if [ "$1" != "-new" ] && [ "$1" != "-replace" ]; then
        error_exit "show_interact: wrong or null parameters! Giving up..."
    fi

    if [ "$1" = "-replace" ]; then
        echo "Current status and observation:"
        echo "${status}, ${obs}"
    fi

    if [[ $take_notes = 1 ]]; then
        Notes file_notes $l
    else 
        register
    fi
        
    if [[ $file_notes = 0 ]]; then

        if [ "$1" = "-new" ]; then
            echo "${new_status},${new_obs},${runs[$l]#*/}" >> $file
        fi

        if [ "$1" = "-replace" ]; then
            sed -i '${line}/.*/${new_status},${new_obs},${runs[$l]#*/}/' $file
        fi

    fi

}

# }}}2
# Função action {{{2
action(){

        local test_action go=0
    	if [[ $no_log = 0 ]]; then
          
            echo ${site_error},${sub_error},${study},${subject},${ses},${type},${sub_type},${run},${echo},${info[0]},${info[1]},${info[2]},${info[3]},${info[4]},${info[5]},${info[6]},${info[7]},${info[8]},${info[9]},${runs[$l]#*/},${size},${json[0]},${json[1]},${site},${json[2]},${json[3]},${json[4]},${json[5]},${json[6]},${json[7]},${json[8]},${json[9]},${json[10]},${json[11]} >> $file

        fi

    	if [[ $observate = 1 ]]; then

            if [[ $no_log = 0 ]]; then

	    		local input token
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
            else
                
                if [[ $no_afni = 0 ]]; then 

                    test_action=$(cat $cur_file".meta" | awk 'END{print $2}')
                    [[ $bad_notes = 1 ]] && [[ $test_action = 2 ]] && go=1
                    [[ $bad_notes = 0 ]] && go=1

                    if [[ $anat_notes = 1 ]]; then
                        
                        [[ $go = 1 ]] && [[ $type = "anat" ]] && [[ $echo = 0 ]] && show_interact -new

                    elif [[ $func_notes = 1 ]]; then

                        [[ $go = 1 ]] && [[ $type = "func" ]] && show_interact -new

                    else  

                        [[ $go = 1 ]] && show_interact -new

                    fi
                fi   
            fi
        fi

     	[[ $reorient = 1 ]] && re_orient
        [[ $new_fov = 1 ]] && fov_red
        [[ $clean = 1 ]] && mess_clean now $l
        
        [[ $unifize_bias = 1 ]] && [[ $type = anat ]] && [[ $echo = 0 ]] && unifize ${runs[$l]}

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
        local p

#       echo RUNS
#       echo ${runs[$k]%.*.*}
        for (( l=0; l<${json_len}; l++ )); do
            json[$p]=$(python -c 'import json; fp = open("'${runs[$l]%.*.*}'.json", "r"); obj = json.load(fp); fp.close(); print (obj["'${fields[$p]}'"])' 2>/dev/null)
            
#           echo ${json[$l]}
#           echo "RETURN:"$?

            if [ "$?" != 0 ]; then
                json[$p]=""
#               echo JSONERROR
            fi
#           echo ${json[$l]}
        done
    else
        l=$1
        if [ "$p" < 0 ] || [ "$p" > "${json_len}" ]; then
            error_exit "read_json: There is no field for index ${l}! Giving up..."
        fi
        json[$p]=$(python -c 'import json; fp = open("'${runs[$l]%.*.*}'.json", "r"); obj = json.load(fp); fp.close(); print (obj["'${fields[$p]}'"])' 2>/dev/null)
        if [ "$?" != 0 ]; then
            json[$p]=""
        fi

    fi

}

# }}}2
# Função mess_clean {{{2

mess_clean () 
{

    local index=$2 
    local type=$1
    local current_file current_data

    if [[ $type = "now" ]]; then

        current_file=${runs[$index]}
        [[ ! -f $current_file".meta" ]] && return

        current_data=($(cat $current_file".meta" | awk 'END{print $0}'))
        
        if [[ ${current_data[1]} = 3 ]]; then
            clean_array_files+=($current_file)
            clean_array_data+=(${current_data[2]})
            [[ ! -d tmp ]] && mkdir tmp
            mv $current_file tmp
            mv $current_file".meta" tmp
            mv ${current_file%%+*}".json" tmp

        fi    
    fi

    if [[ $type = "spit" ]]; then

        local length=${#clean_array_files[@]}
        local i
        echo -e "\nMess_clean - Moved files:"

        for (( i=0; i<$length; i++ )); do
            echo -n ${clean_array_files[$i]}" - "
            echo ${clean_array_data[$i]} | tr '_' ' '

        done    
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
# Função unifize {{{2
unifize()
{
    local input=$1
    local urad 
    local tmp=tmp_${input%%.*}
    local pid_fit
    local test=${input%%.*}
    
    if [[ $(echo $test | awk '{if ( $0 ~ /unifize/ ) { print 1}}') != 1 ]]; then
        echo "Running...${input}"
        cpu_queue
        urad=$(3dinfo -voxvol $input | awk '{print 18.3/$1^(1/3)}') 

        if [[ $sub_type = "T1w" ]]; then       
            3dUnifize -GM -Urad $urad -input $input -prefix ${input%%.*}+unifize.nii.gz &>/dev/null &
            [[ $? != 0 ]] && error_exit "3dUnifize: Something went wrong!"
            cpu_pid[$pid_fit]=$!
            
            exe_backup $input "unifize" ${pid_fit} &
        fi    
        if [[ $sub_type = "T2w" ]]; then
            3dUnifize -GM -T2 -Urad $urad -input $input -prefix ${input%%.*}+unifize.nii.gz &>/dev/null &
            [[ $? != 0 ]] && error_exit "3dUnifize: Something went wrong!"
            cpu_pid[$pid_fit]=$!
            
            exe_backup $input "unifize" ${pid_fit} &

        fi    
    else
        echo "File ${input} already unifized!"
    fi     
}
# }}}2
# Função bias_off {{{2

bias_off(){

    local input
    input=${runs[$l]}

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
    input=${runs[$l]}

    fslreorint2sdt $cur_file ${cur_file%%*.}"+"$reorient".nii.gz"


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

afni_size=400

# Set interface type

command -v dialog && has_dialog=1 || has_dialog=0

# }}}1za
# Processamento de comandos {{{1

interactive=0
no_log=0
observate=0
anat_notes=0
func_notes=0
file_notes=0
bad_file_notes=0
ses_notes=0
take_notes=0
afni_compare=0
reorient=0
new_fov=0
specific_study=0
deoblique=0
head_crop=0
verb=0
ignore_notes=0
clean=0
dead_sub=0
unifize_bias=0
no_afni=0
ignore_flag=0

NOW=`date +%d-%m-%y-%R`
logname="log."${NOW}
DIR=$HOME/Documents/fMRI_data
NOTE_DIR=$(pwd)

# }}}1
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
    				                    specific_study=1
    				                    study=$1
    			                        if [ "$study" = "" ]; then
    				    	                exit_error "--specific_study: Missing studyname!"
    				                    fi
    				                    ;;

        -v | --verbose )                verb=1
                                        ;;

        -fn | --file_notes )            take_notes=1
                                        file_notes=1
                                        no_log=1
                                        observate=1
                                        shift
                                        [[ $1 = "-"*i ]] || [[ ! $1 ]] && error_exit "--file_notes: Missing type!"
                                        case $1 in
                                            compare )       afni_compare=1
                                                            ;;
                                            simple )        ;;                     
                                        esac                    
                                        ;;

        -sn | --session_notes )         take_notes=1
                                        ses_notes=1                   
                                        no_log=1
                                        ;;

        -bn | --bad_notes )             bad_notes=1
                                        shift
                                        [[ $1 = "-"*i ]] || [[ ! $1 ]] && error_exit "--bad_notes: Missing type!"
                                        case $1 in
                                            anat )          anat_notes=1
                                                            ;;
                                            func )          func_notes=1
                                                            ;;        
                                        esac        
                                        ;;
## Ignore files that already has notes updated 

        -ig | --ignore_notes )          ignore_notes=1
                                        ;;

        -igf | --ignore_flag )          shift 
                                        [[ $1 = "-"*i ]] || [[ ! $1 ]] && error_exit "--ignore_flag: Missing type!"
                                        ignore_flag=1
                                        flag=$1
                                        ;;

        -clean | --mess_clean )         clean=1
                                        no_log=1
                                        declare -a clean_array_data
                                        declare -a clean_array_files
                                        ;;

        -ks | --kill_sub )              dead_sub=1
                                        no_log=1
                                        ;;

        -unif | --unifize )             unifize_bias=1
                                        no_log=1            
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

if [ $specific_study = "0" ]; then
    sub=($(find -mindepth 2 -maxdepth 2 -name "sub*" -type d))
else
    sub=($(find -maxdepth 1 -name "sub*" -type d))
fi

leni=${#sub[@]}

for (( i=0; i<$leni; i++ )); do

    if [ $specific_study = "0" ]; then

        study=${sub[$i]#*/}
        subject=${study#*-}
        study=${study%%/*}

    else

        subject=${sub[$i]#*-}

    fi

    error_tmp=$(pwd)
    cd ${sub[$i]}
    [[ $? != 0 ]] && error_exit "Directory ${sub[$i]} couldn't be accessed at $error_tmp!"
    
    [[ $bad_notes = 1 ]] && load_sub_notes $flag && cd - && continue 

    [[ $observate = 1 ]] && [[ $ignore_notes = 0 ]] && update_afni

    [[ $dead_sub = 1 ]] && remove_sub_condition
    

    if [[ $observate = 1 ]] && [[ $ignore_notes = 1 ]]; then 
        check_notes "subject" 
        [[ $? = 0 ]] && [[ $no_afni = 0 ]] && update_afni
    fi    

    sesdir=($(find -maxdepth 1 -name "ses-*" -type d))
    lenj=${#sesdir[@]}
    for (( j=0; j<$lenj; j++ )); do
    

        error_tmp=$(pwd)
        cd ${sesdir[$j]}
        [[ $? != 0 ]] && error_exit "Directory ${sesdir[$j]} couldn't be accessed at $error_tmp!" 
      
        ses=$(pwd)
        ses=${ses##*-}
        

        subdir=($(find -maxdepth 1 -mindepth 1 \( -name "anat" -or -name "func" \) -type d))
        lenk=${#subdir[@]}

        for (( k=0; k<$lenk; k++ )); do
            
            error_tmp=$(pwd)
            cd ${subdir[$k]}
            [[ $? != 0 ]] && error_exit "Directory ${subdir[$k]} couldn't be accessed at $error_tmp!" 

            type=$(pwd)
            type=${type##*/}

            runs=($(find -maxdepth 1 \( -name "*.nii.gz" -or -name "*.nii" \) -type f))

            lenl=${#runs[@]}

            for (( l=0; l<$lenl; l++ )); do

                runs[$l]=${runs[$l]#*/}
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
                check_sub=${runs[$l]#*-}         #A00000300_ses-20110101_acq-mprage_run-02_echo-01_T1w.nii.gz
                check_ses=${check_sub#*-}       #20110101_acq-mprage_run-02_echo-01_T1w.nii.gz
                check_sub=${check_sub%%_*}      #A00000300
                check_ses=${check_ses%%_*}      #20110101

                if [ $check_ses != $ses ]; then
                    echo "Warning: folder ses-${ses} doesn't match file ${runs[$l]}!"
                    warning=$((warning + 1))
                    sub_error="TRUE"
                fi

                if [ $check_sub != $subject ]; then
                    echo "Warning: folder sub-${subject} doesn't match file ${runs[$l]}!"
                    warning=$((warning + 1))
                    sub_error="TRUE"
                fi

                sub_type=${runs[$l]#*_*_}        #acq-mprage_run-02_echo-01_T1w.nii.gz
                sub_type=${sub_type%%.*}
                sub_type=${sub_type%%+*}       #acq-mprage_run-02_echo-01_T1w oder T2 oder task-rest_run-01_bold
                if [ $type = "anat" ]; then
                    
                    tmp=${sub_type%_*}

                  # if [[ $(echo $sub_type | grep -q "_") ]]; then
                  #         echo __ $tmp
                  #     tmp=${sub_type%_*}          #acq-mprage_run-02_echo-01
                  # else
                  #     tmp=;
                  # fi
                    sub_type=${sub_type##*_}    #T1w

                    if [[ $(echo $tmp | awk '{if ( $0 ~ /\_/ ) { print 1}}') ]]; then
                        tmp=${tmp#*_}           #run-02_echo-01
                    else
                        tmp=;
                    fi
                    
                    case $tmp in

                        "" )             run=0
                                         echo=0
                                         ;;
                        run-*_echo-* )
                                         run=${tmp#*-}    #02_echo-01
                                         run=${run%_*}    #02
                                         echo=${tmp##*-}   #01
                                         ;;
                        run-* )
                                         run=${tmp#*-}
                                         echo=0
                                         ;;

                        * )          run=0
                                     echo=0   

                    esac

                elif [ $type = "func" ]; then
                    echo=0
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
                
                if [[ $no_log = 0 ]]; then

                    size=$(du -k ${runs[$l]} | cut -f1)
                    info=($(3dinfo -orient -obliquity -adi -adj -adk -voxvol -n4 ${runs[$l]}))
        
                    read_json all
        #           echo "RETURN"$?
                    [[ $? != 0 ]] && error_exit "Something went wrong in 3dinfo!"

                fi
                cur_file=${runs[$l]#*/}
                action

            done

            cd ..

        done
        
        [[ $ses_notes = 1 ]] && Notes ses_notes

        cd ..
    done    
    cd $DIR
done

# }}}1


# Post proccess {{{1

[[ $observate = 1 ]] && kill $PID_TAIL && kill $PID_AFNI
[[ $clean = 1 ]] && mess_clean spit

wait 
# }}}1

echo "The end...There was ${warning} warnings!"

exit 0
