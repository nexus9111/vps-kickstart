#!/bin/bash

# Author: Joss C
# Contributors: 
# Usage ./script.sh -s {yes;no} -n {yes;no}

while getopts ":s:n:" opt; do
  case $opt in
    s) server="$OPTARG"
    ;;
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

echo "-- Starting server preparation"
sudo apt update
sudo apt-get -y install unzip whois
echo 'HISTTIMEFORMAT="%F %T "' >> ~/.bashrc
source ~/.bashrc

echo "-- Updating root password"
password=$(whiptail --passwordbox "Please enter your new root password" 8 78 --title "Root Password" 3>&1 1>&2 2>&3)
echo "root:$password" | sudo chpasswd

echo "-- Creating new user"
username=$(whiptail --inputbox "Please enter new non root user username" 8 78 --title "Username" 3>&1 1>&2 2>&3)
password=$(whiptail --passwordbox "Please enter new non root user password" 8 78 --title "User Password" 3>&1 1>&2 2>&3)
sudo useradd -m -p $(openssl passwd -1 $password) -s /bin/bash $username
sudo usermod -aG sudo $username

echo "-- Updating SSH Port"
sudo sed -i 's+#Port 22+Port 4222+g' /etc/ssh/sshd_config
sudo service ssh restart

echo "-- Adding SSH Key"
sshkey=$(whiptail --inputbox "Please enter your SSH Public Key" 8 78 --title "SSH Key" 3>&1 1>&2 2>&3)
mkdir ~/.ssh
echo $sshkey >> ~/.ssh/authorized_keys
# add ssh key to new user
sudo mkdir /home/$username/.ssh
sudo chown $username:$username /home/$username/.ssh
sudo echo $sshkey >> /home/$username/.ssh/authorized_keys
sudo chown $username:$username /home/$username/.ssh/authorized_keys

# Docker
echo "-- Installing Docker and Docker Compose"
sudo apt-get -y install docker.io docker-compose
sudo systemctl start docker
sudo usermod -aG docker $USER
echo "-- Restarting Docker service"
sudo service docker restart
sudo /etc/init.d/docker restart
sudo snap restart docker

echo "-- Installing NoHang"
sudo add-apt-repository ppa:oibaf/test
sudo apt update
sudo apt -y install nohang
sudo systemctl enable --now nohang-desktop.service

echo "-- Installing git"
sudo apt-get -y install git

sudo apt-get -y install ufw
sudo ufw allow 4222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "-- Installing usefull tools"
sudo apt-get -y install htop
sudo apt-get -y install net-tools
sudo apt-get -y install tree
sudo apt-get -y install curl
sudo apt-get -y install wget
sudo apt-get -y install vim

if [[ "$server" == "yes" ]]; then
    echo "-- Installing Fail2Ban for Production server"
    sudo apt-get -y install fail2ban
fi

if [[ "$nginx" == "yes" ]]; then
    echo "-- Installing Nginx"
    email=$(whiptail --inputbox "Please enter your email for certbot" 8 78 --title "Email" 3>&1 1>&2 2>&3)
    docker run --restart always -d -it -p 80:80 -p 443:443 --env CERTBOT_EMAIL=$email \
           -v /srv/nginx/nginx_secrets:/etc/letsencrypt -v /srv/nginx/logs/:/logs/ \
           -v /srv/nginx/user_conf.d:/etc/nginx/user_conf.d:ro \
           --name nginx-certbot jonasal/nginx-certbot:latest
fi

echo "-- Installing Node Version Manager"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

echo "-- Installing OhMyZsh"
sudo apt-get -y install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="cloud"/g' ~/.zshrc

echo "-- Installing lsd"
wget https://github.com/lsd-rs/lsd/releases/download/0.23.1/lsd-musl_0.23.1_amd64.deb
sudo dpkg -i lsd-musl_0.23.1_amd64.deb
echo "alias ls='lsd'" >> ~/.zshrc
rm ./lsd-musl_*

echo "-- Add docker aliases"
echo "alias dps='docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\"'" >> ~/.zshrc
echo "alias dpsp='docker ps --format "{{.Ports}} - {{.Names}} ({{.ID}})" | grep 0.0.0.0'" >> ~/.zshrc
echo "alias dcd='docker-compose down'" >> ~/.zshrc
echo "alias dcu='docker-compose up -d'" >> ~/.zshrc


# reboot the system
echo "-- Rebooting the system"
sudo reboot now
