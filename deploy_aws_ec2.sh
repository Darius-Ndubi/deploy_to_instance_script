#!/bin/bash

#@---  Load environment variables to be used---@#
source .env


check_status_notify() {
    #@--- Set the argument passed ---@#
    package=$1

    #@--- Output a red-blinking error of the specific package installation failure ---@#
    #@--- Red ---@#
    echo -e "\033[31m ************* An error occured when trying to install ${package}.a Check the error above ****************"
    #@--- Break out of deploy sequence, Installation error should not proceed to run rest of process ---@#
    #@--- due to the error ---@#
    exit 1
}

#@--- function to handle instalation of all required dependancies ---@#
#@--- certbot, nodejs, npm and nginx ---@#
package_installations() {
    sudo add-apt-repository ppa:certbot/certbot -y
    apt-get update
    curl -sL https://deb.nodesource.com/setup_11.x | sudo bash -
    install_node="sudo apt-get install nodejs -y"
    eval ${install_node}
    #@--- If the installation task was not successfull, return 1 and break---@#
    if [ $? -gt 0 ]; then
        check_status_notify "nodejs_and_npm"
    #@--- Else, everything went okay then we install nginx ---@#
    else
        install_nginx="sudo apt-get install nginx -y"
        eval ${install_nginx}
        #@--- If the installation task was not successfull, return 1 and break---@#
        if [ $? -gt 0 ]; then
            check_status_notify "nginx"

        #@--- Else, everything went okay then we install certbot ---@#
        else
            install_certbot="sudo apt-get install python-certbot-nginx -y"
            eval ${install_certbot}
            #@--- If the installation task was not successfull, return 1 and break---@#
            #@--- Inform the user why the installation did not complete---@#
            if [ $? -gt 0 ]; then
                check_status_notify "certbot"
            else
                #@--- Serve installation, runs the builded version of the application--@#
                install_serve="sudo npm install serve -g"
                eval ${install_serve}
                if [ $? -gt 0 ]; then
                    check_status_notify "serve"
                fi
            fi
        fi
    fi
}


#@--- Function to handle nginx configurations ---@#
configure_nginx() {
    #@--- Check if nginx is active ---@#
    nginx_status='systemctl is-active nginx'
    current_nginx_status=eval ${nginx_status}

    #@--- If active, then then its running ---@#
    if [[ ${current_nginx_status} -eq 'active' ]]; then
        #@--- delete the default nginx configuration ---@#
        if [[ -e /etc/nginx/sites-enabled/default ]]; then
            sudo rm /etc/nginx/sites-enabled/default
            sudo rm /etc/nginx/sites-available/default
        fi
        echo -e "\033[31m ************* Removed the default config **************** "

        #@--- Copy config file for our service ---@#
        echo -e "\033[32m ************* Copied new config file ****************"
        sudo cp ah-frontend.conf /etc/nginx/sites-enabled/ah-frontend

        #@--- Link to sites available ---@#
        sudo ln -s /etc/nginx/sites-enabled/ah-frontend.conf /etc/nginx/sites-available/default

        #@--- restart nginx ---@#
        sudo /etc/init.d/nginx restart
    fi
}

configure_ssl () {
    #@--- Configure ssl to the application---@#
    #@--- the --nointeractive flag -> [run the command non interactively]---@#
    #@--- the --agree-tos flag ->[ agree to the terms of service ---@#
    #@--- the --redirect  flag -> [ redirect users when they access any of the domains specified ---@#
    sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME --noninteractive --agree-tos --redirect -m $USER_EMAIL
    #@--- Green ---@#
    echo -e "\033[32m -------------------- Generated the certificate, Good to go!----------------"

    #@--- Restart nginx ---@#
    sudo /etc/init.d/nginx restart
}

#@--- Fucntion to copy file to configure the application to be run as---@#
#@--- UNIX service in the background ---@#
configure_service() {
    sudo cp ah_background.service /lib/systemd/system/ah_background.service
}

#@--- Function to clone the applications code from the repo ---@#
avail_the_code() {
    #@--- If the directory already exists, delete it ---@#
    #@--- Clone the repo again and cd into ah-code-titans-frontend directory ---@#
    if [ -d "ah-code-titans-frontend/" ]; then
        sudo rm -rf ah-code-titans-frontend/
        git clone $GIT_REPOSITORY
        cd ah-code-titans-frontend/

    #@--- If the directory does not exist, clone it then cd into it ---@#
    else
        git clone $GIT_REPOSITORY
        eval "cd ah-code-titans-frontend/"
    fi
}


build_the_application() {
    #@--- Export route to the backend ---@#
    export REACT_APP_API=$REACT_API_LINK

    #@--- Blue ---@#
    echo -e "\033[34m --------------------Building ..........-----------------"

    #@--- Grant the current user priviledges to npm folder ---@#
    sudo chown -R `whoami` ~/.npm
    #@--- Install dependencies---@#
    npm i
    #@--- Build the application ---@#
    npm run build
    # destroy the files
}
#@--- fucntion to create a startfile ---@#
application_start_file() {
    touch /home/ubuntu/ah-code-titans-frontend/start_ah.sh && chmod u+x /home/ubuntu/ah-code-titans-frontend/start_ah.sh
    echo "serve -s build" | tee /home/ubuntu/ah-code-titans-frontend/start_ah.sh
}

#@--- Fucntion to start the application as a service---@#
start_application_service() {
    #@--- Reload the deamon ---@#
    sudo systemctl daemon-reload
    #@---Start the service just created ---@#
    sudo systemctl restart ah_background
    #@--- Enable the service so that it can be ran on boot ---@#
    sudo systemctl enable ah_background
}


#@--- Fucntion to run the sequence and start th app ---@#
run_deploy_sequence() {
    package_installations
    configure_nginx
    configure_ssl
    configure_service
    avail_the_code
    build_the_application
    application_start_file
    start_application_service
}

#@--- Run the whole script ---@#
run_deploy_sequence
