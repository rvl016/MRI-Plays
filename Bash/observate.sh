#!/bin/bash

NOTE_DIR="/home/ravi/HD2TB/Documents/IC/Implementações/Bash"
AFNI_SIZE=400

error_exit()
# {{{        
{
   echo -e "$1"
   exit 1
}
# }}}        
# MKFIFOs...
creat_pipes()
# {{{        
{
   [[ ! -p inpipe ]] && mkfifo inpipe
   [[ $? != 0 ]] && error_exit "Pipe could not be touched!"
   in_afni=$(pwd)"/inpipe"
   [[ ! -p outpipe ]] && mkfifo outpipe
   #[[ $? != 0 ]] && error_exit "Pipe could not be touched!"
   out_plug=$(pwd)"/outpipe"
}
# }}}        
# ABRE AFNI e PLUGOUT
update_afni()
# {{{        
{
   [[ -z ${PID_AFNI+x} ]] && kill $PID_AFNI
   [[ -z ${PID_PLUG+x} ]] && kill $PID_PLUG
   [[ -z ${PID_TAIL+x} ]] && kill $PID_TAIL
########################################################################
   [[ $AFNI_COMPARE = 1 ]] && afni -yesplugout -R3 -com "OPEN_WINDOW B"\
      &>/dev/null & 
   [[ $AFNI_COMPARE = 0 ]] && afni -yesplugout -R2 -com \
         "OPEN_WINDOW A.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+0+22"\
         -com\
         "OPEN_WINDOW A.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}+\
         ${AFNI_SIZE}+22" -com "OPEN_WINDOW A.sagittalimage geom=\
         ${AFNI_SIZE}x${AFNI_SIZE}+$((2*${AFNI_SIZE}))+22" &>/dev/null &
   wait 
   [[ $? != 0 ]] && error_exit "Something went wrong with AFNI!"
   PID_AFNI=$(ps -e | awk '$4=="afni" {printf "%d",$1}')
   [[ $PID_AFNI = "" ]] && error_exit "AFNI PID could not be gotten!"
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
Notes()
# {{{        
{
   local notetype=$1
   local i=$2
   if [[ $notetype = "ses_notes" ]]; then
      $NOTE_DIR/take_notes.sh --type ses --directory $(pwd)
   fi
   if [[ $notetype = "file_notes" ]]; then    
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
   fi    
   [[ $? != 0 ]] && error_exit \
      "Something went wrong with 'take_notes.sh'!"
}    
# }}}        
Show_interact()
# {{{
{
   local i=$1
########################################################################
   if [ $# = 0 ]; then
    error_exit "show_interact: Missing arguments!"
   fi
   if [ "$sub_error" = "TRUE" ]; then 
      echo error_exit "File ${files[$i]#*/} is in wrong path! \
            (Subject: ${subject}, Session: ${ses})"
   fi
   echo -e "SWITCH_DIRECTORY A.ses-${ses}/${type}\n" > $in_afni
   [[ $AFNI_COMPARE = 1 ]] && echo -e \
         "SWITCH_DIRECTORY B.ses-${ses}/${type}/tmp\n" > $in_afni
   echo -e "SWITCH_UNDERLAY A.${files[$i]}\n" > $in_afni
   [[ $AFNI_COMPARE = 1 ]] && echo -e \
         "SWITCH_UNDERLAY B.${files[$i]%+*}.nii.gz\n" > $in_afni

   echo -e "OPEN_WINDOW A.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}\
         +0+22\n" > $in_afni
   echo -e "OPEN_WINDOW A.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}\
         +${AFNI_SIZE}+22\n" > $in_afni
   echo -e "OPEN_WINDOW A.sagittalimage geom=${AFNI_SIZE}x${AFNI_SIZE}\
         +$((2*${AFNI_SIZE}))+22\n" > $in_afni
   echo -e "OPEN_WINDOW B.axialimage geom=${AFNI_SIZE}x${AFNI_SIZE}+\
         1+$((${AFNI_SIZE} + 22))\n" > $in_afni
   echo -e "OPEN_WINDOW B.coronalimage geom=${AFNI_SIZE}x${AFNI_SIZE}\
         +${AFNI_SIZE}+$((${AFNI_SIZE} + 22))\n" > $in_afni
   echo -e "OPEN_WINDOW B.sagittalimage geom=${AFNI_SIZE}x${AFNI_SIZE}\
         +$((2*${AFNI_SIZE}))+$((${AFNI_SIZE} + 22))\n" > $in_afni
   echo "Looking at:"
   echo "Study: ${study},Subject id: ${subject},Session: ${ses},Type:\
         ${type},Sub Type: ${sub_type},Run: ${run},Echo: ${echo}"
   Notes file_notes $i
}
# }}}        

# main($1 = notetype[ses|file], $2 = directory [ses|sub], $3 = compare\
#, $4 = files) 
# {{{  
argc=$#
argv=$@
notetype=${argv[0]}
dir=${argv[1]}
AFNI_COMPARE=${argv[2]}
declare -a files
for ((i = 3; i < $argc; i++)); do
   files[$((i - 3))]=$argv[$i]
done   
create_pipes
cd $dir
update_afni $notetype
for ((i = 0; i < ${#files[@]}; i++)); do
   
done
if 
rm $in_afni
rm $out_plug
return 0
[[ $cancel = 1 ]] && return 127
# }}}        
