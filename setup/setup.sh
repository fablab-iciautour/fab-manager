#!/bin/bash

DOMAINS=()

welcome_message()
{
  clear
  echo "#======================================================================#"
  echo -e "#\e[31m    ____  __   ____       _  _   __   __ _   __    ___  ____  ____    \e[0m#"
  echo -e "#\e[31m   (  __)/ _\ (  _ \ ___ ( \/ ) / _\ (  ( \ / _\  / __)(  __)(  _ \   \e[0m#"
  echo -e "#\e[31m    ) _)/    \ ) _ ((___)/ \/ \/    \/    //    \( (_ \ ) _)  )   /   \e[0m#"
  echo -e "#\e[31m   (__) \_/\_/(____/     \_)(_/\_/\_/\_)__)\_/\_/ \___/(____)(__\_)   \e[0m#"
  echo "#                                                                      #"
  echo "#======================================================================#"
  printf "\n                 Welcome to Fab-manager's setup assistant\n\n\n"
  echo "Thank you for installing Fab-manager."
  printf "This script will guide you through the installation process of Fab-manager\n\n"
  echo -e "Please report any \e[1mfeedback or improvement request\e[21m on https://feedback.fab-manager.com/"
  echo -e "For \e[1mbug reports\e[21m, please open a new issue on https://github.com/sleede/fab-manager/issues"
  echo -e "You can call for \e[1mcommunity assistance\e[21m on https://forum.fab-manager.com/"
  printf "\nYou can interrupt this installation at any time by pressing Ctrl+C\n"
  printf "If you do not feel confortable with this installation, you can \e[4msubscribe to our hosting plan\e[24m: contact@fab-manager.com\n\n"
  read -rp "Continue? (Y/n) " confirm </dev/tty
  if [[ "$confirm" = "n" ]]; then exit 1; fi
}

system_requirements()
{
  if [ "$(whoami)" = "root" ]; then
    echo "It is not recommended to run this script as root. As a normal user, elevation will be prompted if needed."
    read -rp "Continue anyway? (Y/n) " confirm </dev/tty
    if [[ "$confirm" = "n" ]]; then exit 1; fi
  else
    local _groups=("sudo" "docker")
    for _group in "${_groups[@]}"; do
      echo -e "detecting group $_group for current user..."
      if ! groups | grep "$_group"; then
        echo "Please add your current user to the $_group group."
        echo "You can run the following as root: \"usermod -aG $_group $(whoami)\", then logout and login again"
        echo -e "\e[91m[ ❌ ] current user is misconfigured, exiting...\e[39m" && exit 1
      fi
    done
  fi
  local _commands=("sudo" "curl" "sed" "openssl" "docker" "docker-compose" "systemctl")
  for _command in "${_commands[@]}"; do
    echo "detecting $_command..."
    if ! command -v "$_command"
    then
      echo "Please install $_command before running this script."
      echo -e "\e[91m[ ❌ ] $_command was not found, exiting...\e[39m" && exit 1
    fi
  done
  if ! command -v awk || ! [[ $(awk -W version) =~ ^GNU ]]
  then
    echo "Please install GNU Awk before running this script."
    echo "\e[91m[ ❌ ] GNU awk was not found, exiting...\e[39m" && exit 1
  fi
  printf "\e[92m[ ✔ ] All requirements successfully checked.\e[39m \n\n"
}

read_email()
{
  local email
  read -rp "Please input a valid email address > " email </dev/tty
  if [[ "$email" == *"@"*"."* ]]; then
    EMAIL="$email"
  else
    read_email
  fi
}

config()
{
  echo 'We recommend nginx to serve the application over the network (internet). You can use your own solution or let this script install and configure nginx for Fab-manager.'
  read -rp 'Do you want install nginx? (Y/n) ' NGINX </dev/tty
  if [ "$NGINX" != "n" ]; then
    # if the user doesn't want nginx, let him use its own solution for HTTPS
    printf "\n\nWe recommend let's encrypt to secure the application with HTTPS. You can use your own certificate or let this script install and configure let's encrypt for Fab-manager.\n"
    read -rp "Do you want install let's encrypt? (Y/n) " LETSENCRYPT </dev/tty
    if [ "$LETSENCRYPT" != "n" ]; then
      printf "\n\nLet's encrypt requires an email address to receive notifications about certificate expiration.\n"
      read_email
    fi
    # if the user doesn't want nginx, let him configure his own solution
    printf "\n\nWhat's the domain name where the instance will be active (eg. fab-manager.com)?\n"
    read_domain
    MAIN_DOMAIN=("${DOMAINS[0]}")
    OTHER_DOMAINS=${DOMAINS[*]/$MAIN_DOMAIN}
  else
    LETSENCRYPT="n"
  fi
}

read_domain()
{
  read -rp 'Please input the domain name > ' domain </dev/tty
  if [[ "$domain" == *"."* ]]; then
    DOMAINS+=("$domain")
  else
    echo "The domain name entered is invalid"
    read_domain
    return
  fi
  read -rp 'Do you have any other domain (eg. www.fab-manager.com)? (y/N) ' confirm </dev/tty
  if [ "$confirm" == "y" ]; then
    read_domain
  fi
}

prepare_files()
{
  FABMANAGER_PATH=${1:-/apps/fabmanager}

  sudo mkdir -p "$FABMANAGER_PATH/config"
  sudo chown -R "$(whoami)" "$FABMANAGER_PATH"

  mkdir -p "$FABMANAGER_PATH/elasticsearch/config"

  # Fab-manager environment variables
  \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/env.example > "$FABMANAGER_PATH/config/env"

  # nginx configuration
  if [ "$NGINX" != "n" ]; then
    mkdir -p "$FABMANAGER_PATH/config/nginx"

    \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/nginx_with_ssl.conf.example > "$FABMANAGER_PATH/config/nginx/fabmanager.conf.ssl"
    \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/nginx.conf.example > "$FABMANAGER_PATH/config/nginx/fabmanager.conf"
  fi

  # let's encrypt configuration
  if [ "$LETSENCRYPT" != "n" ]; then
    mkdir -p "$FABMANAGER_PATH/letsencrypt/etc/config"
    mkdir -p "$FABMANAGER_PATH/letsencrypt/systemd"
    mkdir -p "$FABMANAGER_PATH/letsencrypt/etc/webrootauth"

    \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/webroot.ini.example > "$FABMANAGER_PATH/letsencrypt/etc/config/webroot.ini"
    # temp systemd files
    \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/letsencrypt.service > "$FABMANAGER_PATH/letsencrypt/systemd/letsencrypt.service"
    \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/letsencrypt.timer > "$FABMANAGER_PATH/letsencrypt/systemd/letsencrypt.timer"
  fi

  # ElasticSearch configuration files
  \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/elasticsearch.yml > "$FABMANAGER_PATH/elasticsearch/config/elasticsearch.yml"
  \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/log4j2.properties > "$FABMANAGER_PATH/elasticsearch/config/log4j2.properties"

  # docker-compose
  \curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/setup/docker-compose.yml > "$FABMANAGER_PATH/docker-compose.yml"
}

prepare_nginx()
{
  if [ "$NGINX" != "n" ]; then
    sed -i.bak "s/MAIN_DOMAIN/${MAIN_DOMAIN[0]}/g" "$FABMANAGER_PATH/config/nginx/fabmanager.conf"
    sed -i.bak "s/MAIN_DOMAIN/${MAIN_DOMAIN[0]}/g" "$FABMANAGER_PATH/config/nginx/fabmanager.conf.ssl"
    sed -i.bak "s/ANOTHER_DOMAIN_1/$OTHER_DOMAINS/g" "$FABMANAGER_PATH/config/nginx/fabmanager.conf.ssl"
    sed -i.bak "s/URL_WITH_PROTOCOL_HTTPS/https:\/\/${MAIN_DOMAIN[0]}/g" "$FABMANAGER_PATH/config/nginx/fabmanager.conf.ssl"
  else
    # if nginx is not installed, remove its associated block from docker-compose.yml
    awk '$1 == "nginx:"{t=1; next};t==1 && /:[[:blank:]]*$/{t=0};t != 1' docker-compose.yml > "$FABMANAGER_PATH/.awktmpfile" && mv "$FABMANAGER_PATH/.awktmpfile" "$FABMANAGER_PATH/docker-compose.yml"
  fi
}

function join_by { local IFS="$1"; shift; echo "$*"; }

prepare_letsencrypt()
{
  if [ "$LETSENCRYPT" != "n" ]; then
    if ! openssl dhparam -in "$FABMANAGER_PATH/config/nginx/ssl/dhparam.pem" -check; then
      mkdir -p "$FABMANAGER_PATH/config/nginx/ssl"
      printf "\n\nNow, we will generate a Diffie-Hellman (DH) 4096 bits encryption key, to encrypt connections. This will take a moment, please wait...\n"
      openssl dhparam -out "$FABMANAGER_PATH/config/nginx/ssl/dhparam.pem" 4096
    fi
    sed -i.bak "s/REPLACE_WITH_YOUR@EMAIL.COM/$EMAIL/g" "$FABMANAGER_PATH/letsencrypt/etc/config/webroot.ini"
    sed -i.bak "s/MAIN_DOMAIN, ANOTHER_DOMAIN_1/$(join_by , "${DOMAINS[@]}")/g" "$FABMANAGER_PATH/letsencrypt/etc/config/webroot.ini"
    echo "Now downloading and configuring the certificate signing bot..."
    docker pull certbot/certbot:latest
    sed -i.bak "s:/apps/fabmanager:$FABMANAGER_PATH:g" "$FABMANAGER_PATH/letsencrypt/systemd/letsencrypt.service"
    sudo cp "$FABMANAGER_PATH/letsencrypt/systemd/letsencrypt.service" /etc/systemd/system/letsencrypt.service
    sudo cp "$FABMANAGER_PATH/letsencrypt/systemd/letsencrypt.timer" /etc/systemd/system/letsencrypt.timer
    sudo systemctl daemon-reload
  fi
}

prepare_docker()
{
  if [ "$(docker ps | wc -l)" -gt 1 ]; then
    printf "\n\nIf you have previously interrupted the installer, it is recommended to stop any existing docker container before continuing.\n"
    echo "Here's a list of all existing containers:"
    docker ps -a
    read -rp "Force remove all containers? (y/N) " confirm </dev/tty
    if [ "$confirm" = "y" ]; then
      # shellcheck disable=SC2046
      docker rm -f $(docker ps -q)
    fi
  fi

  cd "$FABMANAGER_PATH" && docker-compose pull
}

get_md_anchor()
{
  local md_file="$1"
  local anchor="$2"

  local section lastline
  section=$(echo "$md_file" | sed -n "/<a name=\"$anchor/,/<a name=/p" | tail -n +2)
  lastline=$(echo "$section" | tail -n -1)
  if [[ "$lastline" == *"<a name="* ]]; then
    section=$(echo "$section" | head -n -1)
  fi
  echo "$section"
}

configure_env_file()
{
  printf "\n\nWe will now configure the environment variables.\n"
  echo "This allows you to customize Fab-manager's appearance and behavior."
  read -rp "Proceed? (Y/n) " confirm </dev/tty
  if [ "$confirm" = "n" ]; then return; fi

  local doc variables secret
  doc=$(\curl -sSL https://raw.githubusercontent.com/sleede/fab-manager/master/doc/environment.md)
  variables=(STRIPE_API_KEY STRIPE_PUBLISHABLE_KEY STRIPE_CURRENCY INVOICE_PREFIX FABLAB_WITHOUT_PLANS FABLAB_WITHOUT_SPACES FABLAB_WITHOUT_ONLINE_PAYMENT FABLAB_WITHOUT_INVOICES FABLAB_WITHOUT_WALLET \
   PHONE_REQUIRED BOOK_SLOT_AT_SAME_TIME USER_CONFIRMATION_NEEDED_TO_SIGN_IN EVENTS_IN_CALENDAR SLOT_DURATION DEFAULT_MAIL_FROM DELIVERY_METHOD DEFAULT_HOST DEFAULT_PROTOCOL SMTP_ADDRESS SMTP_PORT SMTP_USER_NAME SMTP_PASSWORD SMTP_AUTHENTICATION \
   SMTP_ENABLE_STARTTLS_AUTO SMTP_OPENSSL_VERIFY_MODE SMTP_TLS GA_ID RECAPTCHA_SITE_KEY RECAPTCHA_SECRET_KEY DISQUS_SHORTNAME TWITTER_NAME \
   FACEBOOK_APP_ID LOG_LEVEL ALLOWED_EXTENSIONS ALLOWED_MIME_TYPES MAX_IMAGE_SIZE MAX_CAO_SIZE MAX_IMPORT_SIZE DISK_SPACE_MB_ALERT FEATURE_TOUR_DISPLAY \
   SUPERADMIN_EMAIL APP_LOCALE RAILS_LOCALE MOMENT_LOCALE SUMMERNOTE_LOCALE ANGULAR_LOCALE MESSAGEFORMAT_LOCALE FULLCALENDAR_LOCALE ELASTICSEARCH_LANGUAGE_ANALYZER TIME_ZONE \
   WEEK_STARTING_DAY D3_DATE_FORMAT UIB_DATE_FORMAT EXCEL_DATE_FORMAT OPENLAB_APP_ID OPENLAB_APP_SECRET OPENLAB_DEFAULT)
  for variable in "${variables[@]}"; do
    local var_doc current
    var_doc=$(get_md_anchor "$doc" "$variable")
    current=$(grep "$variable=" "$FABMANAGER_PATH/config/env")
    printf "\n\n\n==== \e[4m%s\e[24m ====\n" "$variable"
    printf "**** \e[1mDocumentation:\e[21m ****\n"
    echo "$var_doc"
    printf "=======================\n- \e[1mCurrent value: %s\e[21m\n- New value? (leave empty to keep current value)\n" "$current"
    read -rp "  > " value </dev/tty
    echo "======================="
    if [ "$value" != "" ]; then
      sed -i.bak "s/$current/$variable=$value/g" "$FABMANAGER_PATH/config/env"
    fi
  done
  # we automatically generate the SECRET_KEY_BASE
  secret=$(cd "$FABMANAGER_PATH" && docker-compose run --rm fabmanager bundle exec rake secret)
  sed -i.bak "s/SECRET_KEY_BASE=/SECRET_KEY_BASE=$secret/g" "$FABMANAGER_PATH/config/env"
}

read_password()
{
  local password confirmation
  >&2 echo "Please input a password for this administrator's account"
  read -rsp " > " password </dev/tty
  >&2 printf "\nConfirm the password\n"
  read -rsp " > " confirmation </dev/tty
  if [ "$password" != "$confirmation" ]; then
    >&2 printf "\nError: passwords mismatch\n"
    password=$(read_password)
  fi
  echo "$password"
}

setup_assets_and_databases()
{
  printf "\n\nWe will now setup the database.\n"
  read -rp "Continue? (Y/n) " confirm </dev/tty
  if [ "$confirm" = "n" ]; then return; fi

  cd "$FABMANAGER_PATH" && docker-compose run --rm fabmanager bundle exec rake db:create # create the database
  cd "$FABMANAGER_PATH" && docker-compose run --rm fabmanager bundle exec rake db:migrate # run all the migrations
  # prompt default admin email/password
  printf "\n\nWe will now create the default administrator of Fab-manager.\n"
  read_email
  PASSWORD=$(read_password)
  cd "$FABMANAGER_PATH" && docker-compose run --rm -e ADMIN_EMAIL="$EMAIL" -e ADMIN_PASSWORD="$PASSWORD" fabmanager bundle exec rake db:seed # seed the database

  # now build the assets
  cd "$FABMANAGER_PATH" && docker-compose run --rm fabmanager bundle exec rake assets:precompile

  # and prepare elasticsearch
  cd "$FABMANAGER_PATH" && docker-compose run --rm fabmanager bundle exec rake fablab:es:build_stats
}

stop()
{
  cd "$FABMANAGER_PATH" && docker-compose down
}

start()
{
  cd "$FABMANAGER_PATH" && docker-compose up -d
}

enable_ssl()
{
  if [ "$LETSENCRYPT" != "n" ]; then
    # generate certificate
    sudo systemctl start letsencrypt.service
    # serve http content over ssl
    mv "$FABMANAGER_PATH/config/nginx/fabmanager.conf" "$FABMANAGER_PATH/config/nginx/fabmanager.conf.nossl"
    mv "$FABMANAGER_PATH/config/nginx/fabmanager.conf.ssl" "$FABMANAGER_PATH/config/nginx/fabmanager.conf"
    stop
    start
    sudo systemctl enable letsencrypt.timer
    sudo systemctl start letsencrypt.timer
  fi
}

final_message()
{
  printf "\n\e[92m[ ✔ ] Installation process in now complete.\e[39m \n\n"
  echo "#========================#"
  echo -e "#\e[5m  🥳 Congratulations! 🎉  \e[25m#"
  echo "#========================#"
  printf "\n\n"
  echo -e "Please \e[1mkeep track of the logs\e[21m produced by this script and check that everything is running correctly."
  echo "You can call for the community assistance on https://forum.fab-manager.com"
  echo -e "We wish you a pleasant use of \e[31mFab-manager\e[0m"
}

function trap_ctrlc()
{
  echo "Ctrl^C, exiting..."
  exit 2
}

setup()
{
  trap "trap_ctrlc" 2 # SIGINT
  welcome_message
  system_requirements
  config
  prepare_files "$@"
  prepare_nginx
  prepare_letsencrypt
  prepare_docker
  configure_env_file
  setup_assets_and_databases
  start
  enable_ssl
  final_message
}

setup "$@"
