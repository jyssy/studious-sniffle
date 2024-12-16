# https://www.drupal.org/docs/system-requirements/php-requirements
FROM php:8.3-apache-bookworm

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Verify and set permissions
RUN composer --version \
    && mkdir -p /var/www/.composer \
    && chown -R www-data:www-data /var/www/.composer

# install the PHP extensions we need
RUN set -eux; \
    \
    if command -v a2enmod; then \
        a2enmod expires rewrite; \
    fi; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    RUN apt-get install -y --no-install-recommends \
            libfreetype6-dev \
            libjpeg-dev \
            libpng-dev \
            libpq-dev \
            libwebp-dev \
            libzip-dev \
            git \
        && docker-php-ext-configure gd \
            --with-freetype \
            --with-jpeg=/usr \
            --with-webp \
        && docker-php-ext-install -j "$(nproc)" \
            gd \
            opcache \
            pdo_mysql \
            pdo_pgsql \
            zip

    RUN apt-mark auto '.*' > /dev/null \
        && apt-mark manual $savedAptMark \
        && ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
            | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
            | sort -u \
            | xargs -r dpkg-query -S \
            | cut -d: -f1 \
            | sort -u \
            | xargs -rt apt-mark manual \
        && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
        && rm -rf /var/lib/apt/lists/*


# [Previous apache settings remain the same]

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

ENV DRUPAL_VERSION 10.2.5
ENV COMPOSER_ALLOW_SUPERUSER 1

# Install Drush and create necessary directories in one layer
RUN composer require drush/drush \
    && composer install \
    && ln -s /var/www/html/vendor/drush/drush/drush /usr/local/bin/drush \
    && mkdir -p /var/www/html/themes /var/www/html/backups \
    && chown -R www-data:www-data /var/www/html/themes /var/www/html/backups

# cron and supervisor setup
RUN apt-get update && apt-get install -y \
    cron \
    supervisor \
    curl \
    unzip \
    groff \
    less \
    python3 \
    python3-pip \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Setup directories and files
RUN mkdir /opt/backup-scripts/ \
    && touch /var/log/cron.log /var/log/apache2/access.log /var/log/apache2/error.log /var/log/test-cron-log \
    && chmod 0644 /var/log/test-cron-log

COPY files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY files/test.sh /opt/backup-scripts/test.sh
COPY files/backup-cron-job /etc/cron.d/backup-cron-job
COPY files/s3-backup-script /opt/backup-scripts/s3-backup-script.sh

RUN chmod +x /opt/backup-scripts/backup.sh \
    && chmod 0644 /etc/cron.d/backup-cron-job \
    && chmod 0644  /opt/backup-scripts/test.sh \
    && chmod 0644 /opt/backup-scripts/s3-backup-script.sh


# AWS CLI installation and configuration
#

RUN apt-get update && apt-get install -y \
    awscli \
    && rm -rf /var/lib/apt/lists/*

CMD ["supervisord", "-n"]
