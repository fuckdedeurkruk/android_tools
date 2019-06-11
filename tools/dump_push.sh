#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2019 Shivam Kumar Jha <jha.shivam3@gmail.com>
#
# Helper functions

# Store project path
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"

# Common stuff
source $PROJECT_DIR/tools/common_script.sh

# Exit if no arguements
if [ -z "$1" ] ; then
	echo -e "${bold}${red}Supply dir's as arguements!${nocol}"
	exit
fi

# Exit if missing token's
if [ -z "$GIT_TOKEN" ] || [ -z "$TG_API" ]; then
	echo -e "${bold}${cyan}Missing GitHub or telegram token. Exiting.${nocol}"
	exit
fi

# o/p
for var in "$@"; do
	cd "$var"
	# Set variables
	if [ -e system/system/build.prop ]; then
		SYSTEM_PATH="system/system"
	elif [ -e system/build.prop ]; then
		SYSTEM_PATH="system"
	fi
	BRAND_TEMP=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.product.brand=" | sed "s|ro.product.brand=||g" | sort -u | head -n 1 )
	BRAND=${BRAND_TEMP,,}
	if [ "$BRAND" = "vivo" ]; then
		DEVICE=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.vivo.product.release.name=" | sed "s|ro.vivo.product.release.name=||g" | sort -u | head -n 1 )
	else
		DEVICE=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.product.device=" | sed "s|ro.product.device=||g" | sed "s|ASUS_||g" | sort -u | head -n 1 )
	fi
	if [ -z "$DEVICE" ]; then
		DEVICE=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.build.product=" | sed "s|ro.build.product=||g" | sed "s|ASUS_||g" | sort -u | head -n 1 )
	fi
	if [ -z "$DEVICE" ]; then
		DEVICE=target
	fi
	DESCRIPTION=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.build.description=" | sed "s|ro.build.description=||g" | sort -u | head -n 1 )
	FINGERPRINT=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.build.fingerprint=" | sed "s|ro.build.fingerprint=||g" | sort -u | head -n 1 )
	if [ -z "$FINGERPRINT" ]; then
		FINGERPRINT=$DESCRIPTION
	fi
	if [ "$BRAND" = "oppo" ] || [ "$BRAND" = "realme" ]; then
		MODEL=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.oppo.market.name=" | sed "s|ro.oppo.market.name=||g" | sort -u | head -n 1 )
	else
		MODEL=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.product.model=" | sed "s|ro.product.model=||g" | sort -u | head -n 1 )
	fi
	VERSION=$( cat "$SYSTEM_PATH"/build*.prop | grep "ro.build.version.release=" | sed "s|ro.build.version.release=||g" | head -c 1 | sort -u | head -n 1 )
	COMMIT_MSG=$(echo "$DEVICE: $FINGERPRINT" | sort -u | head -n 1 )
	REPO=$(echo dump_$BRAND\_$DEVICE | sort -u | head -n 1 )
	if [ -z "$MODEL" ]; then
		REPO_DESC=$(echo "$DEVICE-dump" | sort -u | head -n 1 )
	else
		REPO_DESC=$(echo "$MODEL-dump" | tr ' ' '-' | sort -u | head -n 1 )
	fi
	BRANCH=$(echo $DESCRIPTION | tr ' ' '-' | sort -u | head -n 1 )
	# Create repository in GitHub
	echo -e "${bold}${cyan}Creating https://github.com/ShivamKumarJha/$REPO${nocol}"
	curl https://api.github.com/user/repos\?access_token=$GIT_TOKEN -d '{"name":"'${REPO}'","description":"'${REPO_DESC}'","private": true,"has_issues": false,"has_projects": false,"has_wiki": false}' > /dev/null 2>&1
	# Add files & push
	if [ ! -d .git ]; then
		echo -e "${bold}${cyan}Initializing git.${nocol}"
		git init . > /dev/null 2>&1
	fi
	if [[ ! -z $(git status -s) ]]; then
		echo -e "${bold}${cyan}Creating branch $BRANCH${nocol}"
		git checkout -b $BRANCH > /dev/null 2>&1
		find -size +97M -printf '%P\n' > .gitignore
		echo -e "${bold}${cyan}Ignoring following files:\n${nocol}$(cat .gitignore)"
		echo -e "${bold}${cyan}Adding files ...${nocol}"
		git add --all > /dev/null 2>&1
		echo -e "${bold}${cyan}Commiting $COMMIT_MSG${nocol}"
		git -c "user.name=ShivamKumarJha" -c "user.email=jha.shivam3@gmail.com" commit -sm "$COMMIT_MSG" > /dev/null 2>&1
		git remote add origin https://github.com/ShivamKumarJha/"$REPO".git > /dev/null 2>&1
		git push https://"$GIT_TOKEN"@github.com/ShivamKumarJha/"$REPO".git $BRANCH
		COMMIT_HEAD=$(git log --format=format:%H | head -n 1)
		COMMIT_LINK=$(echo "https://github.com/ShivamKumarJha/$REPO/commit/$COMMIT_HEAD")

		# Telegram
		echo -e "${bold}${cyan}Sending telegram notification${nocol}"
		printf "<b>Brand: $BRAND</b>" > $PROJECT_DIR/working/tg.html
		printf "\n<b>Device: $DEVICE</b>" >> $PROJECT_DIR/working/tg.html
		printf "\n<b>Version:</b> $VERSION" >> $PROJECT_DIR/working/tg.html
		printf "\n<b>Fingerprint:</b> $FINGERPRINT" >> $PROJECT_DIR/working/tg.html
		printf "\n<b>GitHub:</b>" >> $PROJECT_DIR/working/tg.html
		printf "\n<a href=\"$COMMIT_LINK\">Commit</a>" >> $PROJECT_DIR/working/tg.html
		printf "\n<a href=\"https://github.com/ShivamKumarJha/$REPO/tree/$BRANCH/\">$DEVICE</a>" >> $PROJECT_DIR/working/tg.html
		. $PROJECT_DIR/tools/telegram.sh "$TG_API" "@android_dumps" "$PROJECT_DIR/working/tg.html" "HTML" "$PROJECT_DIR/working/telegram.php" > /dev/null 2>&1
		rm -rf $PROJECT_DIR/working/*
		cd $PROJECT_DIR
	fi
done