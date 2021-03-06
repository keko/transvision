#! /usr/bin/env bash

# Syntax:
# - locale code: update only the requested locale
# - 'no-snapshot': avoid creating a data snapshot

function interrupt_code()
# This code runs if user hits control-c
{
  echored "\n*** Operation interrupted ***\n"
  exit $?
}

# Trap keyboard interrupt (control-c)
trap interrupt_code SIGINT

# Pretty printing functions
standard_color=$(tput sgr0)
green=$(tput setaf 2; tput bold)
red=$(tput setaf 1)

function echored() {
    echo -e "$red$*$standard_color"
}

function echogreen() {
    echo -e "$green$*$standard_color"
}

function echo_manual() {
    echo "Run 'glossaire.sh' without parameters to update all locales."
    echo "Run 'glossaire.sh help' to display this manual."
    echo "---"
    echo "To update only one locale, add the locale code as first parameter"
    echo "(e.g. 'glossaire.sh fr' to update only French)."
    echo "---"
    echo "To update all locales, and avoid creating a data snapshot at the end, add 'no-snapshot'"
    echo "(e.g. 'glossaire.sh no-snapshot' to update all locales without creating a data snapshot)."
    echo "---"
    echo "To update only one locale, and avoid creating a data snapshot at the end, add locale code and 'no-snapshot'"
    echo "(e.g. 'glossaire.sh fr no-snapshot' to update only French without creating a data snapshot)."
}

all_locales=true
create_snapshot=true

if [ $# -eq 1 ]
then
    # I have one parameter, it could be 'no-snapshot' or a locale code
    if [ "$1" == "help" ]
    then
        echo_manual
        exit 1
    elif [ "$1" == "no-snapshot" ]
    then
        create_snapshot=false
    else
        all_locales=false
        locale_code=$1
    fi
fi

if [ $# -eq 2 ]
then
    # I have two parameters, I expect the first to be a locale code, the
    # second to be 'no-snapshot'
    all_locales=false
    locale_code=$1
    if [ "$2" != "no-snapshot" ]
    then
        echo "ERROR: incorrect arguments."
        echo_manual
        exit 1
    fi
    create_snapshot=false
fi

if [ $# -gt 2 ]
then
    # Too many parameters, warn and exit
    echo "ERROR: too many arguments."
    echo_manual
    exit 1
fi

# Get configuration variables from config/config.ini
app_folder=$(dirname $PWD)
export PATH=$PATH:$app_folder/app/inc
export PATH=$PATH:$app_folder/

# Store the relative path to the script
script_path=$(dirname "$0")

# Convert .ini file in bash variables
eval $(cat $script_path/../config/config.ini | $script_path/ini_to_bash.py)

# Check if we have sources
echogreen "Checking if Transvision sources are available..."
if ! $(ls $config/sources/*.txt &> /dev/null)
then
    echored "CRITICAL ERROR: no sources available, aborting."
    echored "Check the value for l10nwebservice in your config.ini and run setup.sh"
    exit
fi

# Create all bash variables
source $script_path/bash_variables.sh

# Set if we need to update repositories or force TMX creation
checkrepo=true
forceTMX=false

function updateLocale() {
    # Update this locale's repository
    # $1: Path to l10n repository
    # $2: Locale code
    # $3: Repository name

    # Assign input variables to variables with meaningful names
    l10n_path="$1"
    locale="$2"
    repository_name="$3"

    cd $l10n_path/$locale
    # Check if there are incoming changesets
    hg incoming -r default --bundle incoming.hg 2>&1 >/dev/null
    incoming_changesets=$?
    if [ $incoming_changesets -eq 0 ]
    then
        # Update with incoming changesets and remove the bundle
        echogreen "Updating $repository_name"
        hg pull --update incoming.hg
        rm incoming.hg

        # Return 1: we need to create the cache for this locale
        return 1
    else
        echogreen "There are no changes to pull for $repository_name"

        # Return 0: no need to create the cache
        return 0
    fi
}

function updateStandardRepo() {
    # Update specified repository. Parameters:
    # $1: Channel name used in folders and TMX
    # $2: Channel name used in variable names

    function buildCache() {
        # Build the cache
        # $1: Locale code
        echogreen "Create ${repo_name^^} cache for $repo_name/$1"
        if [ "$1" = "en-US" ]
        then
            nice -20 $install/app/scripts/tmx_products.py ${!repo_source}/COMMUN/ ${!repo_source}/COMMUN/ en-US en-US $repo_name
        else
            nice -20 $install/app/scripts/tmx_products.py ${!repo_l10n}/$1/ ${!repo_source}/COMMUN/ $1 en-US $repo_name
        fi
    }

    local repo_name="$1"                # e.g. release, beta, aurora, central
    local comm_repo="comm-$1"           # e.g. comm-release, etc.
    local mozilla_repo="mozilla-$1"     # e.g. mozilla-release, etc.
    local repo_source="${2}_source"     # e.g. release_source, beta_source, aurora_source, trunk_source
    local repo_l10n="${2}_l10n"         # e.g. release_l10n, etc.
    local locale_list="${2}_locales"    # e.g. release_locales, etc.

    updated_english=false

    # Store md5 of the existing cache before updating the repositories
    cache_file="${root}TMX/en-US/cache_en-US_${repo_name}.php"
    if [ -f $cache_file ]
    then
        existing_md5=($(md5sum $cache_file))
    else
        existing_md5=0
    fi

    if [ "$checkrepo" = true ]
    then
        # Update all source repositories
        # ${!repo_source}: if repo_source contains 'release_source', this will
        # return the value of the variable $release_source.
        cd ${!repo_source}
        echogreen "Update $comm_repo"
        cd $comm_repo
        hg pull -r default --update
        echogreen "Update $mozilla_repo"
        cd ../$mozilla_repo
        hg pull -r default --update
    fi

    # Remove orphaned symbolic links
    find -L ${!repo_source}/COMMUN/ -type l | while read -r file; do echored "$file is orphaned";  unlink $file; done

    # Create TMX for en-US and check the updated md5
    buildCache en-US
    updated_md5=($(md5sum $cache_file))
    if [ $existing_md5 != $updated_md5 ]
    then
        echo "English strings have been updated."
        updated_english=true
    fi

    if [ "$all_locales" = true ]
    then
        for locale in $(cat ${!locale_list})
        do
            if [ -d ${!repo_l10n}/$locale ]
            then
                updated_locale=0
                if [ "$checkrepo" = true ]
                then
                    updateLocale ${!repo_l10n} $locale $repo_name/$locale
                    updated_locale=$?
                fi

                # Check if we have a cache file for this locale. If it's a brand
                # new locale, we'll have the folder and no updates, but we
                # still need to create the cache.
                cache_file="${root}TMX/${locale}/cache_${locale}_${repo_name}.php"
                if [ ! -f $cache_file ]
                then
                    echored "Cache doesn't exist for ${repo_name}/${locale}"
                    updated_locale=1
                fi

                if [ "$forceTMX" = true -o "$updated_english" = true -o "$updated_locale" -eq 1 ]
                then
                    buildCache $locale
                fi
            else
                echored "Folder ${!repo_l10n}/$locale does not exist. Run setup.sh to fix the issue."
            fi
        done
    else
        if [ -d ${!repo_l10n}/$locale_code ]
        then
            updated_locale=0
            if [ "$checkrepo" = true ]
            then
                updateLocale ${!repo_l10n} $locale_code $repo_name/$locale_code
                updated_locale=$?
            fi

            cache_file="${root}TMX/${locale_code}/cache_${locale_code}_${repo_name}.php"
            if [ ! -f $cache_file ]
            then
                echored "Cache doesn't exist for ${repo_name}/${locale_code}"
                updated_locale=1
            fi

            if [ "$forceTMX" = true -o "$updated_english" = true -o "$updated_locale" -eq 1 ]
            then
                buildCache $locale_code
            fi
        else
            echored "Folder ${!repo_l10n}/$locale_code does not exist."
        fi
    fi
}

function updateNoBranchRepo() {
    if $checkrepo
    then
        # These repos exist only on trunk
        cd $trunk_source/$1
        echogreen "Update $1"
        hg pull -r default --update
    fi
}

function updateGaiaRepo() {
    # Update specified Gaia repository
    # $1: Version. It could be "trunk" or a version (e.g. 1_3, 1_4, etc)

    function buildCache() {
        # Build the cache
        # $1: Locale code
        echogreen "Create ${repo_name^^} cache for $repo_name/$1"
        nice -20 $install/app/scripts/tmx_products.py ${!repo_name}/$1/ ${!repo_name}/en-US/ $1 en-US $repo_name
    }

    if [ "$1" == "gaia" ]
    then
        local locale_list="gaia_locales"
        local repo_name="gaia"
    else
        local locale_list="gaia_locales_$1"
        local repo_name="gaia_$1"
    fi

    # Store md5 of the existing cache before updating the repository
    cache_file="${root}TMX/en-US/cache_en-US_${repo_name}.php"
    if [ -f $cache_file ]
    then
        existing_md5=($(md5sum $cache_file))
    else
        existing_md5=0
    fi

    # Update en-US and build its TMX
    if [ "$checkrepo" = true ]
    then
        updateLocale ${!repo_name} en-US $repo_name/en-US
    fi
    updated_md5=($(md5sum $cache_file))
    if [ $existing_md5 != $updated_md5 ]
    then
        echo "English strings have been updated."
        updated_english=true
    fi

    if [ "$all_locales" = true ]
    then
        for locale in $(cat ${!locale_list})
        do
            if [ -d ${!repo_name}/$locale ]
            then
                if [ "$locale" != "en-US" ]
                then
                    updated_locale=0
                    if [ "$checkrepo" = true ]
                    then
                        updateLocale ${!repo_name} $locale $repo_name/$locale
                        updated_locale=$?
                    fi

                    # Check if we have a cache file for this locale. If it's a brand
                    # new locale, we'll have the folder and no updates, but we
                    # still need to create the cache.
                    cache_file="${root}TMX/${locale}/cache_${locale}_${repo_name}.php"
                    if [ ! -f $cache_file ]
                    then
                        echored "Cache doesn't exist for ${repo_name}/${locale}"
                        updated_locale=1
                    fi

                    if [ "$forceTMX" = true -o "$updated_english" = true -o "$updated_locale" -eq 1 ]
                    then
                        buildCache $locale
                    fi
                fi
            else
                echored "Folder ${!repo_name}/$locale does not exist. Run setup.sh to fix the issue."
            fi
        done
    else
        if [ -d ${!repo_name}/$locale_code ]
        then
            updated_locale=0
            if [ "$checkrepo" = true ]
            then
                updateLocale ${!repo_name} $locale_code $repo_name/$locale_code
                updated_locale=$?
            fi

            cache_file="${root}TMX/${locale_code}/cache_${locale_code}_${repo_name}.php"
            if [ ! -f $cache_file ]
            then
                echored "Cache doesn't exist for ${repo_name}/${locale_code}"
                updated_locale=1
            fi

            if [ "$forceTMX" = true -o "$updated_english" = true -o "$updated_locale" -eq 1 ]
            then
                buildCache $locale_code
            fi
        else
            echored "Folder ${!repo_name}/$locale_code does not exist."
        fi
    fi
}

function updateFromGitHub() {
    if [ "$checkrepo" = true ]
    then
        cd $mozilla_org
        echogreen "Update mozilla.org repository"
        git pull origin master
    fi
    echogreen "Extract strings for mozilla.org"
    cd $install
    nice -20 $install/app/scripts/tmx_mozillaorg
}

function updateFirefoxiOS() {
    if [ "$checkrepo" = true ]
    then
        cd $firefox_ios
        echogreen "Update GitHub repository"
        git pull
    fi
    echogreen "Extract strings for Firefox for iOS"
    cd $install
    nice -20 $install/app/scripts/tmx_xliff firefox_ios
}

# Update repos without branches first (their TMX is created in updateStandardRepo)
updateNoBranchRepo "chatzilla"

updateStandardRepo "release" "release"
updateStandardRepo "beta" "beta"
updateStandardRepo "aurora" "aurora"
updateStandardRepo "central" "trunk"

for gaia_version in $(cat ${gaia_versions})
do
    updateGaiaRepo ${gaia_version}
done

updateFromGitHub
updateFirefoxiOS

# Generate productization data
cd $install
echogreen "Extracting p12n data"
nice -20 python $install/app/scripts/p12n_extract.py

# Create a file to get the timestamp of the last string extraction for caching
echogreen "Creating extraction timestamp for cache system"
touch cache/lastdataupdate.txt

echogreen "Deleting all the old cached files"
rm -f cache/*.cache

echogreen "Deleting custom TMX files"
rm -f web/download/*.tmx

# Create a snapshot of all extracted data for download
if [ "$create_snapshot" = true ]
then
    cd $root
    echogreen "Creating a snapshot of extracted strings in web/data.tar.gz"
    tar --exclude="*.tmx" -zcf datatemp.tar.gz TMX

    echogreen "Snapshot created in the web root for download"
    mv datatemp.tar.gz $install/web/data.tar.gz
fi
