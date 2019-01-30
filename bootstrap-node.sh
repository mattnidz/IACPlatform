
# Install Prereqs
# wget https://dl.google.com/go/go1.11.4.linux-amd64.tar.gz
# tar -xzf go1.11.4.linux-amd64.tar.gz
# mv go /usr/local
# mkdir $HOME/Projects

# Set Go ENVvars and path
# export GOROOT=/usr/local/go
# export GOPATH=$HOME/Projects
# export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Set Go ENVvars and path permanent
# echo "GOROOT=/usr/local/go" >>  ~/.bashrc
# echo "GOPATH=$HOME/Projects" >>  ~/.bashrc
# echo "PATH=$GOPATH/bin:$GOROOT/bin:$PATH" >>  ~/.bashrc

# Docker CE For RHEL 7
yum update -y
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager -y --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install --setopt=obsoletes=0 -y docker-ce-17.03.2.ce-1.el7.centos.x86_64 docker-ce-selinux-17.03.2.ce-1.el7.centos.noarch
service docker start

# Place a startup script for application
# echo "cd /opt/app" >> /etc/rc.d/rc.local
# echo "python /opt/app/webserver.py &" >> /etc/rc.d/rc.local

# Make executable
# chmod +x /etc/rc.d/rc.local

# Get/Start the application


# dos2unix /opt/app/webserver.py
# python /opt/app/webserver.py &


