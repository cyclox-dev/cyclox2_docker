# Stage 1: Composer dependency installation
FROM composer:2 as vendor
WORKDIR /app
COPY ./cyclox2res_sys/composer.json ./composer.json
RUN composer install --no-dev --optimize-autoloader --no-scripts

# Stage 2: Final application image
FROM centos/php-73-centos7:latest
USER 0

# Copy application code
COPY ./cyclox2res_sys /var/www/html/ajocc_xsys

# Copy installed dependencies from the vendor stage
COPY --from=vendor /app/vendor /var/www/html/ajocc_xsys/vendor

# Set correct permissions
RUN chown -R apache:apache /var/www/html/ajocc_xsys

CMD httpd -D FOREGROUND
