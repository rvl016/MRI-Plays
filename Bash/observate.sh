#!/bin/bash
NOTE_DIR="/home/ravi/HD2TB/Documents/IC/MRI-Plays/Bash"
#NOTE_DIR="/home/ravi/Git/MRI-Plays/Bash"
TEMPLPATH="/home/ravi/HD2TB/Documents/IC/MNI_Template/"
AFNI_SIZE=400
DEBUG_AFNI="/dev/null"
DEBUG=0

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
   cd /tmp
   if [[ -p inpipe ]]; then
      rm inpipe
   fi   
   mkfifo inpipe
   [[ $? != 0 ]] && error_exit "Pipe could not be touched!"
   in_afni=$(pwd)"/inpipe"
   if [[ -p outpipe ]]; then
      rm outpipe
   fi
   mkfifo outpipe 
   [[ $? != 0 ]] && error_exit "Pipe could not be touched!"
   out_plug=$(pwd)"/outpipe"
   cd -
}
# }}}        
sendPlugcmd()
# {{{        
{
   local cmd=$1
   if [ $DEBUG = 1 ]; then
      echo "COMMAND: " $cmd
   fi
   head -c 15 $out_plug &>/dev/null & 
   PLUGOUT_CHECK=$!
   echo -e $cmd > $in_afni
   if [ $DEBUG = 1 ]; then
      echo "Waiting for plugout."
   fi
   wait $PLUGOUT_CHECK
   if [ $DEBUG = 1 ]; then
      echo "Plugout awnsered!"
   fi
  #cat $out_plug &>/dev/null
   return
}   
# }}}        
# ABRE AFNI e PLUGOUT
update_afni()
# {{{        
{
   [[ -z ${PID_AFNI+x} ]] && kill $PID_AFNI &>/dev/null
   pkill afni
   [[ -z ${PID_PLUG+x} ]] && kill $PID_PLUG &>/dev/null
   pkill tail
   [[ -z ${PID_TAIL+x} ]] && kill $PID_TAIL &>/dev/null
########################################################################
   if [[ $AFNI_COMPARE = 2 ]]; then 
      afni -YESplugouts -R3 -purge -com "OPEN_WINDOW A \
         geom=+0+$((${AFNI_SIZE}+22))" ./ ${TEMPLPATH} &>$DEBUG_AFNI & 
   fi
   if [[ $AFNI_COMPARE = 1 ]]; then 
      afni -YESplugouts -R3 -purge -com "OPEN_WINDOW A \
         geom=+0+$((2*${AFNI_SIZE}+22))" -com \
         "OPEN_WINDOW B geom=+700+$((2*${AFNI_SIZE}+22))"\
         ./ ${TEMPLPATH} &>$DEBUG_AFNI & 
      sleep 4
   fi
   if [[ $AFNI_COMPARE = 0 ]]; then 
      afni -YESplugouts -R2 -purge -com \
         "OPEN_WINDOW A geom=+0+$((2*${AFNI_SIZE}+22))" -com \
         "OPEN_WINDOW A.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+0+22"\
         -com\
         "OPEN_WINDOW A.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+\
         ${AFNI_SIZE}+22" -com "OPEN_WINDOW A.sagittalimage geom=\
         ${AFNI_SIZE}x${AFNI_SIZE}+$((2*${AFNI_SIZE}))+22"\
	 &>$DEBUG_AFNI &
   fi
   [[ $? != 0 ]] && error_exit "Something went wrong with AFNI!"
  #dialog --msgbox "Only ${remaining} left! =]\nPress return when AFNI\
#is ready: " 7 40
   dialog --infobox "Only ${remaining} left! =]" 7 40
   PID_AFNI=$(ps -e | awk '$4=="afni" {printf "%d",$1}')
   [[ $PID_AFNI = "" ]] && error_exit "AFNI PID could not be got!"
########################################################################
   echo "Starting plugout_drive..."
   head -c 1 $out_plug &>/dev/null & 
   PLUGOUT_CHECK=$!
   tail -n +1 -f $in_afni | plugout_drive &>$out_plug &    
   [[ $? != 0 ]] && \
         error_exit "Something went wrong with plugout_drive!"
   PID_TAIL=$! 
   wait $PLUGOUT_CHECK
   echo "Plugout awnsered!"
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
      path=$(dirname $(find . -type f | grep '/'${files[$i]}'$'))
      path=${dir}${path#*.}
      if [[ $ignore_notes = 1 ]]; then
	      check_notes file ${i} 
         if [[ $? = 0 ]]; then 
            $NOTE_DIR/take_notes.sh file ${path}/${files[$i]}
         fi
      else    
         $NOTE_DIR/take_notes.sh file ${path}/${files[$i]}
      fi     
      ret=$?
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
   if [[ $AFNI_COMPARE -le 1 ]]; then
      sendPlugcmd "SWITCH_DIRECTORY A.All_Datasets\n"
      sendPlugcmd "SWITCH_UNDERLAY A.${files[$(($i+1))]}\n"
   fi
   if [[ $AFNI_COMPARE = 1 ]]; then
      sendPlugcmd "SWITCH_DIRECTORY B.All_Datasets\n"
      sendPlugcmd "SWITCH_UNDERLAY B.${files[$(($i))]}\n" 
      sendPlugcmd "OPEN_WINDOW B.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+1+$((${AFNI_SIZE} + 22))\n"
      sendPlugcmd "OPEN_WINDOW B.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+${AFNI_SIZE}+$((${AFNI_SIZE} + 22))\n"
      sendPlugcmd "OPEN_WINDOW B.sagittalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+$((2*${AFNI_SIZE}))+$((${AFNI_SIZE} + 22))\n"
      sendPlugcmd "SET_DICOM_XYZ B 0 0 0"
   fi
   if [[ $AFNI_COMPARE = 2 ]]; then
      sendPlugcmd "SWITCH_DIRECTORY A.All_Datasets\n"
      sendPlugcmd "SWITCH_OVERLAY A.${files[$(($i+1))]}\n"
      sendPlugcmd "SWITCH_UNDERLAY A.${files[$(($i))]}\n" 
   fi
   sendPlugcmd "OPEN_WINDOW A.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+0+22\n" 
   sendPlugcmd "OPEN_WINDOW A.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+${AFNI_SIZE}+22\n"
   sendPlugcmd "OPEN_WINDOW A.sagittalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+$((2*${AFNI_SIZE}))+22\n"
   sendPlugcmd "SET_DICOM_XYZ A 0 0 0"
   Notes $notetype $i
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
#, $4 = remaining, $5 = files) 
argc=$#
argv=($@)
notetype=${argv[0]}
dir=${argv[1]}
AFNI_COMPARE=${argv[2]}
remaining=${argv[3]}
declare -a files
declare -a fdirs 
for ((i = 4; i < $argc; i++)); do
   files[$((i - 4))]=${argv[$i]}
done   
create_pipes
cd $dir
[[ $notetype = "file" ]] && update_afni $AFNI_COMPARE && specs_process
for ((i = 0; i < ${#files[@]}; i++)); do
   Show_interact $i 
   if [[ $AFNI_COMPARE > 0 ]]; then
      let "i++"
   fi
done
rm $in_afni
rm $out_plug
exit 0
