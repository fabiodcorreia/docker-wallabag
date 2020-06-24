#!/usr/bin/with-contenv bash

SYMFONY_ENV=prod
LOCK="/config/first_run.lock"

APP_DIR="$WALLABAG_PATH/app"
BIN_DIR="$WALLABAG_PATH/bin"
CONF_PARAMETERS="/config/www/parameters.yml"
CONF_CONFIG_PROD="/config/www/config_prod.yml"
CKSUM_PARAMETERS="/config/parameters.sum"
CKSUM_CONFIG_PROD="/config/config_prod.sum"

# ENV_NAME, ENV_VAL, PROP_NAME, REQUIRED, STRING
function check_env {
  if [[ "$2" != "" ]]; then
    echo "****** found $1 ******"
    if [[ "$5" == 1 ]]; then
      sed -i "s#$3:.*#$3: '$2'#g" $CONF_PARAMETERS
    else
      sed -i "s#$3:.*#$3: $2#g" $CONF_PARAMETERS
    fi
  elif [[ "$4" == 1 ]]; then
    echo "###### $1: is not set and required! ######"
    exit 1
  fi
}

if [ ! -f "$LOCK" ]; then
  echo "**** start first run operations ****"

  mkdir -p /config/www/images

  echo "***** delete base /config/www/index.php *****"
  rm -fr /config/www/index.php

  echo "***** move and link parameters.yml to /config/www *****"
  mv "$APP_DIR/config/parameters.yml" $CONF_PARAMETERS
  ln -s $CONF_PARAMETERS "$APP_DIR/config/parameters.yml"

  echo "***** move and link config_prod.yml to /config/www *****"
  mv "$APP_DIR/config/config_prod.yml" $CONF_CONFIG_PROD
  ln -s $CONF_CONFIG_PROD "$APP_DIR/config/config_prod.yml"

  echo "***** set app/config/config_prod.yml log to console *****"
  sed -i "s#path:.*#path: \"php://stderr\"#" $CONF_CONFIG_PROD

  echo "***** disable access log *****"
  sed -i 's/access_log \/dev\/stdout;/#access_log \/dev\/stdout;/g' /config/nginx/nginx.conf;
  sed -i 's/#access_log off;/access_log off;/g' /config/nginx/nginx.conf;

  echo "***** enable php fpm worker log *****"
  echo "catch_workers_output=yes" >> /config/php/www2.conf

  if [ -z "$SESSION_PASSWORD" ]; then
    echo "***** creating session secret *****"
    SESSION_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1)
  fi

  echo "***** collecting and setting ENVs configuration *****"
  check_env "SESSION_PASSWORD" "$SESSION_PASSWORD" "secret" 1 1
  check_env "DATABASE_HOST" "$DATABASE_HOST" "database_host" 1 1
  check_env "DATABASE_PORT" "$DATABASE_PORT" "database_port" 0 0
  check_env "DATABASE_NAME" "$DATABASE_NAME" "database_name" 1 1
  check_env "DATABASE_USER" "$DATABASE_USER" "database_user" 1 1
  check_env "DATABASE_PASS" "$DATABASE_PASS" "database_password" 1 1
  check_env "DOMAIN_NAME" "$DOMAIN_NAME" "domain_name" 1 1
  check_env "EMAIL_HOST" "$EMAIL_HOST" "mailer_host" 1 1
  check_env "EMAIL_USER" "$EMAIL_USER" "mailer_user" 1 1
  check_env "EMAIL_PASS" "$EMAIL_PASS" "mailer_password" 1 1
  check_env "EMAIL_FROM" "$EMAIL_FROM" "from_email" 0 1
  check_env "LOCALE" "$LOCALE" "locale" 0 1
  check_env "TWOFA_ENABLE" "$TWOFA_ENABLE" "twofactor_auth" 0 0
  check_env "TWOFA_SENDER" "$TWOFA_SENDER" "twofactor_sender" 0 0
  check_env "REGISTRATION_ENABLE" "$REGISTRATION_ENABLE" "fosuser_registration" 0 0
  check_env "REGISTRATION_CONFIRM" "$REGISTRATION_CONFIRM" "fosuser_confirmation" 0 0
  check_env "RSS_LIMIT" "$RSS_LIMIT" "rss_limit" 0 0

  echo "***** clear cache *****"
  $BIN_DIR/console cache:clear --env=prod || exit 1

  sleep 5
  wait-for-it.sh -h "$DATABASE_HOST" -p "$DATABASE_PORT" -t 60 -- echo "DB is up. Time to execute installation commands."

  echo "***** wallabag install *****"
  $BIN_DIR/console wallabag:install --env=prod -n || exit 1

  echo "***** set parameters.yml checksum *****"
  cksum $CONF_PARAMETERS | awk '/.{10}/ {print $1}' > $CKSUM_PARAMETERS

  echo "***** set config_prod.yml checksum *****"
  cksum $CONF_CONFIG_PROD | awk '/.{10}/ {print $1}' > $CKSUM_CONFIG_PROD

  touch $LOCK
  echo "**** finish first run operations ****"
else
  echo "**** skip first run operations ****"

  echo "**** link parameters.yml to /config/www ****"
  rm -fr "$APP_DIR/config/parameters.yml"
  ln -s $CONF_PARAMETERS "$APP_DIR/config/parameters.yml"

  echo "**** link config_prod.yml to /config/www ****"
  rm -fr "$APP_DIR/config/config_prod.yml"
  ln -s $CONF_CONFIG_PROD "$APP_DIR/config/config_prod.yml"

  echo "**** clear cache ****"
  $BIN_DIR/console cache:clear --env=prod || exit 1
  sleep 10
fi

CURRENT_CKSUM_PARAMETERS=`cksum $CONF_PARAMETERS | awk '/.{10}/ {print $1}'`
STORED_CKSUM_PARAMETERS=`cat $CKSUM_PARAMETERS`

CURRENT_CKSUM_CONFIG_PROD=`cksum $CONF_CONFIG_PROD | awk '/.{10}/ {print $1}'`
STORED_CKSUM_CONFIG_PROD=`cat $CKSUM_CONFIG_PROD`

if [[ "$CURRENT_CKSUM_PARAMETERS" != "$STORED_CKSUM_PARAMETERS" || "$CURRENT_CKSUM_CONFIG_PROD" != "$STORED_CKSUM_CONFIG_PROD" ]]
then
  echo "**** configuration changed ****"

  echo "**** refresh wallabag installation ****"
  SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist

  echo "***** update parameters.yml checksum *****"
  cksum $CONF_PARAMETERS | awk '/.{10}/ {print $1}' > $CKSUM_PARAMETERS

  echo "***** update config_prod.yml checksum *****"
  cksum $CONF_CONFIG_PROD | awk '/.{10}/ {print $1}' > $CKSUM_CONFIG_PROD
fi

if [ ! -f /var/www/wallabag/web/assets/images ]; then
  ln -s /config/www/images "$WALLABAG_PATH/web/assets/images"
fi

echo "**** database migrations ****"
$BIN_DIR/console doctrine:migrations:migrate --env=prod --no-interaction

echo "**** clean duplicates ****"
$BIN_DIR/console wallabag:clean-duplicates --env=prod || exit 1

echo "**** chown /config and $WALLABAG_PATH ****"
chown -R abc:abc \
  /config \
  $WALLABAG_PATH
