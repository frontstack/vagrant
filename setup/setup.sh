#!/bin/bash
#
# FrontStack VM installation and provisioning script
# @author Tomas Aparicio
# @version 0.4
# @license WTFPL
#

szip_url=http://sourceforge.net/projects/frontstack/files/packages/7zip/7z-9.20-x64.tar.gz/download
temporal=/tmp/frontstack
download_dir=$temporal/downloads
output=$temporal/output.log
config_file="$(dirname $(readlink -f "$0")})/$(echo ${0##*/} | sed 's/\.[^\.]*$//').ini"
install_dir='/home/vagrant/frontstack'

# default install options (you can customize them from setup.ini)
bash_profile=1
conf__frontstack__reset_firewall=0
conf__frontstack__format='tar.gz'
conf__frontstack__user='vagrant'
conf__frontstack__download='http://sourceforge.net/projects/frontstack/files/latest/download'
conf__provision__packages='gcc make nano wget'

check_exit() {
  if [ $? -ne 0 ]; then
    echo $1 && exit 1
  fi
}

check_sleep() {
  if [ $? -ne 0 ]; then
    echo $1
    echo '\nContinuing with the provisioning...'
    sleep 2
  fi
}

make_dir() {
  if [ ! -d $1 ]; then
    mkdir $1
  fi
}

exists() {
  type $1 >/dev/null 2>&1;
  if [ $? -eq 0 ]; then
    echo 1
  else
    echo 0
  fi
}

install_package() {
  if [ -z $nopkgmanager ]; then
    # Debian, Ubuntu and derivatives (with apt-get)
    if which apt-get &> /dev/null; then
      apt-get install -y "$@"
    # OpenSuse (with zypper)
    elif which zypper &> /dev/null; then
      zypper install -y "$@"
    # Mandriva (with urpmi)
    elif which urpmi &> /dev/null; then
      urpmi "$@"
    # Fedora and CentOS (with yum)
    elif which yum &> /dev/null; then
      yum install -y "$@"
    # ArchLinux (with pacman)
    elif which pacman &> /dev/null; then
      pacman -Sy "$@"
    # Else, if no package manager has been founded
    else
       # Set $nopkgmanager
       nopkgmanager=1
       echo "ERROR: impossible to found a package manager in your system. Install '$@' manually"
    fi
  fi
}

save_proxy_vars() {
  if [ -f $1 ]; then
    if [ ! -z "$http_proxy" ]; then
      echo "http_proxy=$http_proxy" >> $1
    fi
    if [ ! -z "$https_proxy" ]; then
      echo "https_proxy=$https_proxy" >> $1
    fi
    if [ ! -z "$no_proxy" ]; then
      echo "no_proxy=$no_proxy" >> $1
    fi
  fi
}

proxy_auth() {
  if [ ! -z $conf__proxy__user ]; then
    echo "--proxy-user=$conf__proxy__user --proxy-password=$conf__proxy__password "
  fi
}

download_status() {
  if [ -f $1 ]; then
    while : ; do
      sleep 1

      local speed=$(echo `cat $1 | grep -oh '\([0-9.]\+[%].*[0-9.][s|m|h|d]\)' | tail -1`)
      echo -n ">> Downloading... $speed"
      echo -n R | tr 'R' '\r'

      if [ -f $2 ]; then
        sleep 1
        local error=$(echo `cat $2`)
        if [ $error != '0' ]; then
          echo 
          if [ $error == '6' ]; then
            echo "Server authentication error, configure setup.ini properly. See $output"
          else
            echo "Download error, exit code '$error'. See $output"
          fi
          exit $?
        fi
        break
      fi
    done
  fi
}

iptables_flush() {
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -X
  iptables -t mangle -F
  iptables -t mangle -X
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
}

#
# Copyright (c) 2009    Kevin Porter / Advanced Web Construction Ltd
#                       (http://coding.tinternet.info, http://webutils.co.uk)
# Copyright (c) 2010-2012     Ruediger Meier <sweet_f_a@gmx.de>
#                             (https://github.com/rudimeier/)
#
# Simple INI file parser
#
read_ini() {

  # Be strict with the prefix, since it's going to be run through eval
  check_prefix() {
    if ! [[ "${VARNAME_PREFIX}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
      echo "read_ini: invalid prefix '${VARNAME_PREFIX}'" >&2
      return 1
    fi
  }
  
  check_ini_file() {
    if [ ! -r "$INI_FILE" ]; then
      echo "read_ini: '${INI_FILE}' doesn't exist or not" \
              "readable" >&2
      return 1
    fi
  }
  
  # enable some optional shell behavior (shopt)
  pollute_bash() {
    if ! shopt -q extglob ; then
      SWITCH_SHOPT="${SWITCH_SHOPT} extglob"
    fi
    if ! shopt -q nocasematch ; then
      SWITCH_SHOPT="${SWITCH_SHOPT} nocasematch"
    fi
    shopt -q -s ${SWITCH_SHOPT}
  }
  
  # unset all local functions and restore shopt settings before returning
  # from read_ini()
  cleanup_bash() {
    shopt -q -u ${SWITCH_SHOPT}
    unset -f check_prefix check_ini_file pollute_bash cleanup_bash
  }
  
  local INI_FILE=""
  local INI_SECTION=""

  # {{{ START Deal with command line args
  # Set defaults
  local BOOLEANS=1
  local VARNAME_PREFIX=INI
  local CLEAN_ENV=0

  while [ $# -gt 0 ]
  do
    case $1 in
        --clean | -c )
          CLEAN_ENV=1
        ;;

        --booleans | -b )
          shift
          BOOLEANS=$1
        ;;

        --prefix | -p )
          shift
          VARNAME_PREFIX=$1
        ;;

        *)
          if [ -z "$INI_FILE" ]; then
            INI_FILE=$1
          else
            if [ -z "$INI_SECTION" ]; then
              INI_SECTION=$1
            fi
          fi
        ;;
    esac
    shift
  done

  if [ -z "$INI_FILE" ] && [ "${CLEAN_ENV}" = 0 ]; then
    echo -e "Usage: read_ini [-c] [-b 0| -b 1]] [-p PREFIX] FILE"\
            "[SECTION]\n  or   read_ini -c [-p PREFIX]" >&2
    cleanup_bash
    return 1
  fi

  if ! check_prefix ; then
    cleanup_bash
    return 1
  fi

  local INI_ALL_VARNAME="${VARNAME_PREFIX}__ALL_VARS"
  local INI_ALL_SECTION="${VARNAME_PREFIX}__ALL_SECTIONS"
  local INI_NUMSECTIONS_VARNAME="${VARNAME_PREFIX}__NUMSECTIONS"
  if [ "${CLEAN_ENV}" = 1 ]; then
          eval unset "\$${INI_ALL_VARNAME}"
  fi
  unset ${INI_ALL_VARNAME}
  unset ${INI_ALL_SECTION}
  unset ${INI_NUMSECTIONS_VARNAME}

  if [ -z "$INI_FILE" ]; then
    cleanup_bash
    return 0
  fi
  
  if ! check_ini_file ;then
    cleanup_bash
    return 1
  fi

  # Sanitise BOOLEANS - interpret "0" as 0, anything else as 1
  if [ "$BOOLEANS" != "0" ]; then
    BOOLEANS=1
  fi
  # }}} END Options
  # }}} END Deal with command line args

  local LINE_NUM=0
  local SECTIONS_NUM=0
  local SECTION=""
  
  # IFS is used in "read" and we want to switch it within the loop
  local IFS=$' \t\n'
  local Iconf__frontstack__OLD="${IFS}"
  
  # we need some optional shell behavior (shopt) but want to restore
  # current settings before returning
  local SWITCH_SHOPT=""
  pollute_bash
  
  while read -r line || [ -n "$line" ]
  do
  #echo line = "$line"

    ((LINE_NUM++))

    # Skip blank lines and comments
    if [ -z "$line" -o "${line:0:1}" = ";" -o "${line:0:1}" = "#" ]; then
      continue
    fi

    # Section marker?
    if [[ "${line}" =~ ^\[[a-zA-Z0-9_]{1,}\]$ ]]; then
      # Set SECTION var to name of section (strip [ and ] from section marker)
      SECTION="${line#[}"
      SECTION="${SECTION%]}"
      eval "${INI_ALL_SECTION}=\"\${${INI_ALL_SECTION}# } $SECTION\""
      ((SECTIONS_NUM++))
      continue
    fi

    # Are we getting only a specific section? And are we currently in it?
    if [ ! -z "$INI_SECTION" ]; then
      if [ "$SECTION" != "$INI_SECTION" ]; then
        continue
      fi
    fi

    # Valid var/value line? (check for variable name and then '=')
    if ! [[ "${line}" =~ ^[a-zA-Z0-9._]{1,}[[:space:]]*= ]]; then
      echo "Error: Invalid line:" >&2
      echo " ${LINE_NUM}: $line" >&2
      cleanup_bash
      return 1
    fi

    # split line at "=" sign
    IFS="="
    read -r VAR VAL <<< "${line}"
    IFS="${Iconf__frontstack__OLD}"
    
    # delete spaces around the equal sign (using extglob)
    VAR="${VAR%%+([[:space:]])}"
    VAL="${VAL##+([[:space:]])}"
    VAR=$(echo $VAR)

    # Construct variable name:
    # ${VARNAME_PREFIX}__$SECTION__$VAR
    # Or if not in a section:
    # ${VARNAME_PREFIX}__$VAR
    # In both cases, full stops ('.') are replaced with underscores ('_')
    if [ -z "$SECTION" ]; then
      VARNAME=${VARNAME_PREFIX}__${VAR//./_}
    else
      VARNAME=${VARNAME_PREFIX}__${SECTION}__${VAR//./_}
    fi
    eval "${INI_ALL_VARNAME}=\"\${${INI_ALL_VARNAME}# } ${VARNAME}\""

    if [[ "${VAL}" =~ ^\".*\"$  ]]
    then
      # remove existing double quotes
      VAL="${VAL##\"}"
      VAL="${VAL%%\"}"
    elif [[ "${VAL}" =~ ^\'.*\'$  ]]
    then
      # remove existing single quotes
      VAL="${VAL##\'}"
      VAL="${VAL%%\'}"
    elif [ "$BOOLEANS" = 1 ]
    then
      # Value is not enclosed in quotes
      # Booleans processing is switched on, check for special boolean
      # values and convert

      # here we compare case insensitive because
      # "shopt nocasematch"
      case "$VAL" in
        yes | true | on )
                VAL=1
        ;;
        no | false | off )
                VAL=0
        ;;
      esac
    fi
    
    # enclose the value in single quotes and escape any
    # single quotes and backslashes that may be in the value
    VAL="${VAL//\\/\\\\}"
    VAL="\$'${VAL//\'/\'}'"

    eval "$VARNAME=$VAL"

  done <"${INI_FILE}"
  
  # return also the number of parsed sections
  eval "$INI_NUMSECTIONS_VARNAME=$SECTIONS_NUM"

  cleanup_bash
}

# check OS architecture
if [ "`uname -m`" != "x86_64" ]; then
  echo 'FrontStack only supports 64 bit based OS. Cannot continue' && exit 1
fi

# check if run as root
if [ "`id -u`" -ne 0 ]; then
  echo 'You must run the installer like a root user. Cannot continue' && exit 1
fi

if [ ! -z $1 ] && [ -f $1 ]; then
  $config_file="$1"
fi

# disabling SELinux if enabled
if [ -f "/usr/sbin/getenforce" ] ; then
  selinux_status=`/usr/sbin/getenforce`
  /usr/sbin/setenforce 0 2> /dev/null
fi

# read config file
if [ -f $config_file ]; then

  read_ini $config_file -p conf
  check_exit "Error while parsing config ini file: $config_file"

  if [ ! -z "$conf__proxy__http_proxy" ]; then
    http_proxy=$conf__proxy__http_proxy
  fi

  if [ ! -z "$conf__proxy__https_proxy" ]; then
    https_proxy=$conf__proxy__https_proxy
  fi

  if [ ! -z "$conf__proxy__no_proxy" ]; then
    no_proxy=$conf__proxy__no_proxy
  fi

  if [ ! -z "$conf__frontstack__install" ]; then
    install_dir=$conf__frontstack__install
  fi
fi

# creates temporal directories
make_dir $temporal
make_dir $download_dir

if [ -d $install_dir ] && [ -f $install_dir/VERSION ]; then
  echo "FrontStack is already installed" && exit 0
fi

if [ `exists wget` -eq 0 ]; then
  install_package wget > /dev/null
fi

if [ "$conf__frontstack__reset_firewall" -eq 1 ]; then
  iptables_flush
fi

cat <<EOF

 -------------------------------------
         Welcome to FrontStack
 -------------------------------------

 Minimal requirements:
  * GNU/Linux 64 bit
  * 512MB RAM
  * 1GB free disk space
  * Internet access (HTTP/S)

EOF

wget $(proxy_auth) http://yahoo.com -O $download_dir/test.html > $output 2>&1
check_exit "No Internet HTTP connectivity. Check if you are behind a proxy and your authentication credentials. See $output"
rm -f $download_dir/test.*

if [ "$conf_frontstack_format" == '7z' ] || [ "$conf_frontstack_format" == 'zip' ]; then
  if [ `exists 7z` -eq 0 ]; then
    if [ ! -f $temporal/7zip/7z ]; then
      echo -n "Downloding 7z... "
      wget $(proxy_auth) $szip_url -O $download_dir/7z.tar.gz >> $output 2>&1
      check_exit "Error while trying to download 7z. See $output"
      echo "done!"

      echo -n "Extracting 7z... "
      make_dir $temporal/7zip/
      tar xvfz $download_dir/7z.tar.gz -C $temporal/7zip/ >> $output 2>&1
      check_exit "Error while trying to extract 7z.tar.gz. See $output"
      echo "done!"
      COMPRESSBIN=$temporal/7zip/7z
    fi
  fi
elif [ "$conf_frontstack_format" == 'rpm' ]; then
  if [ -z $(echo `which rpm`) ]; then
    echo 'rpm package not supported, use another. Cannot continue'
    exit 1
  fi
else
  # set default to tar
  COMPRESSBIN=$(echo `which tar`)
fi

echo "Downloading lastest version of the FrontStack dev environment"
echo "Note this may take some minutes depending of your connection bandwidth... "
echo 

if [ -f $download_dir/download ]; then
  rm -f $download_dir/download
fi

# download stack distribution
if [ -z "$conf__frontstack__http_user" ]; then
    `wget $(proxy_auth) -F $conf__frontstack__download -O $download_dir/frontstack-latest.$conf__frontstack__format > $output 2>&1 && echo $? > $download_dir/download || echo $? > $download_dir/download` &
    download_status $output $download_dir/download
else
  `wget $(proxy_auth) -F --user=$conf__frontstack__http_user --password=$conf__frontstack__http_password $conf__frontstack__download -O $download_dir/frontstack-latest.$conf__frontstack__format > $output 2>&1  && echo $? > $download_dir/download || echo $? > $download_dir/download` &
  download_status $output $download_dir/download
fi
check_exit "Error while trying to download FrontStack. See $output"

if [ $conf__frontstack__format == 'rpm' ]; then
  if [ `exists rpm` -eq 0 ]; then
    echo "No rpm binary found. Cannot continue" && exit 1
  fi

  echo -n "Installing RPM... "
  rpm -ivh $download_dir/frontstack-latest.$conf__frontstack__format >> $output 2>&1
  check_exit "Error while trying to install the RPM. See $output"
  echo 'done!'
else
  echo -n 'Extracting (this may take some minutes)... '
  make_dir $install_dir
  if [ $conf__frontstack__format == '7z' ]; then
    $COMPRESSBIN e -o$install_dir -y $download_dir/frontstack-latest.$conf__frontstack__format >> $output 2>&1
  else
    $COMPRESSBIN xvfz $download_dir/frontstack-latest.$conf__frontstack__format -C $install_dir >> $output 2>&1
  fi
  check_exit "Error while trying to extract FrontStack. See $output"
  echo 'done!'
fi

# set file permissions (by default Vagrant uses the root user to run the provisioning tasks/scripts)
if [ ! -z $conf__frontstack__user ]; then
  echo "Setting permissions for the '$conf__frontstack__user' user..."
  chown -R $conf__frontstack__user:users $install_dir >> $output
  check_exit "Error while trying to set files permissions. See $output"

  # load FrontStack environment variables at session startup (.bash_profile, .profile, .bashrc)
  if [ $bash_profile == '1' ]; then
    if [ -d "/home/$conf__frontstack__user" ]; then
      if [ -f "/home/$conf__frontstack__user/.bash_profile" ]; then
        if [ $(exists `cat /home/$conf__frontstack__user/.bash_profile | grep "$install_dir"`) -eq 1 ]; then
          echo ". $install_dir/bash.sh" >> "/home/$conf__frontstack__user/.bash_profile"
          save_proxy_vars "/home/$conf__frontstack__user/.bash_profile"
        fi
      else
        # creates a new bash session profile by default
        echo '#!/bin/bash' > "/home/$conf__frontstack__user/.bash_profile"
        echo '. $install_dir/bash.sh' >> "/home/$conf__frontstack__user/.bash_profile"
        save_proxy_vars "/home/$conf__frontstack__user/.bash_profile"

        # setting permissions
        chown $conf__frontstack__user:users "/home/$conf__frontstack__user/.bash_profile" >> $output
        chmod +x "/home/$conf__frontstack__user/.bash_profile"
      fi
    fi
  fi
fi

# installing OS packages (beta)
install_packages=("$os_packages $conf__provision__packages")
for pkg in "${install_packages[@]}"
do
  if [ `exists "$pkg"` -eq 0 ]; then
    echo "Installing $pkg..."
    install_package $pkg >> $output 2>&1
    check_exit "Cannot install the '$pkg' package. See $output"
  fi
done

# installing Node.js packages
if [ ! -z "$conf__provision__npm" ]; then
  conf__provision__npm=("$conf__provision__npm")
  for pkg in "${conf__provision__npm[@]}"
  do
    echo "Installing Node.js package '$pkg'..."
    npm install $pkg >> $output 2>&1
    check_sleep "Cannot install the '$pkg' package. See $output"
  done
fi

# install Ruby gems
if [ ! -z "$conf__provision__gem" ]; then
  conf__provision__gem=("$conf__provision__gem")
  for pkg in "$conf__provision__gem[@]}"
  do
    echo "Installing Ruby gem '$pkg'..."
    gem install $pkg >> $output 2>&1
    check_sleep "Cannot install the '$pkg' package. See $output"
  done
fi

# custom provisioning script
if [ ! -n "$conf__provision__script" ] && [ -f $conf__provision__script ]; then
  [ ! -x $conf__provision__script ] && chmod +x $conf__provision__script
  . "$conf__provision__script"
fi

# exec the custom post-install script
if [ ! -n "$conf__frontstack__post_install" ] && [ -f $conf__frontstack__post_install ]; then
  [ ! -x $conf__frontstack__post_install ] && chmod +x $conf__frontstack__post_install
  . "$conf__frontstack__post_install"
fi

# re-enable SELinux
if [ -f "/usr/sbin/getenforce" ]; then
  selinux_status=`/usr/sbin/getenforce`
  /usr/sbin/setenforce 1 2> /dev/null
fi

cat <<EOF

FrontStack installed in: "$install_dir"

To enter in the machine, from the Vagrantfile directory, run:
$ vagrant ssh

EOF
