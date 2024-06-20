#!/bin/bash

# Function to generate an 8-digit alphanumeric password
generate_password() {
  local password=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c8)
  echo $password
}

# Generate the password and store it in a variable
DB_PASSWORD=$(generate_password)

# Update and install necessary packages
sudo apt update
sudo apt upgrade -y
sudo apt install -y postgresql-15 postgresql-contrib-15 git curl ufw

# Function to set up PostgreSQL
setup_postgresql() {
  # Switch to the postgres user and set up the database and user
  sudo -i -u postgres bash << EOF
  # Create a new PostgreSQL user with a password
  psql -c "CREATE USER bs_pos_user WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"

  # Create a new PostgreSQL database
  psql -c "CREATE DATABASE black_sheep_pos;"

  # Grant all privileges on the database to the new user
  psql -c "GRANT ALL PRIVILEGES ON DATABASE black_sheep_pos TO bs_pos_user;"

  # Grant the necessary privileges on the public schema
  psql -c "GRANT ALL ON SCHEMA public TO bs_pos_user;"

  # Exit the postgres user
  exit
EOF

  # Modify the postgresql.conf file to allow remote connections
  sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/15/main/postgresql.conf

  # Modify the pg_hba.conf file to use md5 authentication and allow remote connections
  echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/15/main/pg_hba.conf

  # Restart PostgreSQL service to apply changes
  sudo systemctl restart postgresql
}

# Function to set up the server application
setup_server_app() {
  # Install Node.js and npm using nvm (Node Version Manager)
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
  export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  nvm install node
  nvm use node
  npm install

  # Set up environment variables
  echo "DB_USER=bs_pos_user" > .env
  echo "DB_PASSWORD=$DB_PASSWORD" >> .env
  echo "DB_NAME=black_sheep_pos" >> .env
  echo "DB_HOST=localhost" >> .env
  echo "DB_PORT=5432" >> .env
}

# Function to configure firewall and allow remote connections
setup_firewall() {
  # Allow SSH
  sudo ufw allow OpenSSH

  # Allow PostgreSQL
  sudo ufw allow 5432/tcp

  # Enable UFW
  sudo ufw --force enable
}

# Main function to run the setup
main() {
  setup_postgresql
  setup_server_app
  setup_firewall

  echo "PostgreSQL setup complete and accessible remotely."
  echo "Database Name: black_sheep_pos"
  echo "Database User: bs_pos_user"
  echo "Database Password: $DB_PASSWORD"
}

# Run the main function
main
