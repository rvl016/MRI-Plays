#!/bin/bash

###### For any session-wise note, parameter "-d" must be 
###### given so the program searchs for all "${filename}.meta"
###### and prints out then into user interface
#################### Input ######################################
###### -f $filename 
###### -d $dir (directory)
###### -t ( file | ses | log )
#################################################################
##############################  Envirioment variables {{{1

filenote=0
sesnote=0
lognote=0
##############################  }}}1
##############################  Data variables {{{1

declare -a sub ses type sub_type run echo 

##############################  }}}1    
##############################  Functions {{{1
##############################  exit_error {{{2
exit_error()
{
    echo -e "$1"
    exit 1
}

# }}}2
##############################  }}}2
##############################  Session_note {{{2

Session_note() 
{
    #### $1 = dir
    local dir=$1

    cd $dir 
    [[ $? != 0 ]] && exit_error "Could not change to directory ${dir}!"    
    
    data_array=($(find -mindepth 2 -maxdepth 2 -name *.meta -type f))
    length=${#data_array[@]}
    
    declare -a data_flags data_status data_note sub ses type sub_type run echo

    for (( i=0; i<$length; i++ )); do

        Specs_proccess ${data_array[$i]##*/} $i
        data_tmp=($(cat ${data_array[$i]} | tail -n 1))
        data_flags[$i]=${data_tmp[0]}
        data_status[$i]=${data_tmp[1]}
        data_note[$i]=${data_tmp[2]}
    done

    go=1
    while [[ $go = 1 ]]; do
        Dialog_interface_ses
    done
    
    if [[ ! -f "ses-"$ses".meta" ]]; then
       touch "ses-"$ses".meta" 
    fi
    echo "$(date +%D_%R) $status $note" >> ses-$ses.meta

}    

##############################  }}}2
##############################  Log_note {{{2

### Only for last incall and feedback to caller
Log_note()
{
    echo $status $note
}
##############################  }}}2
##############################  Specs_proccess {{{2

Specs_proccess() 
{
    
    #### $1 = filename
    #### $2 = index

    local fileinput=$1
    local index=$2
    local tmp 
    
    [[ -f ${fileinput}.meta ]] && last=1 || last=0
    if [[ $last = 1 ]]; then
        tmp=($(cat ${fileinput}.meta | awk 'END{ print $0 }'))
        last_note=${tmp[2]}
        last_status=${tmp[1]}
        last_flags=${tmp[0]}
    fi

    sub[$index]=${fileinput%%_*}
    sub[$index]=${sub[$index]#*-}

    ses[$index]=${fileinput#*-*_*-}
    ses[$index]=${ses[$index]%%_*}

    sub_type[$index]=${fileinput%%+*}
    sub_type[$index]=${sub_type[$index]%%.*}
    echo[$index]=${sub_type[$index]%_*}
    echo[$index]=${echo[$index]##*_}

    if [[ ${echo[$index]} = "run-"* ]]; then
        
        run[$index]=${echo[$index]#*-}
        echo[$index]="NULL"

    elif [[ ${echo[$index]} = "echo-"* ]]; then

        run[$index]=${fileinput%_*_*}
        run[$index]=${run[$index]##*-}

        echo[$index]=${echo[$index]#*-}

    else

        run[$index]="NULL"
        echo[$index]="NULL"

    fi    
    
    sub_type[$index]=${sub_type[$index]##*_}

    if [[ ${sub_type[$index]} = "bold" ]]; then

        sub_type[$index]="BOLD"
        type[$index]="func"

    else

        type[$index]="anat"
    
    fi
}    

##############################  }}}2
##############################  Dialog_interface_file {{{2

Dialog_interface_file()
{
    #### $1 = sub
    #### $2 = ses
    #### $3 = type
    #### $4 = sub_type
    #### $5 = run
    #### $6 = echo
    
    info=($(3dinfo -orient -obliquity -adi -adj -adk -voxvol -n4 $filename))

    [[ $last = 1 ]] && note=$(dialog --stdout --backtitle "Taking notes on $filename..." --title "Type an observation over the current file:" --cancel-label "Ignore File" --inputbox "Subject: $1\nSession: $2\nType: $3\nSub-Type: $4\nRun: $5\nEcho: $6\nOrientation: ${info[0]} | Obliquity: ${info[1]}\nVoxel dimensions: [${info[2]},${info[3]},${info[4]}] - ${info[5]}\nTotal size in voxels: ${info[6]}x${info[7]}x${info[8]} | Time poins: ${info[9]}\nLast flags: $last_flags | Last status: $last_status" 15 90 "$last_note" ) || note=$(dialog --stdout --backtitle "Taking notes on $filename..." --title "Type an observation over the current file:" --cancel-label "Ignore File" --inputbox "Subject: $1\nSession: $2\nType: $3\nSub-Type: $4\nRun: $5\nEcho: $6\nOrientation: ${info[0]} | Obliquity: ${info[1]}\nVoxel dimensions: [${info[2]},${info[3]},${info[4]}] - ${info[5]}\nTotal size in voxels: ${info[6]}x${info[7]}x${info[8]} | Time poins: ${info[9]}" 14 90)

    [[ $? = 1 ]] && dialog --backtitle "Taking notes on $filename" --title "Are you sure you want to abort this note?" --yesno "" 4 60 && exit 1

    [[ $last = 1 ]] && status=$(dialog --stdout --backtitle "Taking notes on $filename" --title "Select an status for the current filename:" --cancel-label "Ignore File" --default-item "$last_status" --menu "Note taken: $note" 7 100 0 0 "Good to go" 1 "Some problem" 2 "A lot of problem (some step needs to be redone)" 3 "Unusable (declare dead)") || status=$(dialog --stdout --backtitle "Taking notes on $filename" --title "Select an status for the current filename:" --cancel-label "Ignore File" --menu "Note taken: $note" 7 100 0 0 "Good to go" 1 "Some problem" 2 "A lot of problem (some step needs to be redone)" 3 "Unusable (declare dead)")

    
    [[ $? = 1 ]] && dialog --backtitle "Taking notes on $filename" --title "Are you sure you want to abort this note?" --yesno "" 4 60 && exit 1

    dialog --backtitle "Taking notes on $filename" --title "Is it right?" --yesno "Status: $status \nNote: $note" 6 100
    
    go=$?

    note=$(echo $note | tr ' ' '_')

}    

##############################  Dialog_interface_ses {{{2

Dialog_interface_ses()
{
    #### $1 = sub
    #### $2 = ses
    #### $3 = type
    #### $4 = sub_type
    #### $5 = run
    #### $6 = echo
    #### $7 = index
#    echo $1 $2 $3 $4 $5 $6 $7 $8 $9 $10
#    local sub=$1 ses=$2 type=$3 sub_type=$4 run=$5 
#    local echo=$6 length=$7 data_flags=$8 data_status=$9 data_note=$10
    local i
    local outdiag="\n"

    for (( i=0; i<$length; i++ )); do
        
        outdiag=$outdiag"Flags: "${data_flags[$i]}" | Sub_Type: "${sub_type[$i]}" | Run: "${run[$i]}" | Echo: "${echo[$i]}" | "
        outdiag=$outdiag"Status: "${data_status[$i]}" | Note: "${data_note[$i]}"\n"
        
    done    

    note=$(dialog --backtitle "Taking notes on session $ses from subject $sub..." --title "Type an observation over the current session:" --cancel-label "Ignore Session" --stdout --inputbox "$outdiag" $((6+$i)) 120) 
    
    #$outdiag $((4+2*$i)) 120)

    [[ $? = 1 ]] && dialog --backtitle "Taking notes on session $2 from subject $1..." --title "Are you sure you want to abort this note?" --yesno "" 4 60 && exit 1

    status=$(dialog --backtitle "Taking notes on session $ses from subject $sub..." --title "Select an status for the current session:" --cancel-label "Ignore Session" --stdout --menu "Note taken: $note" 7 100 0 0 "Good to go" 1 "See if other sessions may recovery" 2 "Unusable (declare dead)")
    
    [[ $? = 1 ]] && dialog --backtitle "Taking notes on $filename" --title "Are you sure you want to abort this note?" --yesno "" 4 60 && exit 1

    dialog --backtitle "Taking notes on session $ses from subject $sub..." --title "Is it right?" --yesno "Status: $status \nNote: $note" 6 100

    go=$?

    note=$(echo $note | tr ' ' '_')
}    

##############################  }}}2
##############################  }}}2
##############################  }}}1
##############################
##############################  Input processing {{{1

while [ "$1" != "" ]; do 
    case $1 in 
        
        -f | --file )                   shift
                                        filename=$1
                                        [[ ! $filename ]] && exit_error "--file: Missing filename"
                                        ;;

        -t | --type )                   shift
                                        obs_type=$1
                                        case $obs_type in 
                                            
                                            all )           filenote=1
                                                            sesnote=1
                                                            lognote=1
                                                            ;;

                                            nolog )         filenote=1
                                                            sesnote=1
                                                            ;;

                                            file )          filenote=1
                                                            ;;
                    
                                            ses )           sesnote=1
                                                            ;;
                                            log )           lognote=1
                                                            
                                        esac
                                        ;;

        -d | --directory )              shift
                                        dir=$1
                                        ;;

        * )                             exit_error "Parameter $1 does not exist!"                                     
    esac
    shift
done    

[[ $sesnote = 0 ]] && [[ $filenote = 0 ]] && [[ $lognote = 0 ]] && exit_error "Nothing to do here!" 
[[ $filenote = 1 ]] && [[ ! $filename ]] && exit_error "No filename provided!"
##############################  }}}1
##############################  Main {{{1

if [[ $filenote = 1 ]]; then
    
    cd $dir 
    [[ $? != 0 ]] && exit_error "Directory $dir could not be accessed!"

    [[ ! -f $filename ]] && exit_error "File $filename does not exist!"

    Specs_proccess $filename 0
    go=1
    while [[ $go = 1 ]]; do
        Dialog_interface_file $sub $ses $type $sub_type $run $echo
    done
    
    if [[ ! -f $filename".meta" ]]; then
        touch $filename".meta"    
    fi 
    tmp=${filename#*+}
    [[ $tmp = "sub-"* ]] && tmp="none"

    echo "${tmp%%.*} $status $note" >> $filename".meta"  

fi

[[ $sesnote = 1 ]] && Session_note $dir

#if [[ $lognote = 1 ]]; then

#fi

exit 0

##############################  }}}
