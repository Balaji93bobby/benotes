FROM php:8.1-fpm-alpine

LABEL mantainer="github.com/fr0tt"
LABEL description="Benotes"

ENV user application

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


RUN apk --no-cache update && apk --no-cache add \
    git \
    curl \
    curl-dev \
    zlib-dev \
    freetype-dev \
    libpng-dev \
    jpeg-dev \
    libjpeg-turbo \
    libjpeg-turbo-dev \
    libwebp-dev \
    libxml2-dev \
    libmcrypt-dev \
    libpq \
    postgresql-dev \
    postgresql-client \
    mysql-client \
    sqlite \
    zip \
    unzip \
    libzip-dev \
    libmcrypt-dev \
    openssl \
    nginx \
    supervisor \
    busybox-suid \
    bash \
    su-exec \
    chromium

# use bash instead of ash
RUN sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd 


RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp

# https://github.com/mlocati/docker-php-extension-installer#supported-php-extensions
RUN docker-php-ext-install \
    pdo_mysql \
    mysqli \
    pgsql \
    pdo_pgsql \
    opcache \
    exif \
    pcntl \
    bcmath \
    gd \
    sockets \
    pcntl \
    zip

# install composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN addgroup -S --gid 1000 $user && adduser -S --uid 1000 -G $user $user && adduser $user www-data

# cron
COPY ./docker/crontab /etc/crontabs/application

# configure supervisor
RUN mkdir -p /etc/supervisor.d/
COPY ./docker/supervisord.ini /etc/supervisor.d/supervisord.ini

COPY ./docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh


# configure PHP
RUN mkdir -p /run/php/ && touch /run/php/php8.1-fpm.pid

COPY ./docker/php-fpm.conf /etc/php81/php-fpm.conf
COPY ./docker/php.ini /etc/php81/php.ini

# configure nginx
COPY ./docker/nginx.conf /etc/nginx/
COPY ./docker/nginx-laravel.conf /etc/nginx/modules/

RUN mkdir -p /run/nginx/ && touch /run/nginx/nginx.pid

RUN ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log


WORKDIR /var/www

# will be overriden by bind mount - if used
COPY . .

# storage needs to be owned not only by group but also user www-data because of bind mounts
# however it doesn't magically solves the bind mount permission issue
RUN chown -R $user:$user /var/www && \
    chown -R www-data:www-data storage && chmod -R 775 storage && \
    chown -R www-data:www-data bootstrap/cache && chmod -R 775 bootstrap/cache


USER $user

RUN ln -snf ../storage/app/public/ public/storage

ARG USE_COMPOSER=true
RUN if [ "$USE_COMPOSER" = "true" ] ; \
    then \
    composer install --prefer-dist --no-interaction --no-progress ; \
    fi
RUN php artisan jwt:secret -n
RUN php artisan key:generate
RUN php artisan migrate:fresh --seed


USER root


ARG INSTALL_NODE
RUN if [ "$INSTALL_NODE" = "true" ] ; \
    then \
    apk --no-cache add nodejs npm ; \
    fi

EXPOSE 80
CMD ["/entrypoint.sh"]
