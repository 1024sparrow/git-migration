#!/bin/bash

#read -p 'Введите путь до файла со списком репозиториев на удалённом репозитории: ' argRepoList
#read -p 'Введите директорию, куда сложить локальные репозитории: ' argLocalDir
#read -p 'Введите базовый адрес для выкачивания удалённых репозиториев (например, ssh://git@bitbucket.mycompany.ru:2158/td/): ' argRemoteBase

for iArg in $@
do
	if [ "$iArg" == --help ]
	then
		echo '
qwe rty
'
		exit 0
	fi
done


declare tmpDir
declare -a repos
declare newReposBase

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
newReposBase="ssh://$argLocalUsername@$argLocalOuterIp:$(readlink -f $argLocalDir)/"
echo "newReposBase: \"$newReposBase\""
echo '
Клонирую удалённые репозитории
'
for iRepo in $(cat $argRepoList)
do
	fClone $iRepo
	repos=(${repos[@]} $iRepo)
done

echo '
Подменяю подмодули на новые
'
tmpDir=$(mktemp -d)
mkdir $tmpDir/tt
for iRepo in ${repos[@]}
do
	echo "-- $iRepo --"
	git clone $argLocalDir/$iRepo.git $tmpDir/tt &> /dev/null || ERROR 230316.20081
	pushd $tmpDir/tt > /dev/null
		for iBranch in $(listBranches)
		do
			echo "	$iBranch"
			# место, откуда можно пушить

			git checkout $iBranch &> /dev/null #|| ERROR "Не удалось переключиться на ветку \"$iBranch\""
			if [ -f .gitmodules ]
			then
				tmp=$(mktemp)
				for iRepo2 in ${repos[@]}
				do
					for iRemoteBase in $argRemoteBase $argRemoteBaseAlias
					do
						oldBase="${iRemoteBase//\//\\\/}"
						newBase="${newReposBase//\//\\\/}"
						sed -e "s/$oldBase$iRepo2.git/$newBase$iRepo2.git/g" .gitmodules > $tmp
						cat $tmp > .gitmodules
					done
				done
				rm $tmp
				if [ -n "$(git diff .gitmodules)" ]
				then
					git add .gitmodules &&
					git commit -m "$iBranch: submodules remote replaced for $newReposBase" &&
					git push ||
					ERROR "Не удалось закоммитить изменённый .gitmodules для репозитория \"$iRepo\" (ветка \"$iBranch\")"
				fi
			fi
		done
		echo
		#getDefaultBranch
	popd > /dev/null
	rm -rf $tmpDir/tt || ERROR 230316.20082
done

rm -rf $tmpDir
