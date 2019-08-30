#!/bin/bash

#Teste

logname="nomelog"
no_log=0

while [ "$1" != "" ]; do
    case $1 in
	-l | --log )       shift
			   logname=$1
			   ;;
	-nl | --no_log )   no_log=1
	                   ;;
	-* | --* )                echo -e "\n${1} is not a valid parameter!\n"
			   exit 1
    esac
    shift
done

echo ${logname}
echo ${no_log}
