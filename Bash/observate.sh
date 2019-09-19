#!/bin/bash
NOTE_DIR="/home/ravi/HD2TB/Documents/IC/MRI-Plays/Bash"
AFNI_SIZE=400

error_exit()
# {{{        
{
   echo -e "$1"
   exit 1
}
# }}}        
create_pipes()
# {{{        
{
   if [[ ! -p inpipe ]]; then
      mkfifo inpipe
      [[ $? != 0 ]] && error_exit "Pipe could not be touched!"
   fi   
   in_afni=$(pwd)"/inpipe"
   if [[ ! -p outpipe ]]; then
      mkfifo outpipe 
      [[ $? != 0 ]] && error_exit "Pipe could not be touched!"
   fi
   out_plug=$(pwd)"/outpipe"
}
# }}}        
# ABRE AFNI e PLUGOUT
update_afni()
# {{{        
{
   [[ -z ${PID_AFNI+x} ]] && kill $PID_AFNI
   pkill afni
   [[ -z ${PID_PLUG+x} ]] && kill $PID_PLUG
   pkill tail
   [[ -z ${PID_TAIL+x} ]] && kill $PID_TAIL
########################################################################
   if [[ $AFNI_COMPARE = 1 ]]; then 
      afni -yesplugout -R3 -com "OPEN_WINDOW A geom=+0+\
         $((2*${AFNI_SIZE}+22))" -com \
         "OPEN_WINDOW B geom=+700+$((2*${AFNI_SIZE}+22))" &>/dev/null & 
   fi
   if [[ $AFNI_COMPARE = 0 ]]; then 
      afni -yesplugout -R2 -com \
         "OPEN_WINDOW A geom=+0+$((2*${AFNI_SIZE}+22))" -com \
         "OPEN_WINDOW A.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+0+22"\
         -com\
         "OPEN_WINDOW A.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+\
         ${AFNI_SIZE}+22" -com "OPEN_WINDOW A.sagittalimage geom=\
         ${AFNI_SIZE}x${AFNI_SIZE}+$((2*${AFNI_SIZE}))+22" &>/dev/null &
   fi
echo ===============================
   wait 
echo ===============================
   [[ $? != 0 ]] && error_exit "Something went wrong with AFNI!"
   PID_AFNI=$(ps -e | awk '$4=="afni" {printf "%d",$1}')
   [[ $PID_AFNI = "" ]] && error_exit "AFNI PID could not be got!"
########################################################################
   echo "Starting plugout_drive..."
   tail -n +1 -f $in_afni | plugout_drive &>/dev/null &    
   PID_TAIL=$! 
   [[ $? != 0 ]] && \
         error_exit "Something went wrong with plugout_drive!"
#   echo -e "OPEN_WINDOW A.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+0+22\n" > $in_afni
#   echo -e "OPEN_WINDOW A.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+${AFNI_SIZE}+22\n" > $in_afni
#   echo -e "OPEN_WINDOW A.sagittalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+$((2*${AFNI_SIZE}))+22\n" > $in_afni
#    [[ $AFNI_COMPARE = 1 ]] && echo -e "OPEN_WINDOW B\n" > $in_afni
   PID_PLUG=$(ps -e | awk '$4=="plugout_drive" {printf "%d",$1}')
}
# }}}        
#  Função para chamar o take_notes.sh
Notes()
# {{{        
{
   local notetype=$1
   local i=$2
   if [[ $notetype = "ses" ]]; then
      $NOTE_DIR/take_notes.sh --type ses --directory $(pwd)
      ret=$?
   fi
   if [[ $notetype = "file" ]]; then    
      cd ${fdirs[$i]}
      echo $(pwd)
      if [[ $ignore_notes = 1 ]]; then
         check_notes file ${i} 
         if [[ $? = 0 ]]; then 
            $NOTE_DIR/take_notes.sh --type file --file ${files[$i]}\
                  --directory $(pwd)
         fi
      else    
         $NOTE_DIR/take_notes.sh --type file --file ${files[$i]}\
            --directory $(pwd) 
      fi     
      ret=$?
      cd -
   fi    
   [[ $ret != 0 ]] && error_exit \
      "Something went wrong with 'take_notes.sh'!"
}    
# }}}        
Show_interact()
# {{{
{
   local i=$1
   if [ $# = 0 ]; then
    error_exit "show_interact: Missing arguments!"
   fi
   if [ "$sub_error" = "TRUE" ]; then 
      echo error_exit "File ${files[$i]#*/} is in wrong path! \
            (Subject: ${subject}, Session: ${ses})"
   fi
   echo -e "SWITCH_DIRECTORY A.${fdirs[$i]}\n" > $in_afni
   if [[ $AFNI_COMPARE = 1 ]]; then
      echo -e "SWITCH_DIRECTORY B.${fdirs[$i]}/tmp\n" > $in_afni
   fi
   echo -e "SWITCH_UNDERLAY A.${files[$i]}\n" > $in_afni
   if [[ $AFNI_COMPARE = 1 ]]; then
      if [[ ${files[$i]%+*} = ${files[$i]} ]]; then
         echo "File ${files[$i]} is raw! No comparison."
      else
         echo -e "SWITCH_UNDERLAY B.${files[$i]%+*}.nii.gz\n" > $in_afni
      fi   
   fi
   echo -e "OPEN_WINDOW A.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+0+22\n" > $in_afni
   echo -e "OPEN_WINDOW A.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+${AFNI_SIZE}+22\n" > $in_afni
   echo -e "OPEN_WINDOW A.sagittalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+$((2*${AFNI_SIZE}))+22\n" > $in_afni
   if [[ $AFNI_COMPARE = 1 ]]; then
      echo -e "OPEN_WINDOW B.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+1+$((${AFNI_SIZE} + 22))\n" > $in_afni
      echo -e "OPEN_WINDOW B.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+${AFNI_SIZE}+$((${AFNI_SIZE} + 22))\n" > $in_afni
      echo -e "OPEN_WINDOW B.sagittalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+$((2*${AFNI_SIZE}))+$((${AFNI_SIZE} + 22))\n" > $in_afni
   fi
  #Notes $notetype $i
   read
}
# }}}        
specs_process() 
# {{{        
{
   local i tmp 
   for (( i=0; i<${#files[@]}; i++ )); do
      fdirs[$i]=${files[$i]#*_}
      fdirs[$i]=${fdirs[$i]%%_*}
      tmp=${files[$i]%%+*}
      tmp=${tmp%%.*}
      tmp=${tmp##*_}
      if [[ $tmp = "bold" ]]; then
         fdirs[$i]=${fdirs[$i]}"/func"
      else
         fdirs[$i]=${fdirs[$i]}"/anat"
      fi
   done   
}    
# }}}        
# main($1 = notetype[ses|file], $2 = directory [ses|sub], $3 = compare\
#, $4 = files) 
argc=$#
argv=($@)
notetype=${argv[0]}
dir=${argv[1]}
AFNI_COMPARE=${argv[2]}
echo $AFNI_COMPARE
read
declare -a files
declare -a fdirs 
for ((i = 3; i < $argc; i++)); do
   files[$((i - 3))]=${argv[$i]}
done   
create_pipes
cd $dir
[[ $notetype = "file" ]] && update_afni $AFNI_COMPARE && specs_process
for ((i = 0; i < ${#files[@]}; i++)); do
   Show_interact $i 
   [[ $cancel = 1 ]] && return 127
done
rm $in_afni
rm $out_plug
exit 0
