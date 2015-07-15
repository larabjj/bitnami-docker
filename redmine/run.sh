#!/bin/bash
set -e

REDMINE_SESSION_TOKEN=${REDMINE_SESSION_TOKEN:-rXvLWjqs4tqKNjdHgkqTLjqfj4wWkLCr}

# automatically fetch database parameters from bitnami/mariadb
DATABASE_HOST=${DATABASE_HOST:-${MARIADB_PORT_3306_TCP_ADDR}}
DATABASE_NAME=${DATABASE_NAME:-${MARIADB_ENV_MARIADB_DATABASE}}
DATABASE_USER=${DATABASE_USER:-${MARIADB_ENV_MARIADB_USER}}
DATABASE_PASSWORD=${DATABASE_PASSWORD:-${MARIADB_ENV_MARIADB_PASSWORD}}


if [[ -z ${DATABASE_HOST} || -z ${DATABASE_NAME} || \
      -z ${DATABASE_USER} || -z ${DATABASE_PASSWORD} ]]; then
  echo "ERROR: "
  echo "  Please configure the database connection."
  echo "  Cannot continue without a database. Aborting..."
  exit 1
fi

# s3 / google cloud storage configuration (uploads)
S3_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID:-}
S3_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY:-}
S3_BUCKET=${S3_BUCKET:-}
S3_ENDPOINT=${S3_ENDPOINT:-storage.googleapis.com}

if [[ -z ${S3_ACCESS_KEY_ID} || -z ${S3_SECRET_ACCESS_KEY} ||
      -z ${S3_BUCKET} || -z ${S3_ENDPOINT} ]]; then
  echo "ERROR: "
  echo "  Please configure a s3 / google cloud storage bucket."
  echo "  Cannot continue. Aborting..."
  exit 1
fi

# configure redmine database connection settings
cat > config/database.yml <<EOF
production:
  adapter: mysql2
  database: ${DATABASE_NAME}
  host: ${DATABASE_HOST}
  username: ${DATABASE_USER}
  password: "${DATABASE_PASSWORD}"
  encoding: utf8
EOF

# configure cloud storage settings
cat > config/s3.yml <<EOF
production:
  access_key_id: ${S3_ACCESS_KEY_ID}
  secret_access_key: ${S3_SECRET_ACCESS_KEY}
  bucket: ${S3_BUCKET}
  endpoint: ${S3_ENDPOINT}
EOF

# create the secret session token file
cat > config/initializers/secret_token.rb <<EOF
RedmineApp::Application.config.secret_key_base = '${REDMINE_SESSION_TOKEN}'
EOF

echo "Running database migrations..."
bundle exec rake db:migrate RAILS_ENV=production

echo "Starting redmine server..."
exec bundle exec rails server -b 0.0.0.0 -p 3000 -e production
