#!/bin/bash

RED='\033[0;31m'
GREEN="\033[1;32m"
BLUE="\033[1;34m"
NOCOLOR="\033[0m"

WORK_DIR=/app/subdomainscan

function my_install(){
	mkdir -p $WORK_DIR

	## Sublist3r Install
	cd $WORK_DIR
	sudo git clone https://github.com/aboul3la/Sublist3r.git
	cd Sublist3r
	sudo pip install -r requirements.txt

	## Knock Install
	cd $WORK_DIR
	sudo git clone https://github.com/guelfoweb/knock.git
	cd knock
	#Set your virustotal API_KEY:
	#$ nano knockpy/config.json
	sudo python setup.py install

	## sslyze
	cd $WORK_DIR
	sudo pip install --upgrade setuptools
	sudo pip install sslyze

	clear
	### package check
	echo -e "\nsublist3 : \n"
	$WORK_DIR/Sublist3r/sublist3r.py -h
	sleep 1
	echo -e "\nknockpy : \c"
	knockpy -v 
	echo -e "\nsslyze : `sslyze --version` \n"
	echo -e $RED"subdomain scan work director : `pwd`' \n"$NOCOLOR
}


function my_run(){
	SUBLIST3R=$WORK_DIR/Sublist3r/sublist3r.py
	KNOCKPY=`which knockpy`
	SSLYZE=`which sslyze`

	## result.txt, subdomain_list.txt
	if [ -f result.txt ]; then
		mv result.txt result.txt_$(date '+%Y%m%d-%H%M')
		mv subdomain_list.txt subdomain_list.txt_$(date '+%Y%m%d-%H%M')
	        echo "File not empty exist"
	else
		echo "File empty exist"
	fi

	## TMP Directory
	if [ -d tmp ]; then
		echo "Directory not empty exist"
	else
		mkdir tmp
	fi

	### SUBLIST3R : word list
	for ORIGIN_DOMAIN in `cat origin_domain.txt`
		do
		$SUBLIST3R --domain $ORIGIN_DOMAIN --threads 10 --output tmp/sublist3r_$ORIGIN_DOMAIN.txt
		cat tmp/sublist3r_$ORIGIN_DOMAIN.txt | cut -d '.' -f 1 | sort | uniq >> tmp/wordlist.tmp
	done

	cat wordlist.txt >> tmp/wordlist.tmp
	cat tmp/wordlist.tmp | sort | uniq > wordlist.txt

	#### KNOCKPY : subdomain
	for ORIGIN_DOMAIN in `cat origin_domain.txt`
        	do
		$KNOCKPY $ORIGIN_DOMAIN -w wordlist.txt --json
		mv *.json tmp/knockpy_$ORIGIN_DOMAIN.json
		cat tmp/knockpy_$ORIGIN_DOMAIN.json | jq -r .subdomain_response[].target >> subdomain_list.txt
	done

	### SSLYZE : Fast and powerful SSL/TLS server scanning library
	for SUBDOMAIN in `cat subdomain_list.txt`
		do
		$SSLYZE --certinfo $SUBDOMAIN --json_out=tmp/sslyze_$SUBDOMAIN.json
		cat tmp/sslyze_$SUBDOMAIN.json | jq -c -r '.accepted_targets[] | [.server_info.hostname, .server_info.ip_address, .commands_results.certinfo.certificate_chain[0].notBefore, .commands_results.certinfo.certificate_chain[0].notAfter, .commands_results.certinfo.certificate_chain[0].issuer]' >> result.txt
	done

	rm -f tmp/wordlist.tmp
	rm -rf tmp/sublist3r_*.txt
	rm -rf tmp/knockpy_*.json
	rm -rf tmp/sslyze_*.json
}

function my_view(){
	echo -e $GREEN"-----"
	cat result.txt | jq -jr ' .[0], ",\t", .[2], ",\t", .[3], "\n"'
        echo -e "-----"$NOCOLOR
}

if [ run == $1 ]; then
	my_run
elif [ install == $1 ]; then
	my_install
elif [ view == $1 ]; then
        my_view
else
	echo "Command : run, view, install"
	echo "Please try again"
fi
