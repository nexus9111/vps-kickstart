#!/bin/bash

# Author: Joss C
# Contributors: 
# Usage ./script.sh -s {yes;no} -n {yes;no}

R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;32m'
B='\033[0;34m' 
NO='\033[0m'

while getopts ":s:n:" opt; do
  case $opt in
    # s) server="$OPTARG"
    # ;;
    n) nginx="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
    -*) echo "Option $opt needs a valid argument"
    exit 1
    ;;
  esac
done

# ---------------------------------------------------------------------------- #
#                                    SCRIPT                                    #
# ---------------------------------------------------------------------------- #

echo "${G}-- Starting server preparation${NO}"
sudo apt update
sudo apt-get -y install unzip whois

# ---------------------------------------------------------------------------- #

echo "${G}-- UPDATE HISTORY DATE FORMAT${NO}"
echo 'HISTTIMEFORMAT="%F %T "' >> ~/.bashrc
source ~/.bashrc

# ---------------------------------------------------------------------------- #

echo "${G}-- Updating root password${NO}"
password=$(whiptail --passwordbox "Please enter your new root password" 8 78 --title "Root Password" 3>&1 1>&2 2>&3)
echo "root:$password" | sudo chpasswd

# ---------------------------------------------------------------------------- #

echo "${G}-- Updating SSH Port${NO}"
sudo sed -i 's+#Port 22+Port 4222+g' /etc/ssh/sshd_config
sudo service ssh restart

# ---------------------------------------------------------------------------- #

echo "${G}-- Adding SSH Key${NO}"
sshkey=$(whiptail --inputbox "Please enter your SSH Public Key (leave empty to skip)" 8 78 --title "SSH Key" 3>&1 1>&2 2>&3)
mkdir ~/.ssh
echo $sshkey >> ~/.ssh/authorized_keys

# ---------------------------------------------------------------------------- #

echo "${G}-- Installing Docker and Docker Compose${NO}"
sudo apt-get -y install docker.io docker-compose
sudo systemctl start docker
sudo usermod -aG docker $USER
echo "-- Restarting Docker service"
sudo service docker restart
sudo /etc/init.d/docker restart
sudo snap restart docker

# ---------------------------------------------------------------------------- #

echo "${G}-- Installing new Docker Compose command${NO}"
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.3.3/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# ---------------------------------------------------------------------------- #

echo "${G}-- Installing NoHang${NO}"
sudo add-apt-repository ppa:oibaf/test
sudo apt update
sudo apt -y install nohang
sudo systemctl enable --now nohang-desktop.service

# ---------------------------------------------------------------------------- #

echo "${G}-- Installing git${NO}"
sudo apt-get -y install git

# ---------------------------------------------------------------------------- #

echo "${G}-- Setup firewall${NO}"
sudo apt-get -y install ufw
sudo ufw allow 4222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# ---------------------------------------------------------------------------- #

echo "${G}-- Installing usefull tools${NO}"
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

echo "${G}-- Installing lsd${NO}"
wget https://github.com/lsd-rs/lsd/releases/download/0.23.1/lsd-musl_0.23.1_amd64.deb
sudo dpkg -i lsd-musl_0.23.1_amd64.deb
echo "alias ls='lsd'" >> ~/.zshrc
rm ./lsd-musl_*

# ---------------------------------------------------------------------------- #

echo "${G}-- Add docker aliases${NO}"
echo "alias dps='docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\"'" >> ~/.zshrc
echo "alias dpsp='docker ps --format \"{{.Ports}} - {{.Names}} ({{.ID}})\" | grep 0.0.0.0'" >> ~/.zshrc
echo "alias dcd='docker-compose down'" >> ~/.zshrc
echo "alias dcu='docker-compose up -d'" >> ~/.zshrc

# ---------------------------------------------------------------------------- #

echo "${G}-- Installing Fail2Ban for Production server${NO}"
git clone https://github.com/fail2ban/fail2ban.git
cd fail2ban
sudo python3 setup.py install
sudo cp files/debian-initd /etc/init.d/fail2ban
sudo update-rc.d fail2ban defaults
sudo service fail2ban start
cd ..
sudo rm -rf fail2ban

# ---------------------------------------------------------------------------- #

if [[ "$nginx" == "yes" ]]; then
    echo "-- Installing Nginx"
    email=$(whiptail --inputbox "Please enter your email for certbot" 8 78 --title "Email" 3>&1 1>&2 2>&3)
    docker run --restart always -d -it -p 80:80 -p 443:443 --env CERTBOT_EMAIL=$email \
           -v /srv/nginx/nginx_secrets:/etc/letsencrypt -v /srv/nginx/logs/:/logs/ \
           -v /srv/nginx/user_conf.d:/etc/nginx/user_conf.d:ro \
           --name nginx-certbot jonasal/nginx-certbot:latest
    docker network create nginx-proxy
    docker network connect nginx-proxy nginx-certbot
fi

# reboot the system
echo "${G}-- Rebooting the system ! See you soon ;-)${NO}"
sudo reboot now
