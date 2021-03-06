#!/bin/bash

#
# Integrity Check for web sites: Createed local repository for PHP files and
#	check MD5 sum for them
#
# Version 1.4
#
# Config file format: site:ftpuser:ftppass:versions_to_keep
#
# 2012-12-16 FLX f@qsol.ro
#	- Added -k to keep a specific number of versions. Also added the fourth field in config file
#
# 2012-12-16 FLX f@qsol.ro
#	- Created generic version
#
# 2012-12-16 FLX f@qsol.ro
#	- Modified to fully use parameters
#
# 2012-12-05 FLX f@qsol.ro
#	- Added option to update baseline
#
# 2012-12-4 FLX f@qsol.ro
#	- Started
#
#
#

#####################################################################
#
#	Global Configure section
#
#####################################################################

cfg_file='/root/.icheck.cfg'
versions_to_keep=0

working_dir='/root/icheck'
sysadmin='sysadmin@qwerty-sol.ro'
#sysadmin='f@qsol.ro'

log_file_prefix="check.result"
md5_file_prefix="md5.baseline"

#####################################################################

function PRINT_USAGE(){
  echo "This script check a site for modifications:
  -s site to work on
  -f config file
  -k versions to keep (site files and check results)
  -c check md5sum
  -u update
  -i init
  -h prints out this help
You must at least specify check or update."
  exit 0
}

function LOG(){
	local msg="$1"
	echo `date +"%Y-%m-%d %H:%M:%S"` $msg >> $site.$log_file_prefix
}

function EOJ(){
	local exit_code=$1
	LOG "Exiting"
	
	cat $site.$log_file_prefix | mailx -s "$site integrity check" $sysadmin

	exit $exit_code
}

function UPDATE {
	LOG "Update started ..."

	mv $site.$md5_file_prefix $site.$md5_file_prefix.$now
	find . -path "./$site/*" -name "*.php"  -exec md5sum '{}' \; > $site.$md5_file_prefix

	LOG "Update finished." 
}

function CLEAN {
	LOG "Clean started ..."

	if [ "$versions_to_keep" -ge "0" ] ; then
		LOG "  Keeping $versions_to_keep versions"
		site_dirs=$( ls -trd $site.20* | head --lines=-$versions_to_keep )
		LOG "  site_dirs: $site_dirs="
		log_files=$( ls -tr $site.$log_file_prefix.20* | head --lines=-$versions_to_keep )
		LOG "  log_files: $log_files="
		md5_files=$( ls -tr $site.$md5_file_prefix.20* | head --lines=-$versions_to_keep )
		LOG "  md5_files: $md5_files="
		for fl in $site_dirs $log_files $md5_files ; do
			LOG "Remove file: $fl"
		done
	else
		LOG "  Keeping ALL ($versions_to_keep) versions"
	fi
	
	LOG "Clean finished." 
}

function CHECK {
	LOG "Check started ..."

	mv $site $site.$now
	LOG "  Start wget ..."
	wget --ftp-user=$ftpuser --ftp-password=$ftppassword --mirror -A php ftp://$site/
	LOG "  End wget."

	LOG "  Start md5sum ..."
	md5sum --check $site.$md5_file_prefix |grep -v OK | tee -a $site.$log_file_prefix
	LOG "  End md5sum."
	
	LOG "Check finished."

}


#####################################################################
#
#	Main Program
#
#####################################################################

now=`date +"%Y-%m-%d.%H-%M"`

if ! which md5sum > /dev/null 2>&1; then
	LOG "Unable to find md5sum. Aborting."
	EOJ 1
fi

site='NOT_SPECIFIED'
init=0
update=0
check=0
clean=0;
while true ; do
	getopts 's:f:k:iculh' OPT 
	if [ "$OPT" = '?' ] ; then break; fi; 
	case "$OPT" in
		"s") site=$OPTARG;;
		"f") cfg_file=$OPTARG;;
		"k") versions_to_keep=$OPTARG;;
		"i") init=1;;
		"c") check=1;;
		"u") update=1;;
		"l") clean=1;;
		"h") PRINT_USAGE;;
	esac
done

if [ "$site" = 'NOT_SPECIFIED' ] ; then
	LOG "No site specified"
	EOJ 3
fi

cd "$working_dir"
if [ "`pwd`" != "$working_dir" ]; then
	LOG "Unable to cd to $working_dir."
	EOJ 2
fi
if [ -d "$site" ] ; then
	cd "$site"
else
	mkdir "$site"
	cd "$site"	
fi
if [ "`pwd`" != "$working_dir/$site" ]; then
	LOG "Unable to cd to $working_dir/$site."
	EOJ 2
fi

mv $site.$log_file_prefix $site.$log_file_prefix.$now

tmp=$(grep $site $cfg_file)
if [ -n "$tmp" ]; then
	# Ok found $site line in config file
	ftpuser=$( echo $tmp | awk -F":" '{print $2}' )
	ftppassword=$( echo $tmp | awk -F":" '{print $3}' )
	tmp_ver=$( echo $tmp | awk -F":" '{print $4}' )
	if [ -z "$ftpuser" ] || [ -z "$ftppassword" ] ; then
		LOG "Site $site line $tmp not correct (user: $ftpuser / pass: $ftppassword) in config file $cfg_file"
		EOJ 3
	fi
	if [ -n "$tmp_ver" ] && [ "$versions_to_keep" = "0" ] ; then
		versions_to_keep=$tmp_ver
	fi
else
	LOG "Site $site not found in config file $cfg_file"
	EOJ 3
fi

if [ "$clean" = '1' ] ; then
	LOG "Cleaning"
	CLEAN
	EOJ 0
elif [ "$init" = '1' ] ; then
	LOG "Initialising"
	CHECK
	UPDATE
#	CLEAN
	EOJ 0
elif [ "$check" = '1' ] ; then
	LOG "Checking"
	CHECK
#	CLEAN
	EOJ 0
elif [ "$update" = '1' ] ; then
	LOG "Updating"
	UPDATE
	EOJ 0
else
	LOG "No command specified"
	EOJ 3
fi

# Shouldn't reach here
LOG "Unexpected finish."
EOJ 15

