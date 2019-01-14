# Place a startup script for application
echo "cd /opt/app" >> /etc/rc.d/rc.local
echo "python /opt/app/webserver.py &" >> /etc/rc.d/rc.local

# Make executable
chmod +x /etc/rc.d/rc.local

# Start the application
cd /opt/app
dos2unix /opt/app/webserver.py
python /opt/app/webserver.py &