# VPS KICKSTART
[DEVOPS]

## Initialise vps:

- If vps has a physical firewall (ionos vps has), you should enable 4222/TCP
- You need to get/create a public ssh key for connecting to the server later

### Usage

```console
# server mode will install fail2ban on the machine
$ chmod +x setup.sh

# simple run
$ ./setup.sh 

# add nginx/certbot on the server
$ ./setup.sh [...] -n yes
```

- Now you will be able to login on the server on port 4222
