#! /usr/bin/env bash

# Syntax:
# - without parameters: update all locales
# - one parameter (locale code): update only the requested locale

function interrupt_code()
# This code runs if user hits control-c
{
  echored "\n*** Operation interrupted ***\n"
  exit $?
}

# Trap keyboard interrupt (control-c)
trap interrupt_code SIGINT

# Pretty printing functions
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2; tput bold)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4; tput bold)

function echored() {
    echo -e "$RED$*$NORMAL"
}

function echogreen() {
    echo -e "$GREEN$*$NORMAL"
}

function echoblue() {
    echo -e "$BLUE$*$NORMAL"
}

all_locales=true

if [ $# -eq 1 ]
then
    # I have exactly one parameter, it should be the locale code
    all_locales=false
    locale_code=$1
fi

if [ $# -gt 1 ]
then
    # Too many parameters, warn and exit
    echo "ERROR: too many arguments. Run 'glossaire.sh' without parameters to"
    echo "update all locales, or add the locale code as the only parameter "
    echo "(e.g. 'glossaire.sh fr' to update only French)."
    exit 1
fi

# Get server configuration variables
export PATH=$PATH:$PWD/web/inc
export PATH=$PATH:$PWD/

# We need to store the current directory value for the CRON job
DIR=$(dirname "$0")
source $DIR/iniparser.sh

# Decide if must update hg repositories and create TMX
checkrepo=true
createTMX=true

function updateStandardRepo() {
    # Update specified repository. Parameters:
    # $1 = channel name used in folders and TMX
    # $2 = channel name used in variable names

    local repo_name="$1"                # e.g. release, beta, aurora, central
    local comm_repo="comm-$1"           # e.g. comm-release, etc.
    local mozilla_repo="mozilla-$1"     # e.g. mozilla-release, etc.
    local repo_source="${2}_source"     # e.g. release_source, beta_source, aurora_source, trunk_source
    local repo_l10n="${2}_l10n"         # e.g. release_l10n, etc.
    local locale_list="${2}_locales"    # e.g. release_locales, etc.
    local locale_list_omt="${2}_locales_omegat"    # e.g. release_locales_omegat, beta_locales_omegat

    if $checkrepo
    then
        cd ${!repo_source}              # value of variable called repo, e.g. value of $release_source
        echogreen "Update $comm_repo"
        cd $comm_repo
        hg pull -r default
        hg update -C
        echogreen "Update $mozilla_repo"
        cd ../$mozilla_repo
        hg pull -r default
        hg update -C

        if $all_locales
        then
            cd ${!repo_l10n}            # value of variable called repo_l10n, e.g. value of $release_l10n
            for locale in $(cat ${!locale_list})
            do
                echogreen "Update $repo_name/$locale"
                cd $locale
                hg pull -r default
                hg update -C
                cd ..
            done
        else
            if [ -d ${!repo_l10n}/$locale_code ]
            then
                echogreen "Update $repo_name/$locale_code"
                cd ${!repo_l10n}/$locale_code
                hg pull -r default
                hg update -C
                cd ..
            else
                echored "Folder ${!repo_l10n}/$locale_code does not exist."
            fi
        fi
    fi

    cd $install
    if $createTMX
    then
        find -L ${!repo_source}/COMMUN/ -type l | while read -r file; do echored "$file is orphaned";  unlink $file; done
        if $all_locales
        then
            for locale in $(cat ${!locale_list})
            do
                omt=0
                echogreen "Create ${repo_name^^} TMX for $locale"
                grep -q ^$locale$ ${!locale_list_omt}
                rc=$?
                if [ $rc -eq 0 ]
                then
                    echoblue "Create customized ${repo_name^^} TMX for $locale to use in OmegaT"
                    omt=1
                fi
                nice -20 python tmxmaker.py -o $omt ${!repo_l10n}/$locale/ ${!repo_source}/COMMUN/ $locale en-US $repo_name
            done
        else
            if [ -d ${!repo_l10n}/$locale_code ]
            then
                echogreen "Create ${repo_name^^} TMX for $locale_code"
                nice -20 python tmxmaker.py ${!repo_l10n}/$locale_code/ ${!repo_source}/COMMUN/ $locale_code en-US $repo_name
            else
                echored "Folder ${!repo_l10n}/$locale_code does not exist."
            fi
        fi

        echogreen "Create ${repo_name^^} TMX for en-US"
        nice -20 python tmxmaker.py ${!repo_source}/COMMUN/ ${!repo_source}/COMMUN/ en-US en-US $repo_name
    fi
}


function updateNoBranchRepo() {
    if $checkrepo
    then
        # These repos exist only on trunk
        cd $trunk_source/$1
        echogreen "Update $1"
        hg pull -r default
        hg update -C
    fi
}


function updateGaiaRepo() {
    # Update specified Gaia repository. Parameters:
    # $1 = version, could be "trunk" or a version (e.g. 1_1, 1_2, etc)

    if [ "$1" == "gaia" ]
    then
        local locale_list="gaia_locales"
        local repo_name="gaia"
    else
        local locale_list="gaia_locales_$1"
        local repo_name="gaia_$1"
    fi

    if $checkrepo
    then
        if $all_locales
        then
            cd ${!repo_name}
            for locale in $(cat ${!locale_list})
            do
                echogreen "Update $repo_name/$locale"
                cd $locale
                hg pull -r default
                hg update -C
                cd ..
            done
        else
            if [ -d ${!repo_name}/$locale_code ]
            then
                echogreen "Update $repo_name/$locale_code"
                cd ${!repo_name}/$locale_code
                hg pull -r default
                hg update -C
                cd ..
            else
                echored "Folder ${!repo_name}/$locale_code does not exist."
            fi
        fi
    fi

    cd $install
    if $createTMX
    then
        if $all_locales
        then
            for locale in $(cat ${!locale_list})
            do
                echogreen "Create ${repo_name^^} TMX for $locale"
                nice -20 python tmxmaker.py ${!repo_name}/$locale/ ${!repo_name}/en-US/ $locale en-US $repo_name
            done
        else
            if [ -d ${!repo_name}/$locale_code ]
            then
                echogreen "Create ${repo_name^^} TMX for $locale_code"
                nice -20 python tmxmaker.py ${!repo_name}/$locale_code/ ${!repo_name}/en-US/ $locale_code en-US $repo_name
            else
                echored "Folder ${!repo_name}/$locale_code does not exist."
            fi
        fi

        echogreen "Create ${repo_name^^} TMX for en-US"
        nice -20 python tmxmaker.py ${!repo_name}/en-US/ ${!repo_name}/en-US/ en-US en-US $repo_name
    fi
}

# Update repos without branches first (their TMX is created in updateStandardRepo)
updateNoBranchRepo "chatzilla"
updateNoBranchRepo "venkman"

updateStandardRepo "release" "release"
updateStandardRepo "beta" "beta"
updateStandardRepo "aurora" "aurora"
updateStandardRepo "central" "trunk"

updateGaiaRepo "gaia"
updateGaiaRepo "1_1"
updateGaiaRepo "1_2"
updateGaiaRepo "1_3"

# Generate cache of bugzilla components if it doesn't exist or it's older than 7 days
cd $install
if [ -f web/cache/bugzilla_components.json ]
then
    # File exist, check the date
    if [ $(find web/cache/bugzilla_components.json -mtime +6) ]
    then
        echored "Generating web/cache/bugzilla_components.json (file older than a week)"
        nice -20 python bugzilla_query.py
    else
        echogreen "No need to generate Bugzilla components cache"
    fi
else
    # File does not exist
    echored "Generating web/cache/bugzilla_components.json (file missing)"
    nice -20 python bugzilla_query.py
fi

# Generate productization data
cd $install
echogreen "Extracting p12n data"
nice -20 python p12n_extract.py

# Update L20N test repo
if $checkrepo
then
    cd $l20n_test/l20ntestdata
    git pull origin master
fi

cd $install
if $createTMX
then
    if $all_locales
    then
        for locale in $(cat $l20n_test_locales)
        do
            echogreen "Create L20N test repo TMX for $locale"
            nice -20 python tmxmaker.py $l20n_test/l20ntestdata/$locale/ $l20n_test/l20ntestdata/en-US/ $locale en-US l20n_test
        done
    else
        if [ -d $l20n_test/l20ntestdata/$locale_code ]
        then
            echogreen "Create L20N test repo TMX for $locale_code"
            nice -20 python tmxmaker.py $l20n_test/l20ntestdata/$locale_code/ $l20n_test/l20ntestdata/en-US/ $locale_code en-US l20n_test
        else
            echored "Folder $l20n_test/$locale_code does not exist."
        fi
    fi

    echogreen "Create L20N test repo TMX for en-US"
    nice -20 python tmxmaker.py $l20n_test/l20ntestdata/en-US/ $l20n_test/l20ntestdata/en-US/ en-US en-US l20n_test
fi
