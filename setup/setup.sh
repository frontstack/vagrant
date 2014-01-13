#!/bin/bash
#
# FrontStack VM installation and provisioning script
# @author Tomas Aparicio
# @version 0.3
# @license WTFPL
#

szip_url=http://sourceforge.net/projects/frontstack/files/packages/7zip/7z-9.20-x64.tar.gz/download
temporal=/tmp/frontstack
download_dir=$temporal/downloads
output=$temporal/output.log
config_file="$(dirname $(readlink -f "$0")})/$(echo ${0##*/} | sed 's/\.[^\.]*$//').ini"
install_dir='/home/vagrant/frontstack'

# default install options (you can customize them from setup.ini)
fs_bash_profile=1
fs_reset_firewall=0
fs_format='tar.gz'
fs_user='vagrant'
fs_download='http://sourceforge.net/projects/frontstack/files/latest/download'
os_packages='gcc make nano wget'

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

config_parser() {
  ini="$(<$1)"               # read the file
  ini="${ini//[/\[}"          # escape [
  ini="${ini//]/\]}"          # escape ]
  IFS=$'\n' && ini=(${ini}) # convert to line-array
  ini=(${ini[*]//;*/})      # remove comments with ;
  ini=(${ini[*]/\    =/=})  # remove tabs before =
  ini=(${ini[*]/=\   /=})   # remove tabs be =
  ini=(${ini[*]/\ =\ /=})   # remove anything with a space around =
  ini=(${ini[*]/#\\[/\}$'\n'config.section.}) # set section prefix
  ini=(${ini[*]/%\\]/ \(})    # convert text2function (1)
  ini=(${ini[*]/=/=\( })    # convert item to array
  ini=(${ini[*]/%/ \)})     # close array parenthesis
  ini=(${ini[*]/%\\ \)/ \\}) # the multiline trick
  ini=(${ini[*]/%\( \)/\(\) \{}) # convert text2function (2)
  ini=(${ini[*]/%\} \)/\}}) # remove extra parenthesis
  ini[0]="" # remove first element
  ini[${#ini[*]} + 1]='}'    # add the last brace
  eval "$(echo "${ini[*]}")" # eval the result
}

proxy_auth() {
  if [ ! -z $proxy_user ]; then
    echo "--proxy-user=$proxy_user --proxy-password=$proxy_password "
  fi
}

download_status() {
  if [ -f $1 ]; then
    while : ; do
      sleep 1

      local speed=$(echo `cat $1 | grep -oh '\([0-9.]\+[%].*[0-9.][s|m|h|d]\)' | tail -1`)
      echo -n "Downloading... $speed"
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
  config_parser $config_file
  check_exit "Error while parsing config ini file: $config_file"

  # load config variables
  if [ `exists config.section.auth` -eq 1 ]; then
    config.section.auth
  fi
  
  if [ `exists config.section.frontstack` -eq 1 ]; then
    config.section.frontstack
  fi

  if [ ! -z $config.section.proxy ]; then
    config.section.proxy
  fi
  
  if [ ! -z $fs_install ]; then
    install_dir=$fs_install
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

if [ ! -z $fs_reset_firewall ] && [ $fs_reset_firewall -eq 1]; then
  iptables_flush
fi

cat <<EOF

 -------------------------------------
         Welcome to FrontStack
 -------------------------------------

 VM minimal requirements:
  * GNU/Linux 64 bit
  * 512MB RAM
  * 2GB HDD
  * Internet access (HTTP/S)

EOF

wget $(proxy_auth) http://yahoo.com -O $download_dir/test.html > $output 2>&1
check_exit "No Internet HTTP connectivity. Check if you are behind a proxy and your authentication credentials. See $output"
rm -f $download_dir/test.*

if [ $fs_format == '7z' ] || [ $fs_format == 'zip' ]; then
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
echo "Note this may take some minutes depending of your connection bandwidth... "
echo 

if [ -f $download_dir/download ]; then
  rm -f $download_dir/download
fi

# download stack distribution
if [ -z $fs_http_user ]; then
    `wget $(proxy_auth) -F $fs_download -O $download_dir/frontstack-latest.$fs_format > $output 2>&1 && echo $? > $download_dir/download || echo $? > $download_dir/download` &
    download_status $output $download_dir/download
else
  `wget $(proxy_auth) -F --user=$fs_http_user --password=$fs_http_password $fs_download -O $download_dir/frontstack-latest.$fs_format > $output 2>&1  && echo $? > $download_dir/download || echo $? > $download_dir/download` &
  download_status $output $download_dir/download
fi
check_exit "Error while trying to download FrontStack. See $output"

if [ $fs_format == 'rpm' ]; then
  if [ `exists rpm` -eq 0 ]; then
    echo "No rpm binary found. Cannot continue" && exit 1
  fi

  echo -n "Installing RPM... "
  rpm -ivh $download_dir/frontstack-latest.$fs_format >> $output 2>&1
  check_exit "Error while trying to install the RPM. See $output"
  echo 'done!'
else
  echo -n 'Extracting (this may take some minutes)... '
  make_dir $install_dir
  if [ $fs_format == '7z' ]; then
    $COMPRESSBIN e -o$install_dir -y $download_dir/frontstack-latest.$fs_format >> $output 2>&1
  else
    $COMPRESSBIN xvfz $download_dir/frontstack-latest.$fs_format -C $install_dir >> $output 2>&1
  fi
  check_exit "Error while trying to extract FrontStack. See $output"
  echo 'done!'
fi

# set file permissions (by default Vagrant uses the root user to run the provisioning tasks/scripts)
if [ ! -z $fs_user ]; then
  echo "Setting permissions for the '$fs_user' user..."
  chown -R $fs_user:users $install_dir >> $output
  check_exit "Error while trying to set files permissions. See $output"

  # load FrontStack environment variables at session startup (.bash_profile, .profile, .bashrc)
  if [ $fs_bash_profile == '1' ]; then
    if [ -d "/home/$fs_user" ]; then
      if [ -f "/home/$fs_user/.bash_profile" ]; then
        if [ $(exists `cat /home/$fs_user/.bash_profile | grep "$install_dir"`) -eq 1 ]; then
          echo ". $install_dir/bash.sh" >> "/home/$fs_user/.bash_profile"
        fi
      else
        # creates a new bash session profile by default
        echo "#!/bin/bash" > "/home/$fs_user/.bash_profile"
        echo ". $install_dir/bash.sh" >> "/home/$fs_user/.bash_profile"
        # setting permissions
        chown $fs_user:users "/home/$fs_user/.bash_profile" >> $output
        chmod +x "/home/$fs_user/.bash_profile"
      fi
    fi
  fi
fi

# installing OS packages (beta)
install_packages="$os_packages $install_packages"
install_packages=("$install_packages")
for pkg in "${install_packages[@]}"
do
  if [ `exists "$pkg"` -eq 0 ]; then
    echo "Installing $pkg..."
    install_package $pkg >> $output 2>&1
    check_exit "Cannot install the '$pkg' package. See $output"
  fi
done

# installing Node.js packages
if [ ! -z $npm ]; then
  for pkg in "${npm[@]}"
  do
    echo "Installing Node.js package '$pkg'..."
    npm install $pkg >> $output 2>&1
    check_sleep "Cannot install the '$pkg' package. See $output"
  done
fi

# install Ruby gems
if [ ! -z $gem ]; then
  for pkg in "$gem[@]}"
  do
    echo "Installing Ruby gem '$pkg'..."
    gem install $pkg >> $output 2>&1
    check_sleep "Cannot install the '$pkg' package. See $output"
  done
fi

# exec post install script
if [ ! -n $install_script ] && [ -f $install_script ]; then
  [ ! -x $install_script ] && chmod +x $install_script
  . "$install_script"
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
