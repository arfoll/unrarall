#!/usr/bin/env bash

#unrarall
# Copyright (C) 2011, 2012, 2013 Brendan Le Foll <brendan@fridu.net>
# Copyright (C) 2011, 2012, 2013 Dan Liew <dan@su-root.co.uk>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
##########################################################################

# Set some defaults
declare -x FIND="find" #set to gfind to use homebrew's GNU findutils on OSX Yosemite
declare -x DIR=""
declare -x RM="rm"
declare -rx UNRARALL_VERSION="0.4.3"
declare -ix FORCE=0
declare -ix VERBOSE=0
declare -ix QUIET=0
declare -ix CKSFV=1
declare -x UNRAR_METHOD="e"
declare -x CKSFV_FLAGS="-q -g"
declare -x UNRARALL_BIN="" #Leave empty to let unrarall to loop through UNRAR_BINARIES, setting this will disable searching through UNRAR_BINARIES
declare -x UNRAR_BINARIES=(unrar rar 7z) #Array of binaries to try and use, the order here is the order of precedence
declare -x UNRARALL_PID="$$"
declare -x UNRARALL_EXECUTABLE_NAME=$(basename $0;)
declare -x UNRARALL_PASSWORD_FILE="${HOME}/.unrar_passwords" #If this exists and unrar asks for a password
declare -ax UNRARALL_DETECTED_CLEAN_UP_HOOKS
declare -ax UNRARALL_CLEAN_UP_HOOKS_TO_RUN=(none)
declare -x UNRARALL_OUTPUT_DIR=""

function usage()
{
  echo "Usage: ${UNRARALL_EXECUTABLE_NAME} [ --clean=<hook>[,<hook>] ] [ --force ] [ --full-path ]
                [ --verbose | --quiet ] [--7zip] [--dry] [--disable-cksfv]
                [ --output DIRECTORY ] <DIRECTORY>
       ${UNRARALL_EXECUTABLE_NAME} --help
       ${UNRARALL_EXECUTABLE_NAME} --version

Usage (short options):
     ${UNRARALL_EXECUTABLE_NAME}  [-f] [ -v | -q ] [-7] [-d] [-o DIRECTORY ] [-s] <DIRECTORY>
     ${UNRARALL_EXECUTABLE_NAME} -h

DESCRIPTON
${UNRARALL_EXECUTABLE_NAME} is a utility to unrar and clean up various files
(.e.g. rar files). Sub-directories are automatically recursed and if a rar file
exists in a sub-directory then the rar file is extracted into that subdirectory.

Use --clean= if you want to cleanup (delete files/folders). Otherwise no
cleaning is done. It can also be used to delete rar files that have already been
used for extraction with \"--clean=rar --force\". Use with caution!

OPTIONS

-7, --7zip           Force using 7zip instead of trying to automatically find a
                     program to extract the rar files.
-d, --dry            Dry run of unrar and cleaning. No action will actually be
                     performed.
-s, --disable-cksfv  Use cksfv (if present) to check the CRC of the downloaded
                     files (if present) before extracting
--clean=             Clean if unrar extraction succeeds (use --force to override).
                     The clean up hooks specified determine what files/folders
                     are removed. By default this is 'none'. Hooks are separated
                     by a comma and are executed in order specified.
-f, --force          Force unrar even if sfv check failed and if --clean will
                     clean even if unrar fails.
--full-path          Extract full path inside rar files instead of just
                     extracting the files in the rar file which is the default
                     behaviour.
-h, --help           Displays this help message and exits.
-v, --verbose        Show extraction progress as ${UNRARALL_EXECUTABLE_NAME}
                     executes. This is not done by default
-q, --quiet          Be completely quiet. No output will be written to the
                     screen
-o, --output         Specify a directory to extract rar files. By default files
                     will be extracted in the directory containing the rar file.
--version            Give version information version.
"

#List the detected clean up hooks with their help information
detect-clean-up-hooks
echo "CLEAN UP HOOKS"
for hook in ${UNRARALL_DETECTED_CLEAN_UP_HOOKS[*]} ; do
  echo "$hook : $( unrarall-clean-${hook} help)"
done

echo "all : Execute all the above hooks. They are executed in the order they are listed above."
echo "none : Do not execute any clean up hooks (default)."


echo "
VERSION: $UNRARALL_VERSION
"
}

function clean-up
{
  #perform any necessary clean up
  message error "${UNRARALL_EXECUTABLE_NAME} is exiting"
  exit 1;
}

#Catch exit signals
trap clean-up SIGQUIT SIGINT SIGTERM

#function to display pretty messages
function message()
{
  #Assume $1 is message type & $2 is message
  #See http://www.frexx.de/xterm-256-notes/ for information on xterm colour codes

  if [ "$QUIET" -ne 1 ]; then
    case "$1" in
      error)
        #use escape sequence to show red text
        echo -e "\033[31m${2}\033[0m" 1>&2
      ;;
      ok)
        #use escape sequence to show green text
        echo -e "\033[32m${2}\033[0m"
      ;;
      nnl)
        #use echo -n to avoid new line
        echo -n "$2"
      ;;
      info)
        echo "$2"
      ;;
      *)
        echo "$2"
    esac
  fi
}

#function to get flags for unrar binary
function getUnrarFlags()
{
  #$1 is assumed to be unrar binary name
  case "$1" in
    unrar)
      echo -o+ -y
    ;;
    rar)
      echo -o+ -y
    ;;    
    7z)
      echo -y
    ;;
    echo)
      echo
    ;;
    *)
      #This code should only be reached if the programmer has made an error
      message error "Failed to determine flags for unsupported program \"$1\""
      #We will probably be called in a sub shell but we need to kill the parent shell
      kill -TERM ${UNRARALL_PID}
      exit 1;
    ;;
  esac
}

#function to check if file is password protected
function isRarEncrypted()
{
  case "$1" in
    unrar)
      rar_listing=$(unrar l -p- "$2")
      echo "${rar_listing}" | grep -q -E "^\*"
      if [ "$?" -eq 0 ] ; then
        # RAR file contains encrypted files
        echo 1
      else
        echo "${rar_listing}" | grep -q -E "^Details: .+ encrypted headers"
        if [ "$?" -eq 0 ] ; then
          # RAR file is encrypted (even the file listing)
          echo 1
        else
          # RAR file is not encrypted
          echo 0
        fi
      fi
    ;;
    rar)
      rar_listing=$(rar l -p- "$2" 2>&1)
      echo "${rar_listing}" | grep -q -E "^\*"
      if [ "$?" -eq 0 ] ; then
        # RAR file contains encrypted files
        echo 1
      else
        echo "${rar_listing}" | grep -q -E "encrypted file .* wrong password"
        if [ "$?" -eq 0 ] ; then
          # RAR file is encrypted (even the file listing)
          echo 1
        else
          # RAR file is not encrypted
          echo 0
        fi
      fi
    ;;    
    7z)
      rar_listing=$(7z l -slt -p- "$2")
      echo "${rar_listing}" | grep -q -E "^Encrypted = \+$"
      if [ "$?" -eq 0 ] ; then
        # RAR file contains encrypted files
        echo 1
      else
        echo "${rar_listing}" | grep -q -E "^Error: .+: Can not open encrypted archive\. Wrong password\?$"
        if [ "$?" -eq 0 ] ; then
          # RAR file is encrypted (even the file listing)
          echo 1
        else
          # RAR file is not encrypted
          echo 0
        fi
      fi
    ;;
    echo)
        echo 0
    ;;
    *)
      #This code should only be reached if the programmer has made an error
      message error "Failed to check encryption using unsupported program \"$1\""
      #We will probably be called in a sub shell but we need to kill the parent shell
      kill -TERM ${UNRARALL_PID}
      exit 1;
    ;;
  esac
}

function detect-clean-up-hooks()
{
  [ $VERBOSE -eq 1 ] && message info "Detecting clean up hooks..."
  HOOKS=$(declare -F | grep -Eo ' unrarall-clean-[_a-z-]+')
  index=0
  EMPTY_FOLDER=0
  for hook in $HOOKS ;do
    [ $VERBOSE -eq 1 ] && message info "Found $hook";

    if [ "$hook" == "unrarall-clean-empty_folders" ]; then
        # it is executed last for --clean=all
        EMPTY_FOLDER=1
        continue
    fi

    UNRARALL_DETECTED_CLEAN_UP_HOOKS[$index]=$( echo "$hook" | sed 's/unrarall-clean-//')
    ((index++))
  done

  if [ ${EMPTY_FOLDER} -eq 1 ]; then
    UNRARALL_DETECTED_CLEAN_UP_HOOKS[$index]="empty_folders"
  fi
}

#Prints out an escaped version of 1st argument for use in find's regex
#This is emacs style regex
function find-regex-escape()
{
  echo "$1" | sed 's#\\#\\\\#g ;s/\?/\\?/g ; s/\./\\./g ; s/\+/\\+/g ; s/\*/\\*/g; s/\^/\\^/g ; s/\$/\\$/g; s/\[/\\[/g; s/\]/\\]/g;'
}

#Helper function for hooks to remove a single file/folder
# unrarall-remove-file <FILE> <HOOKNAME>
function unrarall-remove-file-or-folder()
{
      if [ -f "./${1}" -o -d "./${1}" ]; then
        [ "$VERBOSE" -eq 1 ] && message nnl "Hook ${2}: Found ${1} . Attempting to remove..."
        ${RM} -rf $( [ "$VERBOSE" -eq 1 ] && echo '--verbose') "./${1}"
        [ $? -ne 0 ] && message error "Could not remove ${1}" || message ok "Success"
      else
        [ "$VERBOSE" -eq 1 ] && message info "Hook ${2}: No ${1} file/folder found."
      fi
}

#Start of clean-up hooks
# unrarall-clean-* <MODE> <SFILENAME> <RARFILE_DIR>
# <MODE> is either help or clean
# <SFILENAME> is the name of the rar file but with rar suffix removed
# <RARFILE_DIR> is the directory containing the rar files
# Hooks should use ${RM} instead of the 'rm' command
# Hooks cannot be named "all" or "none" as these are reserved.
# Hooks can assume that the current working directory is the directory where files
# extracted. This is not necessarily the same as <RARFILE_DIR> is --output was specified

function unrarall-clean-nfo()
{
  case "$1" in
    help)
      echo "Removes .nfo files with the same name as the .rar file"
    ;;
    clean)
      [ $VERBOSE -eq 1 ] && message info "Deleting ${2}.nfo"
      ${RM} -f "${2}.nfo"
    ;;
    *)
      message error "Could not execute clean-nfo hook"
    ;;
  esac
}

function unrarall-clean-rar()
{
  case "$1" in
    help)
      echo "Removes rar files and sfv files"
    ;;
    clean)
      # Strip out trailing slash if there is one. If we leave it there it'll break the regex passed to find
      _RARFILE_DIR="${3%/}"
      [ $VERBOSE -eq 1 ] && message info "Deleting ${2} rar files (in \"${_RARFILE_DIR}\")..."
      if [ ! -d "${_RARFILE_DIR}" ]; then
        message error "RARFILE_DIR (${_RARFILE_DIR}) is not a directory"
        return
      fi

      #-maxdepth 1 is very important, we only want to delete rar files in the current directory!
      ${FIND} "${_RARFILE_DIR}" -maxdepth 1 -type f -iregex "${_RARFILE_DIR}/$(find-regex-escape "$2")"'\.\(sfv\|[0-9]+\|[r-z][0-9]+\|rar\|part[0-9]+\.rar\)$' -exec ${RM} -f $( [ $VERBOSE -eq 1 ] && echo '-v') '{}' \;
    ;;
    *)
      message error "Could not execute clean-rar hook"
    ;;
  esac
}

function unrarall-clean-osx_junk()
{
  case "$1" in
    help)
      echo "Removes junk OSX files"
    ;;
    clean)
      unrarall-remove-file-or-folder ".DS_Store" "osx_junk"
    ;;
    *)
      message error "Could not execute osx_junk hook"
    ;;
  esac
}

function unrarall-clean-windows_junk()
{
  case "$1" in
    help)
      echo "Removes junk Windows files"
    ;;
    clean)
      unrarall-remove-file-or-folder "Thumbs.db" "windows_junk"
    ;;
    *)
      message error "Could not execute windows_junk hook"
    ;;
  esac
}

function unrarall-clean-covers_folders()
{
  case "$1" in
    help)
      echo "Removes junk Covers folders"
    ;;
    clean)
      [ "$VERBOSE" -eq 1 ] && message info "Removing all Covers/ folders"
      ${FIND} . -depth -type d -iname 'covers' -exec ${RM} -rf $( [ $VERBOSE -eq 1 ] && echo '-v') '{}' \;
    ;;
    *)
      message error "Could not execute covers_folders hook"
    ;;
  esac
}

function unrarall-clean-proof_folders()
{
  case "$1" in
    help)
      echo "Removes junk Proof folders"
    ;;
    clean)
      [ "$VERBOSE" -eq 1 ] && message info "Removing all Proof/ folders"
      ${FIND} . -depth -type d -iname 'proof' -exec ${RM} -rf $( [ $VERBOSE -eq 1 ] && echo '-v') '{}' \;
    ;;
    *)
      message error "Could not execute proof_folders hook"
    ;;
  esac
}

function unrarall-clean-sample_folders()
{
  case "$1" in
    help)
      echo "Removes Sample folders"
    ;;
    clean)
      [ "$VERBOSE" -eq 1 ] && message info "Removing all Sample/ folders"
      ${FIND} . -type d -iname 'sample' -exec ${RM} -rf $( [ $VERBOSE -eq 1 ] && echo '-v') '{}' \;
    ;;
    *)
      message error "Could not execute sample_folders hook"
    ;;
  esac
}

function unrarall-clean-sample_videos()
{
  case "$1" in
    help)
      echo "Removes video files with \"sample\" as a prefix and a similar name to the rar file (without extension)"
    ;;
    clean)
      [ "$VERBOSE" -eq 1 ] && message info "Removing video files with \"sample\" prefix"
      ${FIND} . -type f -iregex '^\./sample.*'"$(find-regex-escape "$2")"'\.\(asf\|avi\|mkv\|mp4\|m4v\|mov\|mpg\|mpeg\|ogg\|webm\|wmv\)$' -exec ${RM} -f $( [ $VERBOSE -eq 1 ] && echo '-v') '{}' \;
    ;;
    *)
      message error "Could not execute sample_videos hook"
    ;;
  esac
}

function unrarall-clean-empty_folders()
{
  case "$1" in
    help)
      echo "Removes empty folders in the folder containing the found rar file(s)"
    ;;
    clean)
      [ "$VERBOSE" -eq 1 ] && message info "Removing empty folders"
      if [ ! -d "${3}" ]; then
        message error "RARFILE_DIR (${3}) is not a directory"
        return
      fi
      ${FIND} "${3}" -depth -mindepth 1 -type d -empty -exec rmdir $( [ $VERBOSE -eq 1 ] && echo '-v') '{}' \;
    ;;
    *)
      message error "Could not execute empty_folders hook"
    ;;
  esac
}

#end of clean-up hooks


# Parse command line arguments
if [ "$#" -lt 1 ]; then
  message error "Insufficient number of arguments. See ${UNRARALL_EXECUTABLE_NAME} --help"
  exit 1;
fi

while [ -n "$1" ]; do
  if [ $# -gt 1 ] || [ $( echo "$1" | grep -Ec '^(-h|--help|--version)$' ) -eq 1 ] ; then
    #Handle optional arguments
    case "$1" in
      -h | --help )
        usage
        exit 0
      ;;
      --version )
        echo "$UNRARALL_VERSION"
        exit 0
      ;;
      -d | --dry )
        UNRARALL_BIN=echo
        RM="echo"
      ;;
      -s | --disable-cksfv )
        CKSFV=0
      ;;
      --clean=*)
        index=0;
        for hook in $( echo "$1" | sed 's/--clean=//' | tr , " ") ; do
          UNRARALL_CLEAN_UP_HOOKS_TO_RUN[$index]="$hook"
          ((index++))
        done
        [ $index -eq 0 ] && { message error "Clean up hooks must be specified when using --clean="; exit 1; }
      ;;
      -f | --force )
        FORCE=1
      ;;
      -v | --verbose )
        VERBOSE=1
        CKSFV_FLAGS="-g"
      ;;
      -q | --quiet )
        VERBOSE=0
        QUIET=1
      ;;
      --full-path )
        UNRAR_METHOD="x"
      ;;
      -7 | --7zip)
        # to ensure that if --dry and then --7zip are used then we still do a dry run
        if [ "$UNRARALL_BIN" != 'echo' ]; then
          UNRARALL_BIN=7z
        fi
      ;;
      -o | --output)
        shift
        UNRARALL_OUTPUT_DIR="$1"
        if [ ! -d "${UNRARALL_OUTPUT_DIR}" ]; then
          message error "\"${UNRARALL_OUTPUT_DIR}\" is not a directory"
          exit 1
        else
          message info "Using \"${UNRARALL_OUTPUT_DIR}\" as output directory"
        fi

        # Make the directory absolute. This is necessary
        # because we may be changing directory multiple times
        UNRARALL_OUTPUT_DIR="$(cd "${UNRARALL_OUTPUT_DIR}" ; pwd)"
      ;;
      *)
        # user issued unrecognised option
        message error "Unrecognised option: $1"
        usage
        exit 1
      ;;
    esac
  else
    #Handle mandatory argument
    DIR="$1"

  fi
    shift
done

if [[ $OSTYPE == darwin* ]]; then 
    type -P gfind &>/dev/null && FIND=gfind || { message error "Please install findutils using HomeBrew. (http://brew.sh/)"; exit 1; }
fi

detect-clean-up-hooks

#Verify selected clean-up hooks are ok
if [ ${#UNRARALL_CLEAN_UP_HOOKS_TO_RUN[*]} -eq 1 ] && [ $( echo "${UNRARALL_CLEAN_UP_HOOKS_TO_RUN[0]}" | grep -Ec '^(all|none)$' ) -eq 1 ] ; then
  #Don't need to do anything
  [ $VERBOSE -eq 1 ] && message info "Using virtual clean-up hook ${UNRARALL_CLEAN_UP_HOOKS_TO_RUN[0]}"
else
  #Loop through clean up hooks and check it's allowed
  for hook_to_use in ${UNRARALL_CLEAN_UP_HOOKS_TO_RUN[*]} ; do
    HOOK_FOUND=0
    for hook in ${UNRARALL_DETECTED_CLEAN_UP_HOOKS[*]}; do
      if [ "$hook_to_use" = "$hook" ]; then
        HOOK_FOUND=1
        break;
      fi
    done

    if [ $HOOK_FOUND -eq 0 ]; then
      message error "Hook $hook_to_use is not a valid clean up hook. See --help"
      exit 1;
    fi

  done
fi

# Current Dir check
if [ "${DIR}" == "." ]; then
  DIR="`pwd`"
fi

#If No user specified binary, cycle through array and try and find a binary that can be used
if [ -z "${UNRARALL_BIN}" ]; then
  for (( index=0; index < ${#UNRAR_BINARIES[@]}; index++)); do
    #Check for binary
    [ $VERBOSE -eq 1 ] && message nnl "Looking for ${UNRAR_BINARIES[$index]}..."
    if type -P ${UNRAR_BINARIES[$index]} 2>&1 > /dev/null ; then
      #Binary found
      UNRARALL_BIN="${UNRAR_BINARIES[$index]}"
      [ $VERBOSE -eq 1 ] && message ok "found"
      break;
    else
      [ $VERBOSE -eq 1 ] && message error "not found"
    fi

    #check if end of list
    if [ $index -eq $(( ${#UNRAR_BINARIES[@]} -1)) ]; then
      message error "Failed to find binary to perform rar extraction. The following binaries were looked for ${UNRAR_BINARIES[*]}"
      exit 1;
    fi
  done
else
  #check the manually specified binary exists
  if ! type -P ${UNRARALL_BIN} 2>&1 > /dev/null ; then
    message error "The manually specified binary ${UNRARALL_BIN} cannot be found"
    exit 1;
  fi
fi

#Inform the user about the binary chosen
[ $VERBOSE -eq 1 ] && message info "Using \"${UNRARALL_BIN}\" to extract rar files" ;

# Check $DIR exists and is a directory
if [ -d "$DIR" ]; then
  message normal "Working over directory \"${DIR}\""
else
  message error "Cannot find directory \"${DIR}\""
  exit 1;
fi

CURRENT_DIR=`pwd`

#find all files
COUNT=0

#modify IFS for new lines so filenames with spaces do not get split
IFS_TEMP=$IFS
IFS=$(echo -en "\n\b")
MATCHRARMIME='x-rar'

if [ "$CKSFV" -eq 1 ]; then
  if ! type -P cksfv 2>&1 > /dev/null ; then
    message info "Install cksfv in order to get CRC checked before using ${UNRAR_BINARIES}"
    CKSFV=0
  fi
fi

# assuming only the .rar files are of interest
for file in $(${FIND} "$DIR" -depth -iregex '.*\.\(rar\|001\)$'); do

  filename=`basename "${file}"`
  # Strip extension off filename
  sfilename="${filename%.*}"

  # if rar is of style partxx.rar then only extract $filename.part01.rar
  if [[ "$file" =~ .part[0-9]+.rar$ ]]; then
    if [[ "$file" =~ .part0*1.rar$ ]]; then
      sfilename=`echo "$sfilename" | sed 's/\.part[0-9]\+$//'`
      [ $VERBOSE -eq 1 ] && message info "Using rar 3.x split archive format"
    else
      continue
    fi
  # allow rar archives with .001 -> .999 naming
  elif [[ "$file" =~ .[0-9][0-9][0-9]$ ]]; then
    if [[ "$file" =~ .001$ ]]; then
      message info "Your packager is wrong, 001 is not an acceptable filename for a rar file. We'll attempt to clean up his mess anyways..."
    else
      continue
    fi
  fi
  let COUNT=COUNT+1
  dirname=`dirname "$file"`

  # check file really is a rar file
  if [[ ! "`file --mime "${file}"`" =~ $MATCHRARMIME ]]; then
    message error "Skipping file \"${file}\" because it does not appear to be a valid rar file."
    continue
  fi

  # move to directory
  cd "$dirname"
  RARFILE_DIR="$(pwd)"

  SUCCESS=0
  if [ "$CKSFV" -eq 1 ]; then
    # check an sfv file is present
    if [ -e "${sfilename}.sfv" ]; then
      message info "Running cksfv using ${sfilename}.sfv"
      eval cksfv ${CKSFV_FLAGS} \"${sfilename}.sfv\"
      # CKSFV will print error message even with -q on error
      SUCCESS=$?
    fi
  fi

  # Compute fullpath to rar file
  filenameAbsolute="$(pwd)/${filename}"

  # If user specified extraction directory change to it now
  if [ -n "${UNRARALL_OUTPUT_DIR}" ]; then
    cd "${UNRARALL_OUTPUT_DIR}"
    if [ $? -ne 0 ]; then
      message error "Failed to switch to output directory \"${UNRARALL_OUTPUT_DIR}\""
      exit 1
    fi
  fi

  # unrar file if SFV checked out or --force was given
  if [ "$SUCCESS" -eq 0 ] || [ "$FORCE" -eq 1 ]; then
    message nnl "Extracting (${UNRAR_METHOD}) \"$file\"..."
    file_encrypted=$(isRarEncrypted ${UNRARALL_BIN} ${filenameAbsolute})
    if [ "${file_encrypted}" -eq 0 ]; then
      # The file is not encrypted. We're extracting without a password
      if [ "$VERBOSE" -eq 1 ] || [ "$UNRARALL_BIN" = "echo" ] ; then
        ${UNRARALL_BIN} ${UNRAR_METHOD} $( getUnrarFlags ${UNRARALL_BIN}) -p- "$filenameAbsolute"
      else
        ${UNRARALL_BIN} ${UNRAR_METHOD} $( getUnrarFlags ${UNRARALL_BIN}) -p- "$filenameAbsolute" >/dev/null
      fi
      SUCCESS=$?
    else
      # The file is encrypted. if we have a password file, then use it
      if [ -s "${UNRARALL_PASSWORD_FILE}" ] ; then
        [ $VERBOSE -eq 1 ] && message info "This archive is encrypted. Trying passwords from password file \"${UNRARALL_PASSWORD_FILE}\"..."
        while true; do read password || break
          if [ "$VERBOSE" -eq 1 ] || [ "$UNRARALL_BIN" = "echo" ] ; then
            ${UNRARALL_BIN} ${UNRAR_METHOD} $( getUnrarFlags ${UNRARALL_BIN}) -p"$password" "$filenameAbsolute"
          else
            ${UNRARALL_BIN} ${UNRAR_METHOD} $( getUnrarFlags ${UNRARALL_BIN}) -p"$password" "$filenameAbsolute" >/dev/null
          fi
          SUCCESS=$?
          if [ "$SUCCESS" -eq 0 ] ; then
            [ $VERBOSE -eq 1 ] && message ok "Extraction succeeded using password: \"${password}\""
            break
          else
            [ $VERBOSE -eq 1 ] && message error "Extraction failed using password: \"${password}\""
          fi
        done < "$UNRARALL_PASSWORD_FILE"
      else
        message error "Archive \"$file\" is encrypted. Please put the password in \"${UNRARALL_PASSWORD_FILE}\" to extract it."
        SUCCESS=1
      fi
    fi
  fi
  # if fail remove from count
  if [ "$SUCCESS" -eq 0 ] && [ "$FORCE" -eq 0 ] ; then
    message ok "ok";
  elif [ "$SUCCESS" -eq 0 ] && [ "$FORCE" -eq 1 ] ; then
    message ok "ok (forced)";
  else
    let COUNT=COUNT-1
    [ "$FORCE" -eq 0 ] && message error "failed" || message error "failed (forced)"
  fi

  #Perform clean up if necessary
  if [ ${UNRARALL_CLEAN_UP_HOOKS_TO_RUN[0]} != "none" ]; then
    if  [ "$SUCCESS" -eq 0 ] || [ "$FORCE" -eq 1 ] ; then
      message nnl "Running hooks..."
      if [ ${UNRARALL_CLEAN_UP_HOOKS_TO_RUN[0]} = "all" ]; then
        #Run every clean up hook
        for hook in ${UNRARALL_DETECTED_CLEAN_UP_HOOKS[*]} ; do
          message nnl "$hook "
          ( unrarall-clean-$hook clean $sfilename "${RARFILE_DIR}" )
        done
      else
        #Run selected clean up hooks
        for hook in ${UNRARALL_CLEAN_UP_HOOKS_TO_RUN[*]} ; do
          message nnl "$hook "
          ( unrarall-clean-$hook clean $sfilename "${RARFILE_DIR}")
        done
      fi
      message ok "Finished running hooks"
    else
      message error "Couldn't do requested clean because ${UNRARALL_BIN} extracted unsuccessfully. Use --force to override this behaviour"
    fi
  fi

  cd "$CURRENT_DIR"
done
IFS=$IFS_TEMP

if [ "$QUIET" -ne 1 ]; then
  if [ "$COUNT" -ne 0 ]; then
    EXIT_PHRASE="found and extracted"
    if [ ${UNRARALL_CLEAN_UP_HOOKS_TO_RUN[0]} != "none" ]; then
      EXIT_PHRASE="found, extracted and then cleaned using the following hooks: ${UNRARALL_CLEAN_UP_HOOKS_TO_RUN[*]}"
    fi
    message info "$COUNT rar files $EXIT_PHRASE"
  else
    message error "no rar files extracted"
  fi
fi
