FROM wordpress:6.4.1-php8.0-apache

# WP-CLIをインストール
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && php wp-cli.phar --info \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp \
    && wp --info

# Xdebugのインストール
RUN pecl install xdebug-3.2.1 && docker-php-ext-enable xdebug

# Xdebugの設定
RUN { \
        echo 'xdebug.remote_enable=1'; \
        echo 'xdebug.remote_autostart=1'; \
        echo 'xdebug.remote_host=host.docker.internal'; \
        echo 'xdebug.remote_port=9003'; \
    } >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
