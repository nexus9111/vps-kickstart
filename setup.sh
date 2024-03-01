#!/bin/bash

# Author: Joss C
# Contributors: 
# Usage ./script.sh [-k <sshkey>] [-u <newUser>]

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;32m'
B='\033[0;34m' 
NO='\033[0m'

while getopts ":k:u:" opt; do
  case $opt in
    k) sshkey="$OPTARG"
    ;;
    u) newUser="$OPTARG"
    ;;
    \?) echo -e "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
    -*) echo -e "Option $opt needs a valid argument"
    exit 1
    ;;
  esac
done

if [ "$EUID" -ne 0 ]
  then echo -e "${R}Please run as root${NO}"
  exit
fi

# ---------------------------------------------------------------------------- #
#                                    SCRIPT                                    #
# ---------------------------------------------------------------------------- #

echo -e "${G}-- Starting server preparation${NO}"
sudo apt update
sudo apt-get -y install unzip whois

# ---------------------------------------------------------------------------- #

echo -e "${G}-- UPDATE HISTORY DATE FORMAT${NO}"
echo 'HISTTIMEFORMAT="%F %T "' >> ~/.bashrc
source ~/.bashrc

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Updating root password${NO}"
password=$(openssl rand -base64 12)
echo -e "root:$password" | sudo chpasswd

# ---------------------------------------------------------------------------- #

if [[ "$newUser" != "" ]]; then
  echo -e "${G}-- Creating new user${NO}"
  newUserPassword=$(openssl rand -base64 12)
  sudo useradd -m -p $(openssl passwd -1 $newUserPassword) -s /bin/bash $newUser
  sudo usermod -aG sudo $newUser
fi

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Updating SSH Port${NO}"
sudo sed -i 's+#Port 22+Port 4222+g' /etc/ssh/sshd_config
sudo sed -i 's+ListenStream=22+ListenStream=4222+g' /lib/systemd/system/ssh.socket
sudo service ssh restart

# ---------------------------------------------------------------------------- #

if [[ "$sshkey" != "" ]]; then
    echo -e "${G}-- Adding SSH Key${NO}"
    mkdir ~/.ssh
    echo $sshkey >> ~/.ssh/authorized_keys

    if [[ "$newUser" != "" ]]; then
      echo -e "${G}-- Adding SSH Key to new user${NO}"
      sudo mkdir /home/$newUser/.ssh
      sudo chown $newUser:$newUser /home/$newUser/.ssh
      sudo echo $sshkey >> /home/$newUser/.ssh/authorized_keys
      sudo chown $newUser:$newUser /home/$newUser/.ssh/authorized_keys
    fi
fi

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Installing Docker and Docker Compose${NO}"
sudo apt-get -y install docker.io docker-compose
sudo systemctl start docker
sudo usermod -aG docker $USER
echo -e "-- Restarting Docker service"
sudo service docker restart
sudo /etc/init.d/docker restart
sudo snap restart docker

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Installing new Docker Compose command${NO}"
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.3.3/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Installing NoHang${NO}"
sudo add-apt-repository ppa:oibaf/test -y
sudo apt update -y
sudo apt -y install nohang
sudo systemctl enable --now nohang-desktop.service

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Installing git${NO}"
sudo apt-get -y install git

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Setup firewall${NO}"
sudo apt-get -y install ufw
sudo ufw allow 4222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Installing usefull tools${NO}"
sudo apt-get -y install htop
sudo apt-get -y install net-tools
sudo apt-get -y install tree
sudo apt-get -y install curl
sudo apt-get -y install wget
sudo apt-get -y install vim
sudo apt install python3 -y
sudo apt install python3-pip -y
sudo python3 -m pip install bpytop --upgrade

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Installing lsd${NO}"
wget https://github.com/lsd-rs/lsd/releases/download/0.23.1/lsd-musl_0.23.1_amd64.deb
sudo dpkg -i lsd-musl_0.23.1_amd64.deb
echo -e "alias ls='lsd'" >> ~/.zshrc
rm ./lsd-musl_*

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Add docker aliases${NO}"
echo -e "alias dps='docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\"'" >> ~/.zshrc
echo -e "alias dpsp='docker ps --format \"{{.Ports}} - {{.Names}} ({{.ID}})\" | grep 0.0.0.0'" >> ~/.zshrc
echo -e "alias dcd='docker-compose down'" >> ~/.zshrc
echo -e "alias dcu='docker-compose up -d'" >> ~/.zshrc

# ---------------------------------------------------------------------------- #

echo -e "${G}-- Installing Fail2Ban for Production server${NO}"
git clone https://github.com/fail2ban/fail2ban.git
cd fail2ban
sudo python3 setup.py install
sudo cp files/debian-initd /etc/init.d/fail2ban
sudo update-rc.d fail2ban defaults
sudo service fail2ban start
cd ..
sudo rm -rf fail2ban

# ---------------------------------------------------------------------------- #

# reboot the system
echo -e "${G}-- Rebooting the system ! See you soon ;-)${NO}"
echo -e "${Y}PLEASE NOTE: ${G}Your new root password is: ${R}$password${NO}"

if [[ "$newUser" != "" ]]; then
  echo -e "${Y}PLEASE NOTE: ${G}Your new user is: ${R}$newUser${NO}"
  echo -e "${Y}PLEASE NOTE: ${G}Your new user password is: ${R}$newUserPassword${NO}"
fi

sudo reboot now
