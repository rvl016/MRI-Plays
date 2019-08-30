echo $1 $2 $3 $4
while [ "$1" != "" ] ; do
    case $1 in
	-l | --log )                shift
	                            logname=$1
			            echo $1
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
	-orient | --reorient )      reorient=$1
			            if [ "$reorient" != "" ]; then
				    	exit_error "Missing new orientation!"
				    fi
				    ;;
	-ss | --specific_study )    DIR=$DIR"/"$1
				    spec_study=1
				    study=$1
				    ;;
	* )                  echo "$1 is not a valid command!"
    esac
    shift
done
