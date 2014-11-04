#!/bin/bash

# -----------------------------------------------------------------------------------#
# This script goes into one repository, updates that repository to its current tip,
# then pulls in changes from another repository. It then either runs 'hg update' or
# 'hg merge' to include the new changes, then pushes it out to the remote repository.
#------------------------------------------------------------------------------------#

#TODO ISSUE 3 - Should we just poll treestatus instead of manually flagging closed?
# Default to assuming the tree is not closed
closed="false"
rev=""

# Parse command line flags to get parameters
while getopts :hs:d:cr: option
do
  case "$option" in
  h)
    echo
    echo "MozMerge:"
    echo "usage: ./merge.sh -d [branch name] -s [branch name] -r [revision] -c"
    echo
    echo "Options:"
    echo "  -d     This is the repository you will be pushing incoming changes TO"
    echo "  -s     This is the repository you will be fetching incoming changes FROM"
    echo "  -r     This is the specific revision you want to pull from -s"
    echo "             [optional, will pull tip otherwise]"
    echo "  -c     This flag indicates that -d is closed, so the CLOSED TREE hook is in effect"
    echo "             [optional, assumes tree is open if omitted]"
    echo
    exit
    ;;
  c)
    closed="true"
    ;;
  r)
    rev=$OPTARG
    ;;
  s)
    source=$OPTARG
    ;;
  d)
    destination=$OPTARG
    ;;
  *)
    echo "Unknown option"
    ;;
  esac
done

# We can't do anything if we don't know what we're merging or where it's merging to...
if [[ "$source" = "" && "$destination" = "" ]]
then
  echo "The source and destination parameters are required. Please include them."
  echo "Exiting."
  exit
fi

if [ "$source" = "" ]
then
  echo "The source parameter is required. Please include it."
  echo "Exiting."
  exit
fi

if [ "$destination" = "" ]
then
  echo "The destination parameter is required. Please include it."
  echo "Exiting."
  exit
fi

# Store the user's current directory so we can return there at the end of the merge.
mydir=$(pwd)

# Map repo names to URLs for pulling so we don't make any assumptions.
declare -A repomap
repomap[mozilla-central]="https://hg.mozilla.org/mozilla-central"
repomap[mozilla-inbound]="https://hg.mozilla.org/integration/mozilla-inbound"
repomap[b2g-inbound]="https://hg.mozilla.org/integration/b2g-inbound"
repomap[fx-team]="https://hg.mozilla.org/integration/fx-team"

echo "..."
echo "..."

# Force some shorthand repo names into canonical names.
if [ $source = "central" ]
then
  source="mozilla-central"
elif [ $source = "inbound" ]
then
  source="mozilla-inbound"
elif [ $source = "b2g" ]
then
  source="b2g-inbound"
elif [ $source = "fxteam" ]
then
  source="fx-team"
elif [ $source = "aurora" ]
then
  source="mozilla-aurora"
fi

if [ $destination = "central" ]
then
  destination="mozilla-central"
elif [ $destination = "inbound" ]
then
  destination="mozilla-inbound"
elif [ $destination = "b2g" ]
then
  destination="b2g-inbound"
elif [ $destination = "fxteam" ]
then
  destination="fx-team"
fi

# TODO ISSUE 5 - This assume all local repos are cloned into ~/mozilla/ but I don't know what else to do here.
cd ~/mozilla/$source

# Make sure the local repo mirrors the remote repo before pulling in for the merge.
hg pull -u && hg pull -u

# Pull in from the other repo to do the merge
if [ -z $rev ]
then
  hg pull ${repomap[$destination]}
else
  hg pull ${repomap[$destination]} -r $rev
fi


# TODO ISSUE 6 - $COUNT = 1 if there were no changes, also
# Count the number of heads. If only one head, this is an update not a merge.
COUNT=`hg heads -q | wc -l`
if [ "$COUNT" -eq 1 ]
then
  hg update
  if [[ "$source" = "mozilla-central" || "$closed" = "true" ]]
  then
    echo
    echo
    echo "This is an update, I can't add the 'a=merge' or 'CLOSED TREE' to bypass the commit hook."
    echo "Please open mozilla-central before pressing '1' to proceed."
    select proceed in "Proceed"; do
      case $proceed in
        Proceed )
          hg push ;;
      esac
    done
  fi
else
# TODO ISSUE 1 - This doesn't handle merge conflicts at all
  if [ $closed = "true" ]
  then
    hg merge && hg commit -m "Merge $destination to $source a=merge CLOSED TREE"
  else
    hg merge && hg commit -m "Merge $destination to $source a=merge"
  fi
  hg push
fi

# TODO ISSUE 7 - Remove this when you're confident enough to actually push the merges
#hg strip --no-backup "roots(outgoing())" && hg checkout default


echo "cd $mydir"
cd $mydir





