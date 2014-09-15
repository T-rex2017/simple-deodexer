#!/bin/bash
pagebreak="************************************************************"
rootdir=$(pwd)
chmod 0755 tools/*
version=$(cat tools/version.txt)

if [ ! -d triage ]; then
	mkdir triage
	cd triage
	mkdir app
	mkdir framework
	mkdir priv-app
	cd ../
fi

if [[ ! $1 ]] && [[ ! $2 ]]; then
	tools/help.sh 3
	exit 0
fi

zpln() {
	$rootdir/tools/zipalign -f -v 4 $1 ./temporary-file
	rm -f $1
	mv ./temporary-file $1
	echo
}

deodex_file() {
	echo
	odex_file=$1

	if [ "$odex_file" == "" ]
	then
	  echo "Error: No .odex file specified"

	elif [ -e $odex_file ]
	then
	  echo "Working on $odex_file"
	  echo "- Disassembling $odex_file"
	else
	  echo "Error: $odex_file not found"
	fi
	
	# Call baksmali

	java -Xmx512m -jar ../../tools/baksmali-$version.jar -a $api_level -d ../framework -x $odex_file
	is_error=$?

	
	# If there were no errors, then assemble it with smali

	if [ "$is_error" == "0" ] && [ -d out ]
	then

	  echo "- Assembling into classes.dex"
	  java -Xmx512m -jar ../../tools/smali-$version.jar -a $api_level -o classes.dex out

	  rm -rf out
	  
	  # Ensure classes.dex was produced
	  
	  if [ -e classes.dex ]
	  then

		# Ensure the .odex file's .apk or .jar is found
		no_ext=`echo $odex_file | sed 's/.odex//'`
		main_file=$no_ext.apk

		error_found=no

		if [ -e $main_file ]
		then
		  ext=apk
		else
		  main_file=$no_ext.jar
		  
		  if [ -e $main_file ]
		  then
			ext=jar
		  else          
			echo "ERROR: Can't find $no_ext.jar or $no_ext.apk"
			error_found=yes
		  fi
		fi


		if [ $error_found == yes ]
		then

		  echo "- Removing classes.dex"
		  rm -f classes.dex

		  # Keep the odex file so that it's left unchanged

		else

		  echo "- Removing $odex_file"
		  rm -f $odex_file

		  echo "- Putting classes.dex into $main_file"
		  zip -r -q $main_file classes.dex
		  rm -f classes.dex
		  if [ -e $main_file ]
		  then
			echo "$main_file has been deodexed"
		  fi
		
		fi

	  else
		echo "WARNING: Unable to produce classes.dex!"
	  fi          

	else
	  echo "WARNING: Cannot deodex $odex_file"
	  rm -rf out
	fi
}

count_odex() {
	cd triage/$1
		for f in $(ls *.odex)
		do
			count=$(($count+1))
	done
			
	echo $count
}

if [[ ! $1 == "" ]]; then
	if [ $1 == "-h" ]; then
		tools/help.sh
		exit 0
	elif [ $1 == "-a" ]; then
		processDirList=( app )
		printf '\033c'
		echo "$(count_odex app) odex files are in /app."
	elif [ $1 == "-p" ]; then
		processDirList=( app )
		printf '\033c'
		echo "$(count_odex priv-app) odex files are in /priv-app."
	elif [ $1 == "-f" ]; then
		processDirList=( framework )
		printf '\033c'
		echo "$(count_odex framework) odex files are in /app."
		cp tools/java.awt.jar triage/framework/java.awt.jar
	elif [ $1 == "-x" ]; then
		printf '\033c'
		echo "Cleaning up"
		echo "- app"
		rm -fR triage/app
		mkdir triage/app
		echo "- framework"
		rm -fR triage/framework
		mkdir triage/framework
		echo "- priv-app"
		rm -fR triage/priv-app
		mkdir triage/priv-app
		echo "Done."
		exit 0
	elif [ $1 == "-b" ]; then
		processDirList=( app framework )
		printf '\033c'
		echo "$(count_odex app) odex files are in /app."
		echo "$(count_odex framework) odex files are in /framework."
	elif [ $1 == "-bb" ]; then
		printf '\033c'
		processDirList=( app framework priv-app )
		echo "$(count_odex app) odex files are in /app."
		echo "$(count_odex framework) odex files are in /framework."
		echo "$(count_odex priv-app) odex files are in /priv-app."
	elif [ $1 == "-z" ]; then
		printf '\033c'
		processDirList=( app framework priv-app )
		for processDir in $processDirList
			do
				cd triage/$processDir
				for f in $(ls *.apk)
					do
						zpln $f
				done
		done
	elif [ $1 == "-zz" ]; then
		printf '\033c'
		cd triage/app
		for f in $(ls *.apk)
			do
				zpln $f
		done
	elif [ $1 == "-zzz" ]; then
		printf '\033c'
		cd triage/framework
		for f in $(ls *.apk)
			do
				zpln $f
		done
	elif [ $1 == "-zzzz" ]; then
		printf '\033c'
		cd triage/priv-app
		for f in $(ls *.apk)
			do
				zpln $f
		done
	elif [ $1 == "-j" ]; then
		tools/change.sh
		exit 0
	fi
elif [[ ! $1 ]] && [[ $2 != "" ]]; then
	tools/help.sh 4
else
	tools/help.sh 2 $1
	exit 0
fi

if [[ ! $2 ]] && [ $1 == "-hh" ]; then
	tools/guide.sh
	exit 0
elif [[ ! $2 ]] && [[ $1 != "" ]]; then
	tools/help.sh 1
	exit 0
else
	api_level=$2
fi

for processDir in $processDirList
	do
		cd triage/$processDir
		for f in $(ls *.odex)
			do
				deodex_file $f
		done
		echo ""
		echo "Zipaligning APKs"
		for f in $(ls *.apk)
			do
				zpln $f
		done
done

echo
if [ -e $rootdir/triage/framework/java.awt.jar ]; then
	rm $rootdir/triage/framework/java.awt.jar
fi

echo "Done."
echo ""

exit 0