#!/bin/bash

DALO_PATH=/var/www/html
RADIUS_PATH=/etc/freeradius/3.0
DALORADIUS_CNF="${DALO_PATH}/library/daloradius.conf.php"

echo "freeradius config"
if test -f "${RADIUS_PATH}/radiusd.conf"; then
    sed -i 's|dialect = "sqlite"|dialect = "mysql"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|driver = "rlm_sql_null"|driver = "rlm_sql_mysql"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|dialect = ${modules.sql.dialect}|dialect = "mysql"|' $RADIUS_PATH/mods-available/sqlcounter
    sed -i 's|ca_file = "/etc/ssl/certs/my_ca.crt"|#ca_file = "/etc/ssl/certs/my_ca.crt"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|ca_path = "/etc/ssl/certs/"|#ca_path = "/etc/ssl/certs/"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|cipher = "DHE-RSA-AES256-SHA:AES128-SHA"|#cipher = "DHE-RSA-AES256-SHA:AES128-SHA"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|certificate_file = "/etc/ssl/certs/private/client.crt"|#certificate_file = "/etc/ssl/certs/private/client.crt"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|private_key_file = "/etc/ssl/certs/private/client.key"|#private_key_file = "/etc/ssl/certs/private/client.key"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|tls_required = yes|tls_required = no|' $RADIUS_PATH/mods-available/sql
    sed -i 's|#\s*read_clients = yes|read_clients = yes|' $RADIUS_PATH/mods-available/sql
    ln -s $RADIUS_PATH/mods-available/sql $RADIUS_PATH/mods-enabled/sql
    ln -s $RADIUS_PATH/mods-available/sqlcounter $RADIUS_PATH/mods-enabled/sqlcounter
    ln -s $RADIUS_PATH/mods-available/sqlippool $RADIUS_PATH/mods-enabled/sqlippool
    sed -i 's|instantiate {|instantiate {\nsql|' $RADIUS_PATH/radiusd.conf
    sed -i 's|use_tunneled_reply = no|use_tunneled_reply = yes|' $RADIUS_PATH/mods-available/eap
    ln -s $RADIUS_PATH/sites-available/status $RADIUS_PATH/sites-enabled/status
    sed -i 's|^#\s*server = .*|server = "'$DB_HOST'"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|^#\s*port = .*|port = "'$DB_PORT'"|' $RADIUS_PATH/mods-available/sql
    sed -i '1,$s/radius_db.*/radius_db="'$DB_DATABASE'"/g' $RADIUS_PATH/mods-available/sql
    sed -i 's|^#\s*password = .*|password = "'$DB_PASSWORD'"|' $RADIUS_PATH/mods-available/sql 
    sed -i 's|^#\s*login = .*|login = "'$DB_USERNAME'"|' $RADIUS_PATH/mods-available/sql
    sed -i 's|testing123|'$RADIUS_SECRET'|' $RADIUS_PATH/mods-available/sql
else
    echo "ERROR: Config file missing !!!"
    exit;
fi

echo "daloRADIUS config"
if test -f "${DALORADIUS_CNF}.sample"; then
    cp "${DALORADIUS_CNF}.sample" $DALORADIUS_CNF
    sed -i "s/\$configValues\['CONFIG_DB_HOST'\] = .*;/\$configValues\['CONFIG_DB_HOST'\] = '$DB_HOST';/" $DALORADIUS_CNF
    sed -i "s/\$configValues\['CONFIG_DB_PORT'\] = .*;/\$configValues\['CONFIG_DB_PORT'\] = '$DB_PORT';/" $DALORADIUS_CNF
    sed -i "s/\$configValues\['CONFIG_DB_PASS'\] = .*;/\$configValues\['CONFIG_DB_PASS'\] = '$DB_PASSWORD';/" $DALORADIUS_CNF
    sed -i "s/\$configValues\['CONFIG_DB_USER'\] = .*;/\$configValues\['CONFIG_DB_USER'\] = '$DB_USERNAME';/" $DALORADIUS_CNF
    sed -i "s/\$configValues\['CONFIG_DB_NAME'\] = .*;/\$configValues\['CONFIG_DB_NAME'\] = '$DB_DATABASE';/" $DALORADIUS_CNF
    sed -i "s/\$configValues\['FREERADIUS_VERSION'\] = .*;/\$configValues\['FREERADIUS_VERSION'\] = '3';/" $DALORADIUS_CNF
    sed -i "s|\$configValues\['CONFIG_PATH_DALO_VARIABLE_DATA'\] = .*;|\$configValues\['CONFIG_PATH_DALO_VARIABLE_DATA'\] = '/var/www/html/var';|" $DALORADIUS_CNF
    sed -i "s/\$configValues\['CONFIG_MAINT_TEST_USER_RADIUSSERVER'\] = .*;/\$configValues\['CONFIG_MAINT_TEST_USER_RADIUSSERVER'\] = '127.0.0.1';/" $DALORADIUS_CNF
    sed -i "s/\$configValues\['CONFIG_MAINT_TEST_USER_RADIUSSECRET'\] = .*;/\$configValues\['CONFIG_MAINT_TEST_USER_RADIUSSECRET'\] = '${RADIUS_SECRET}';/" $DALORADIUS_CNF

    if [ -n "$MAIL_SMTPADDR" ]; then
        sed -i "s/\$configValues\['CONFIG_MAIL_SMTPADDR'\] = .*;/\$configValues\['CONFIG_MAIL_SMTPADDR'\] = '$MAIL_SMTPADDR';/" $DALORADIUS_CNF
    fi
    if [ -n "$MAIL_PORT" ]; then
        sed -i "s/\$configValues\['CONFIG_MAIL_SMTPPORT'\] = .*;/\$configValues\['CONFIG_MAIL_SMTPPORT'\] = '$MAIL_PORT';/" $DALORADIUS_CNF
    fi
    if [ -n "$MAIL_FROM" ]; then
        sed -i "s/\$configValues\['CONFIG_MAIL_SMTPFROM'\] = .*;/\$configValues\['CONFIG_MAIL_SMTPFROM'\] = '$MAIL_FROM';/" $DALORADIUS_CNF
    fi
    if [ -n "$MAIL_AUTH" ]; then
        sed -i "s/\$configValues\['CONFIG_MAIL_SMTPAUTH'\] = .*;/\$configValues\['CONFIG_MAIL_SMTPAUTH'\] = '$MAIL_AUTH';/" $DALORADIUS_CNF
    fi
else
    echo "ERROR: Config file missing !!!"
    exit;
fi

while ! mysqladmin ping -h"$DB_HOST" --silent; do
    echo "Waiting for mysql ($DB_HOST)..."
    sleep 20
done

RADIUS_LOCK=/data/radius_init_done
if test -f "$RADIUS_LOCK"; then
    echo "freeradius Database already initialized"
else
    mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" < $RADIUS_PATH/mods-config/sql/main/mysql/schema.sql
    mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" < $RADIUS_PATH/mods-config/sql/ippool/mysql/schema.sql
#    mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" \
#    -e "INSERT INTO nas (nasname,shortname,type,ports,secret,server,community,description) VALUES ('127.0.0.1/8','DOCKER NET','other',0,'$RADIUS_SECRET',NULL,'','')"
    if [[ "$?" -ne 0 ]]; then
        echo "ERROR: Could not initialize database on mysql ($DB_HOST)"
        exit;
    else
        echo "freeradius Database init complete"
        date > $RADIUS_LOCK
    fi
fi

DALO_LOCK=/data/dalo_init_done
if test -f "$DALO_LOCK"; then
    echo "dalo Database already initialized"
else
    mysql -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" < $DALO_PATH/contrib/db/mysql-daloradius.sql
    if [[ "$?" -ne 0 ]]; then
        echo "ERROR: Could not initialize database on mysql ($DB_HOST)"
        exit;
    else
        echo "dalo Database init complete"
        date > $DALO_LOCK
    fi
fi


# => .htaccess
cat << EOF > ${DALO_PATH}/.htaccess
AuthName "Authentication Base"
AuthType Basic
AuthUserFile .htpasswd
Require valid-user
EOF

echo $HTPASSWD > /etc/apache2/.htpasswd

# => Time Zone
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo $TZ > /etc/timezone

sed -i 's/AllowOverride\ None/AllowOverride\ All/g' /etc/apache2/apache2.conf
chown -R www-data:www-data /var/www/html
touch /tmp/daloradius.log
chown -R www-data:www-data /tmp/daloradius.log
mkdir -p /var/log/freeradius
touch /var/log/freeradius/radius.log

echo "apache2 freeradius" > /tmp/services
### => loop
while :
do
    ps -A > /tmp/ps
    SRV=$(cat /tmp/services|xargs)
    for s in $SRV; do
        if ! grep -q ${s} /tmp/ps; then tini -s service ${s} restart; fi
    done
sleep 10
done