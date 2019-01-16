
# Install Prereqs
wget https://dl.google.com/go/go1.11.4.linux-amd64.tar.gz
tar -xzf go1.11.4.linux-amd64.tar.gz
mv go /usr/local
mkdir $HOME/Projects

# Set Go ENVvars and path
export GOROOT=/usr/local/go
export GOPATH=$HOME/Projects
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Set Go ENVvars and path permanent
echo "GOROOT=/usr/local/go" >>  ~/.bashrc
echo "GOPATH=$HOME/Projects" >>  ~/.bashrc
echo "PATH=$GOPATH/bin:$GOROOT/bin:$PATH" >>  ~/.bashrc

# Place a startup script for application
echo "cd /opt/app" >> /etc/rc.d/rc.local
echo "python /opt/app/webserver.py &" >> /etc/rc.d/rc.local

# Make executable
chmod +x /etc/rc.d/rc.local

# Start the application
cd /opt/app
dos2unix /opt/app/webserver.py
python /opt/app/webserver.py &

