FROM php:8.3-apache-bookworm

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN chmod +x /usr/bin/composer

# System dependencies and PHP extensions
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg-dev \
        libpng-dev \
        libpq-dev \
        libwebp-dev \
        libzip-dev \
        git \
        cron \
        supervisor \
        curl \
        unzip \
        groff \
        less \
        python3 \
        python3-pip \
        nano \
        awscli

# Configure and install PHP extensions
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg=/usr \
        --with-webp \
    && docker-php-ext-install -j "$(nproc)" \
        gd \
        opcache \
        pdo_mysql \
        pdo_pgsql \
        zip

# Enable Apache modules
RUN set -eux; \
    if command -v a2enmod; then \
        a2enmod expires rewrite; \
    fi

# Set environment variables
ENV DRUPAL_VERSION=10.2.5
ENV COMPOSER_ALLOW_SUPERUSER=1

# Setup directories and logs
RUN mkdir -p /var/www/html/themes /var/www/html/backups /opt/backup-scripts && \
    touch /var/log/cron.log /var/log/apache2/access.log /var/log/apache2/error.log /var/log/test-cron-log && \
    chmod 0644 /var/log/test-cron-log && \
    chown -R www-data:www-data /var/www/html

# Copy configuration files
COPY files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY files/test.sh /opt/backup-scripts/test.sh
COPY files/backup-cron-job /etc/cron.d/backup-cron-job
COPY files/s3-backup-script.sh /opt/backup-scripts/s3-backup-script.sh

# Set permissions
RUN chmod 0644 /etc/cron.d/backup-cron-job && \
    chmod 0644 /opt/backup-scripts/test.sh && \
    chmod 0644 /opt/backup-scripts/s3-backup-script.sh

# Install Drush
WORKDIR /var/www/html
RUN composer require drush/drush && \
    composer install && \
    ln -s /var/www/html/vendor/drush/drush/drush /usr/local/bin/drush

# Cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

CMD ["supervisord", "-n"]
