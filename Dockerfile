FROM npeca75/php:81
ENV DEBIAN_FRONTEND=noninteractive \
 DB_HOST=169.254.255.254 \
 DB_PORT=3306 \
 DB_DATABASE=radius \
 DB_USERNAME=radIus \
 DB_PASSWORD=RadiuS \
 RADIUS_SECRET=SomesecreT \
 HTPASSWD=admin:81pDi9Six5bIY \
 TZ="Europe/Belgrade"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
    apache2 \
    ca-certificates \
    cron \
    freeradius \
    freeradius-mysql \
    freeradius-utils \
    libapache2-mod-php \
    libmysqlclient-dev \
    locales \
    mc \
    mysql-client \
    net-tools \
    php-mail \
    php-dev \
    php-mail-mime \
    php-db \
    tini \
    tzdata \
    unzip \
    wget \
    && apt-get clean && apt-get autoclean && apt-get autoremove --purge

# PHP Pear DB library install
RUN update-locale \
    && update-ca-certificates -f \
    && mkdir -p /tmp/pear/cache \
    && wget http://pear.php.net/go-pear.phar \
    && php go-pear.phar \
    && rm go-pear.phar \
    && pear channel-update pear.php.net \
    && pear install -a -f DB \
    && pear install -a -f Mail \
    && pear install -a -f Mail_Mime

# Create directories
RUN rm -fr /var/www \
    && mkdir -p /var/www \
    && wget -qO- https://github.com/lirantal/daloradius/archive/refs/tags/1.3.tar.gz | tar -xzf - -C /var/www  \
    && mv /var/www/daloradius-1.3 /var/www/html \
    && rm -fr /tmp/*

COPY startup.sh /startup.sh

VOLUME data
EXPOSE 80/tcp 1812/udp 1813/udp

MAINTAINER peca.nesovanovic@sattrakt.com
ENTRYPOINT ["tini", "--"]
CMD ["/startup.sh"]
