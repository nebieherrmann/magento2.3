FROM php:7.2-fpm

MAINTAINER "Magento"

ENV PHP_EXTRA_CONFIGURE_ARGS="--enable-fpm --with-fpm-user=magento2 --with-fpm-group=magento2"

RUN apt-get update 
RUN apt-get install apt-utils 
RUN apt-get install sudo 
RUN apt-get install wget 
RUN apt-get install unzip 
RUN apt-get install cron 
RUN apt-get install curl 
RUN apt-get install libmcrypt-dev 
RUN apt-get install libicu-dev 
RUN apt-get install libxml2-dev libxslt1-dev 
RUN apt-get install libfreetype6-dev 
RUN apt-get install libjpeg62-turbo-dev 
RUN apt-get install libpng12-dev 
RUN apt-get install git 
RUN apt-get install vim 
RUN apt-get install openssh-server 
RUN apt-get install supervisor 
RUN apt-get install mysql-client 
RUN apt-get install ocaml 
RUN apt-get install expect 
RUN curl -L https://github.com/bcpierce00/unison/archive/2.48.4.tar.gz | tar zxv -C /tmp && \
             cd /tmp/unison-2.48.4 && \
             sed -i -e 's/GLIBC_SUPPORT_INOTIFY 0/GLIBC_SUPPORT_INOTIFY 1/' src/fsmonitor/linux/inotify_stubs.c && \
             make && \
             cp src/unison src/unison-fsmonitor /usr/local/bin && \
             cd /root && rm -rf /tmp/unison-2.48.4 
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ 
RUN docker-php-ext-configure hash --with-mhash 
RUN docker-php-ext-install -j$(nproc) mcrypt intl xsl gd zip pdo_mysql opcache soap bcmath json iconv 
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer 
RUN pecl install xdebug && docker-php-ext-enable xdebug 
RUN echo "xdebug.remote_enable=1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 
RUN echo "xdebug.remote_port=9000" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 
RUN echo "xdebug.remote_connect_back=0" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 
RUN echo "xdebug.remote_host=127.0.0.1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 
RUN echo "xdebug.idekey=PHPSTORM" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 
RUN echo "xdebug.max_nesting_level=1000" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 
RUN chmod 666 /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 
RUN mkdir /var/run/sshd 
RUN apt-get clean && apt-get update && apt-get install -y nodejs 
RUN ln -s /usr/bin/nodejs /usr/bin/node 
RUN apt-get install -y npm 
RUN npm update -g npm && npm install -g grunt-cli && npm install -g gulp 
RUN echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config 
RUN apt-get install -y apache2 
RUN a2enmod rewrite 
RUN a2enmod proxy 
RUN a2enmod proxy_fcgi 
RUN rm -f /etc/apache2/sites-enabled/000-default.conf 
RUN useradd -m -d /home/magento2 -s /bin/bash magento2 && adduser magento2 sudo 
RUN echo "magento2 ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 
RUN touch /etc/sudoers.d/privacy 
RUN echo "Defaults        lecture = never" >> /etc/sudoers.d/privacy 
RUN mkdir /home/magento2/magento2 && mkdir /var/www/magento2 
RUN mkdir /home/magento2/state 
RUN curl -sS https://accounts.magento.cloud/cli/installer -o /home/magento2/installer 
RUN rm -r /usr/local/etc/php-fpm.d/* 
RUN sed -i 's/www-data/magento2/g' /etc/apache2/envvars

# PHP config
ADD conf/php.ini /usr/local/etc/php

# SSH config
COPY conf/sshd_config /etc/ssh/sshd_config
RUN chown magento2:magento2 /etc/ssh/ssh_config

# supervisord config
ADD conf/supervisord.conf /etc/supervisord.conf

# php-fpm config
ADD conf/php-fpm-magento2.conf /usr/local/etc/php-fpm.d/php-fpm-magento2.conf

# apache config
ADD conf/apache-default.conf /etc/apache2/sites-enabled/apache-default.conf

# unison script
ADD conf/.unison/magento2.prf /home/magento2/.unison/magento2.prf

ADD conf/unison.sh /usr/local/bin/unison.sh
ADD conf/entrypoint.sh /usr/local/bin/entrypoint.sh
ADD conf/check-unison.sh /usr/local/bin/check-unison.sh
RUN chmod +x /usr/local/bin/unison.sh && chmod +x /usr/local/bin/entrypoint.sh
RUN  chmod +x /usr/local/bin/check-unison.sh

ENV PATH $PATH:/home/magento2/scripts/:/home/magento2/.magento-cloud/bin
ENV PATH $PATH:/var/www/magento2/bin

ENV USE_SHARED_WEBROOT 1
ENV SHARED_CODE_PATH /var/www/magento2
ENV WEBROOT_PATH /var/www/magento2
ENV MAGENTO_ENABLE_SYNC_MARKER 0

RUN mkdir /windows \
 && cd /windows \
 && curl -L -o unison-windows.zip https://www.irif.fr/~vouillon/unison/unison%202.48.3.zip \
 && unzip unison-windows.zip \
 && rm unison-windows.zip \
 && mv 'unison 2.48.3 text.exe' unison.exe \
 && rm 'unison 2.48.3 GTK.exe' \
 && chown -R magento2:magento2 .

RUN mkdir /mac-osx \
 && cd /mac-osx \
 && curl -L -o unison-mac-osx.zip http://unison-binaries.inria.fr/files/Unison-OS-X-2.48.15.zip \
 && unzip unison-mac-osx.zip \
 && rm unison-mac-osx.zip \
 && chown -R magento2:magento2 .

# Initial scripts
COPY scripts/ /home/magento2/scripts/
RUN sed -i 's/^/;/' /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini 
RUN cd /home/magento2/scripts && composer install && chmod +x /home/magento2/scripts/m2init 
RUN sed -i 's/^;;*//' /usr/local/etc/php/conf.d/docker-php-ext-xdebug.in

RUN chown -R magento2:magento2 /home/magento2 && \
    chown -R magento2:magento2 /var/www/magento2 && \
    chmod 755 /home/magento2/scripts/bin/magento-cloud-login

# Delete user password to connect with ssh with empty password
RUN passwd magento2 -d

EXPOSE 80 22 5000 44100
WORKDIR /home/magento2

USER root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
