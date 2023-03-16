#!/bin/bash

#read -p 'Введите путь до файла со списком репозиториев на удалённом репозитории: ' argRepoList
#read -p 'Введите директорию, куда сложить локальные репозитории: ' argLocalDir
#read -p 'Введите базовый адрес для выкачивания удалённых репозиториев (например, ssh://git@bitbucket.mycompany.ru:2158/td/): ' argRemoteBase


declare tmpDir

function ERROR {
	if [ -n $tmpDir ]
	then
		rm -rf $tmpDir
	fi
	rm -rf $argLocalDir
	echo "Error: $1"
	exit 1
}
source $(dirname $0)/parameters.ini || ERROR 'Не найден файл с параметрами...'

function fClone {
# Arguments:
# 1.) Имя репозитория

	if [ -d $argLocalDir/$1.git ]
	then
		echo "Репозиторий \"$1\" уже склонирован"
	else
		echo "Клонирую \"$1\""
		git clone --share --bare $argRemoteBase$1.git $argLocalDir/$1.git &> /dev/null || ERROR "Не смог склонировать репозиторий \"$1\""
	fi
}

function isHead {
	local arg="$1"
	#echo "((${arg:0:15}))"
	if [ "${arg:0:15}" == "HEAD -> origin/" ]
	then
		return 0
	fi
	return 1
}

function listBranches {
	local originMark='remotes/origin/'
	local o
	local line
	local initState=true
	while read line
	do
		if [[ "$line" =~ ^${originMark} ]]
		then
			o="${line:${#originMark}}"
			if ! isHead "$o"
			then
				echo "$o"
			fi
		fi
	done < <(git branch --all) || ERROR 'Не удалось получить список веток'
}

function getDefaultBranch {
	local originMark='remotes/origin/'
	local o
	local line
	local initState=true
	while read line
	do
		if [[ "$line" =~ ^${originMark} ]]
		then
			o="${line:${#originMark}}"
			if isHead "$o"
			then
				echo "${o:15}"
			fi
		fi
	done < <(git branch --all) || ERROR 'Не удалось получить дефолтную ветку'
}

if ! [ -d $argLocalDir ]
then
	mkdir -p $argLocalDir
fi
echo '
Клонирую удалённые репозитории
'
for iRepo in $(cat $argRepoList)
do
	fClone $iRepo
done

echo '
Подменяю подмодули на новые
'
tmpDir=$(mktemp -d)
mkdir $tmpDir/tt
for iRepo in $(cat $argRepoList)
do
	echo "-- $iRepo --"
	git clone $argLocalDir/$iRepo.git $tmpDir/tt &> /dev/null || ERROR 230316.20081
	pushd $tmpDir/tt > /dev/null
		for iBranch in $(listBranches)
		do
			echo "	$iBranch"
			# место, откуда можно пушить

			# sed -e 's/https:\/\/bitbucket.locotech-signal.ru\/scm\/td\/cmake.git/http:\/\/qwe.rty/' .gitmodules
		done
		#getDefaultBranch
	popd > /dev/null
	rm -rf $tmpDir/tt || ERROR 230316.20082
done

rm -rf $tmpDir
