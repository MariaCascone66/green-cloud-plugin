#!/bin/bash

# Funzione per la creazione e gestione del virtual environment
function install_flask_dependencies {
    echo "Installing Flask and dependencies..."

    # Verifica se il venv esiste già, altrimenti lo crea
    if [[ ! -d "$VENV_DIR" ]]; then
        python3 -m venv "$VENV_DIR" || { echo "Failed to create virtual environment"; exit 1; }
    fi

    # Attiva il venv
    source "$VENV_DIR/bin/activate"

    # Installa le dipendenze dal requirements.txt
    if [[ -f "$CLOUDWATCHER_DIR/requirements.txt" ]]; then
        pip install --upgrade pip
        pip install -r "$CLOUDWATCHER_DIR/requirements.txt" || { echo "Failed to install dependencies"; exit 1; }
    else
        echo "requirements.txt not found!"
        exit 1
    fi
    
    echo "Dependencies installed successfully"

    # Disattiva il venv
    deactivate
}

# Funzione per copiare il file di servizio systemd
function copy_service_file {
    echo "Copying systemd service files..."
    sudo cp "$CLOUDWATCHER_DIR/systemd/cloudwatcher_dashboard.service" "$SYSTEMD_DIR/"
    sudo cp "$CLOUDWATCHER_DIR/systemd/cloudwatcher_tagger.service" "$SYSTEMD_DIR/"
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
}

# Funzione per assegnare ruoli all'utente admin
function assign_roles {
    echo "Assegnazione dei ruoli all'utente admin..."

    # Verifica se il ruolo admin è già assegnato
    if ! openstack role assignment list --user admin --system all --names | grep -q 'admin'; then
        echo "Assegnazione del ruolo 'admin' all'utente 'admin' sul sistema..."
        openstack role add --user admin --system all --role admin
    else
        echo "Il ruolo 'admin' è già assegnato all'utente 'admin'."
    fi
}

# Funzione per avviare il servizio CloudWatcher
function start_cloudwatcher_plugin {
    echo "Starting CloudWatcher services..."
    sudo systemctl start cloudwatcher_dashboard.service || { echo "Failed to start dashboard"; exit 1; }
    sudo systemctl start cloudwatcher_tagger.service || { echo "Failed to start tagger"; exit 1; }
}

# Funzione per fermare il servizio CloudWatcher
function stop_cloudwatcher_plugin {
    echo "Stopping CloudWatcher services..."
    sudo systemctl stop cloudwatcher_dashboard.service
    sudo systemctl stop cloudwatcher_tagger.service
}

# Funzione per pulire i file CloudWatcher
function clean_cloudwatcher_plugin {
    echo "Cleaning CloudWatcher service files..."
    sudo rm -f "$SYSTEMD_DIR/cloudwatcher_dashboard.service"
    sudo rm -f "$SYSTEMD_DIR/cloudwatcher_tagger.service"
}

# Verifica se il servizio è abilitato
if is_service_enabled cloudwatcher; then

    if [[ "$1" == "stack" && "$2" == "install" ]]; then
        echo_summary "CloudWatcher: Installing dependencies"
        install_flask_dependencies
        copy_service_file

    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        echo_summary "CloudWatcher: Configuring service"
        assign_roles

    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "CloudWatcher: Starting service"
        start_cloudwatcher_plugin
    fi

    if [[ "$1" == "unstack" ]]; then
        echo_summary "CloudWatcher: Stopping service"
        stop_cloudwatcher_plugin
    fi

    if [[ "$1" == "clean" ]]; then
        echo_summary "CloudWatcher: Cleaning service"
        clean_cloudwatcher_plugin
    fi
fi
