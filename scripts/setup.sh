#!/bin/bash
#
# FrontStack VM installation and provisioning script
# @author Tomas Aparicio
# @version 0.1
# @license WTFPL
#
# TODO
# - Custom scripts pre/post install
#

SZIPURL=http://dl.bintray.com/frontstack/stable/7z/7z-9.20-x64.tar.gz
TEMPDIR=/tmp/frontstack
DOWNLOADSDIR=$TEMPDIR/downloads
OUTPUTLOG=$TEMPDIR/output.log
# default values (can be overwritten in setup.ini)
CONFIGFILE="$(dirname $(readlink -f "$0")})/$(echo ${0##*/} | sed 's/\.[^\.]*$//').ini"
INSTALLDIR='/home/vagrant/frontstack'

# default config (customize it from setup.ini)
fs_bashprofile=1
fs_format='tar.gz'
fs_user='vagrant'
fs_download='http://dl.dropboxusercontent.com/u/22374892/frontstack-0.1.0-x64.tar.gz'
install_packages='nano git gcc'

checkExitCode() {
  if [ $? -ne 0 ]; then
    echo $1
    exit 1
  fi
}

makeDir() {
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

installPackage() {
  if [ -z $NOPKGMANAGER ]; then
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
       # Set $NOPKGMANAGER
       NOPKGMANAGER=1
       echo "ERROR: impossible to found a package manager in your system. Install '$@' manually"
    fi
  fi
}

configParser() {
  ini="$(<$1)"               # read the file
  ini="${ini//[/\[}"          # escape [
  ini="${ini//]/\]}"          # escape ]
  IFS=$'\n' && ini=( ${ini} ) # convert to line-array
  ini=( ${ini[*]//;*/} )      # remove comments with ;
  ini=( ${ini[*]/\    =/=} )  # remove tabs before =
  ini=( ${ini[*]/=\   /=} )   # remove tabs be =
  ini=( ${ini[*]/\ =\ /=} )   # remove anything with a space around =
  ini=( ${ini[*]/#\\[/\}$'\n'config.section.} ) # set section prefix
  ini=( ${ini[*]/%\\]/ \(} )    # convert text2function (1)
  ini=( ${ini[*]/=/=\( } )    # convert item to array
  ini=( ${ini[*]/%/ \)} )     # close array parenthesis
  ini=( ${ini[*]/%\\ \)/ \\} ) # the multiline trick
  ini=( ${ini[*]/%\( \)/\(\) \{} ) # convert text2function (2)
  ini=( ${ini[*]/%\} \)/\}} ) # remove extra parenthesis
  ini[0]="" # remove first element
  ini[${#ini[*]} + 1]='}'    # add the last brace
  eval "$(echo "${ini[*]}")" # eval the result
}

getProxyAuth() {
  if [ ! -z $proxy_user ]; then
    echo "--proxy-user=$proxy_user --proxy-password=$proxy_password "
  fi
}

# Shows the wget download status progress
# @param wget output log file path
# @param completed file to check
downloadStatus() {
  if [ -f $1 ]; then
    while : ; do
      sleep 1

      local speed=$(echo `cat $1 | grep -oh '\([0-9.]\+[%].*[0-9.][s|m|h|d]\)' | tail -1`)
      echo -n "Downloading... $speed"
      echo -n R | tr 'R' '\r'
      # evaluate exit code?
      if [ -f $2 ]; then
        sleep 1
        local error=$(echo `cat $2`)
        if [ $error != '0' ]; then
          echo 
          if [ $error == '6' ]; then
            echo "Server authentication error, configure setup.ini properly. See $OUTPUTLOG"
          else
            echo "Download error, exit code '$error'. See $OUTPUTLOG"
          fi
          exit $?
        fi
        break
      fi
    done
  fi
}

# check OS architecture
if [ "`uname -m`" != "x86_64" ]; then
  echo 'FrontStack only supports 64 bit based OS. Cannot continue'
  exit 1
fi

# check if run as root
if [ "`id -u`" -ne 0 ]; then
  echo 'You must run the installer like a root user. Cannot continue'
  exit 1
fi

if [ ! -z $1 ] && [ -f $1 ]; then
  $CONFIGFILE="$1"
fi

# disabling SELinux if enabled
#if [ -f "/usr/sbin/getenforce" ] ; then
#    selinux_status=`/usr/sbin/getenforce`
#    /usr/sbin/setenforce 0 2> /dev/null
#fi

# read config file
if [ -f $CONFIGFILE ]; then
  configParser $CONFIGFILE
  checkExitCode "Error while parsing config ini file: $CONFIGFILE"

  # load config variables
  if [ `exists config.section.auth` -eq 1 ]; then
    config.section.auth
  fi
  
  if [ -z $config.section.frontstack ]; then
    echo "FrontStack config missing. Required"
    exit
  fi
  config.section.frontstack

  if [ ! -z $config.section.proxy ]; then
    config.section.proxy
  fi
  
  if [ ! -z $fs_install ]; then
    INSTALLDIR=$fs_install
  fi
fi

# creates temporal directories
makeDir $TEMPDIR
makeDir $DOWNLOADSDIR

if [ -d $INSTALLDIR ] && [ -f $INSTALLDIR/VERSION ]; then
  echo "FrontStack is already installed. Nothing to do"
  exit 0
fi

cat <<EOF
 -------------------------------------
         Welcome to FrontStack
 -------------------------------------
  
     Setup and provisioning script

 VM requirements:
  * GNU/Linux 64 bits
  * 768MB RAM
  * 1GB of hard disk free space
  * Internet access (HTTP/s protocol)
  * Root access level

EOF

wget $(getProxyAuth) http://yahoo.com -O $DOWNLOADSDIR/test.html > $OUTPUTLOG 2>&1
checkExitCode "No Internet HTTP connectivity. Check if you are behind a proxy and your authentication credentials. See $OUTPUTLOG"
rm -f $DOWNLOADSDIR/test.*

if [ $fs_format == '7z' ] || [ $fs_format == 'zip' ]; then
  if [ `exists 7z` -eq 0 ]; then
    if [ ! -f $TEMPDIR/7zip/7z ]; then
      echo -n "Downloding 7z... "
      wget $(getProxyAuth) $SZIPURL -O $DOWNLOADSDIR/7z.tar.gz >> $OUTPUTLOG 2>&1
      checkExitCode "Error while trying to download 7z. See $OUTPUTLOG"
      echo "done!"

      echo -n "Extracting 7z... "
      makeDir $TEMPDIR/7zip/
      tar xvfz $DOWNLOADSDIR/7z.tar.gz -C $TEMPDIR/7zip/ >> $OUTPUTLOG 2>&1
      checkExitCode "Error while trying to extract 7z.tar.gz. See $OUTPUTLOG"
      echo "done!"
      COMPRESSBIN=$TEMPDIR/7zip/7z
    fi
  fi
elif [ $fs_format == 'rpm' ]; then
  if [ -z $(echo `which rpm`) ]; then
    echo 'rpm package is not installed. Cannot continue'
    exit 1
  fi
else
  # set default to tar
  COMPRESSBIN=$(echo `which tar`)
fi

echo "Downloading lastest version of the FrontStack dev environment"
echo "Note this may take some minutes depending on your connection bandwidth... "
echo 

if [ -f $DOWNLOADSDIR/download ]; then
  rm -f $DOWNLOADSDIR/download
fi

# download stack distribution
if [ -z $fs_http_user ]; then
    `wget $(getProxyAuth) -F $fs_download -O $DOWNLOADSDIR/frontstack-latest.$fs_format > $OUTPUTLOG 2>&1 && echo $? > $DOWNLOADSDIR/download || echo $? > $DOWNLOADSDIR/download` &
    downloadStatus $OUTPUTLOG $DOWNLOADSDIR/download
else
  `wget $(getProxyAuth) -F --user=$fs_http_user --password=$fs_http_password $fs_download -O $DOWNLOADSDIR/frontstack-latest.$fs_format > $OUTPUTLOG 2>&1  && echo $? > $DOWNLOADSDIR/download || echo $? > $DOWNLOADSDIR/download` &
  downloadStatus $OUTPUTLOG $DOWNLOADSDIR/download
fi
checkExitCode "Error while trying to download FrontStack. See $OUTPUTLOG"

if [ $fs_format == 'rpm' ]; then
  if [ `exists rpm` -eq 0 ]; then
    echo "No rpm binary found. Cannot continue"
    exit 1
  fi

  echo -n "Installing RPM... "
  rpm -ivh $DOWNLOADSDIR/frontstack-latest.$fs_format >> $OUTPUTLOG 2>&1
  checkExitCode "Error while trying to install the RPM. See $OUTPUTLOG"
  echo 'done!'
else
  echo -n "Extracting (this may take some minutes)... "
  makeDir $INSTALLDIR
  if [ $fs_format == '7z' ]; then
    $COMPRESSBIN e -o$INSTALLDIR -y $DOWNLOADSDIR/frontstack-latest.$fs_format >> $OUTPUTLOG 2>&1
  else
    $COMPRESSBIN xvfz $DOWNLOADSDIR/frontstack-latest.$fs_format -C $INSTALLDIR >> $OUTPUTLOG 2>&1
  fi
  checkExitCode "Error while trying to extract FrontStack. See $OUTPUTLOG"
  echo 'done!'
fi

# set file permissions (by default Vagrant uses the root user to run the provisioning tasks/scripts)
if [ ! -z $fs_user ]; then
  echo "Setting permissions for the '$fs_user' user..."
  chown -R $fs_user:users $INSTALLDIR >> $OUTPUTLOG
  checkExitCode "Error while trying to set files permissions. See $OUTPUTLOG"

  # load FrontStack environment variables at session startup (.bash_profile, .profile, .bashrc)
  if [ $fs_bashprofile == '1' ]; then
    if [ -d "/home/$fs_user" ]; then
      if [ -f "/home/$fs_user/.bash_profile" ]; then
        if [ $(exists `cat /home/$fs_user/.bash_profile | grep $INSTALLDIR`) -eq 0 ]; then
          echo ". $INSTALLDIR/bash.sh" >> "/home/$fs_user/.bash_profile"
        fi
      else
        # creates a new bash session profile
        echo "#!/bin/bash" > "/home/$fs_user/.bash_profile"
        echo ". $INSTALLDIR/bash.sh" >> "/home/$fs_user/.bash_profile"
        # set permissions
        chown $fs_user:users "/home/$fs_user/.bash_profile" >> $OUTPUTLOG
        chmod +x "/home/$fs_user/.bash_profile"
      fi
    fi
  fi
fi

# installing OS packages (beta)
install_packages=($install_packages)
for pkg in "${install_packages[@]}"
do
  if [ `exists "$pkg"` -eq 0 ]; then
    echo "Installing $pkg..."
    installPackage $pkg >> $OUTPUTLOG 2>&1
    checkExitCode "Cannot install '$pkg' package. See $OUTPUTLOG"
  fi
done

# exec customized post install script
if [ ! -n $install_script ] && [ -f $install_script ]; then
  . "$install_script"
fi

cat <<EOF

FrontStack installed in: "$INSTALLDIR"

To have fun, run:
$ vagrant ssh

EOF
