#!/bin/bash

#@---  Load environment variables to be used---@#
source .env

#@---  nginx config ---@#
primary_configuration="
server {
    listen 80;
    server_name $DOMAIN_NAME  www.$DOMAIN_NAME;

    location / {
        proxy_pass 'http://127.0.0.1:3000';
    }
}
"

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
    curl -sL https://deb.nodesource.com/setup_10.x | sudo bash -
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
                #@--- Forever installation, runs the application in the background---@#
                install_forever="sudo npm install forever -g"
                eval ${install_forever}
                if [ $? -gt 0 ]; then
                    check_status_notify "forever"
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
        fi
        echo -e "\033[31m ************* Removed the default config **************** "
        #@--- Create config file for our service ---@#
        sudo touch /etc/nginx/sites-enabled/ah-frontend
        echo -e "\033[32m ************* Created new config file ****************"

        #@--- Add nginx config to the file ---@#
        echo ${primary_configuration} | sudo tee /etc/nginx/sites-enabled/ah-frontend

        #@--- Link to sites available ---@#
        sudo ln -s /etc/nginx/sites-enabled/ah-frontend /etc/nginx/sites-available/ah-frontend

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

#@--- Function to clone the applications code from the repo ---@#
avail_the_code() {
    #@--- If the directory already exists, delete it ---@#
    #@--- Clone the repo again and cd into ah-code-titans-frontend directory ---@#
    if [ -d "ah-code-titans-frontend/" ]; then
        rm -rf ah-code-titans-frontend/
        git clone $GIT_REPOSITORY
        cd ah-code-titans-frontend/

    #@--- If the directory does not exist, clone it then cd into it ---@#
    else
        git clone $GIT_REPOSITORY
        eval "cd ah-code-titans-frontend/"
    fi
}


start_the_application() {
    #@--- Export route to the backend ---@#
    export REACT_APP_API=$REACT_API_LINK

    #@--- Blue ---@#
    echo -e "\033[34m --------------------Starting up.......-----------------"

    #@--- Start the application ---@#
    npm i

    #@--- Ininitate runnung the application in the background ---@#
    forever start -c "npm run start-js" .

    #@--- Check if the application is successfully running in the background---@#
    forever list
}

#@--- Fucntion to run the sequence and start th app ---@#
run_deploy_sequence() {
    package_installations
    configure_nginx
    configure_ssl
    avail_the_code
    start_the_application

}

#@--- Run the whole script ---@#
run_deploy_sequence
