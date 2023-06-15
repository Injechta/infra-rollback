#!/bin/bash

# Variables ensorcelées
resource_group_name="Gregory_E"
key_vault_name="coffremaudit"
certificate_name="certifmaudit"
secret_name="secretmaudit"
private_key_name="clefmaudite"

# Fonction message d'erreur, quitter le script avec un code de sortie
handle_error() {
  echo "Erreur : $1"
  rollback
  exit 1
}

# Fonction pour vérifier si une commande est disponible
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Vérifier si l'utilisateur est connecté à Azure et proposer de se connecter si nécessaire
check_azure_login() {
  echo "Vérification de la connexion Azure..."
  if ! az account show >/dev/null 2>&1; then
    echo "Vous n'êtes pas connecté à Azure. Voulez-vous vous connecter maintenant? (o/n)"
    read -r response
    if [[ "$response" =~ ^[Oo]$ ]]; then
      az login
      if [ $? -ne 0 ]; then
        handle_error "La connexion à Azure a échoué."
      fi
    else
      perform_rollback
    fi
  fi
}

# Fonction pour vérifier si un groupe de ressources existe déjà
check_existing_resource_group() {
  echo "Vérification de l'existence du groupe de ressources..."
  if az group show --name $resource_group_name >/dev/null 2>&1; then
    handle_error "Le groupe de ressources $resource_group_name existe déjà."
  fi
}

# Fonction pour vérifier si un Key Vault existe déjà
check_existing_key_vault() {
  echo "Vérification de l'existence du Key Vault..."
  if az keyvault show --name $key_vault_name --resource-group $resource_group_name >/dev/null 2>&1; then
    handle_error "Le Key Vault $key_vault_name existe déjà."
  fi
}

# Fonction de rollback en cas d'erreur
perform_rollback() {
  echo "Une erreur s'est produite. Exécution du rollback..."
  rollback
  echo "Rollback terminé. Le script a été annulé."
  exit 1
}

# Fonction pour créer un Azure Key Vault sur Azure
create_key_vault() {
  echo "Création d'un Azure Key Vault..."
  az group create --name $resource_group_name --location westeurope || handle_error "La création du groupe de ressources a échoué."

  az keyvault create --resource-group $resource_group_name --name $key_vault_name --sku standard || handle_error "La création d'un Azure Key Vault a échoué."
}

# Fonction pour créer un certificat SSL dans Azure Key Vault
create_ssl_certificate() {
  echo "Création du certificat SSL dans Azure Key Vault..."
  az keyvault certificate create --vault-name $key_vault_name --name $certificate_name --policy "$(az keyvault certificate get-default-policy)" || handle_error "La création du certificat SSL a échoué."
}

# Fonction pour créer une clé privée dans Azure Key Vault
create_private_key() {
  echo "Création de la clé privée dans Azure Key Vault..."
  az keyvault key create --vault-name $key_vault_name --name $private_key_name --size 2048 --kty RSA || handle_error "La création de la clé privée a échoué."
}

# Fonction pour créer un secret dans Azure Key Vault
create_secret() {
  echo "Création du secret dans Azure Key Vault..."
  az keyvault secret set --vault-name $key_vault_name --name $secret_name --value "ValeurDuSecret" || handle_error "La création du secret a échoué."
}

# Fonction pour supprimer un secret dans Azure Key Vault
delete_keyvault_secret() {
  local secret_name=$1
  echo "Suppression du secret dans Azure Key Vault..."
  az keyvault secret delete --vault-name $key_vault_name --name $secret_name >/dev/null 2>&1
}

# Fonction pour supprimer une clé privée dans Azure Key Vault
delete_keyvault_key() {
  local key_name=$1
  echo "Suppression de la clé privée dans Azure Key Vault..."
  az keyvault key delete --vault-name $key_vault_name --name $key_name >/dev/null 2>&1
}

# Fonction pour supprimer un certificat dans Azure Key Vault
delete_keyvault_certificate() {
  local certificate_name=$1
  echo "Suppression du certificat dans Azure Key Vault..."
  az keyvault certificate delete --vault-name $key_vault_name --name $certificate_name >/dev/null 2>&1
}

# Fonction pour supprimer le Key Vault
delete_key_vault() {
  echo "Suppression du Key Vault..."
  az keyvault delete --name $key_vault_name --resource-group $resource_group_name >/dev/null 2>&1
}

# Fonction pour afficher un message prévenant du téléchargement des fichiers
show_download_message() {
  echo "Téléchargement des fichiers en cours..."
}

# Fonction pour télécharger un fichier à partir d'Azure Key Vault
download_keyvault_file() {
  local file_name=$1
  local output_file=$2

  az keyvault secret download --vault-name $key_vault_name --name $file_name --file "$output_file" >/dev/null 2>&1 || handle_error "Erreur lors du téléchargement du fichier $file_name."
}

# Fonction pour créer un répertoire de téléchargement s'il n'existe pas
create_download_directory() {
  local download_dir=$1

  mkdir -p "$download_dir"
}

# Fonction pour exécuter le rollback en cas d'erreur
rollback() {
  delete_keyvault_secret $secret_name
  delete_keyvault_key $private_key_name
  delete_keyvault_certificate $certificate_name
  delete_key_vault
}

# Fonction principale pour exécuter les étapes du script
run_script() {
  check_azure_login
  check_existing_resource_group
  check_existing_key_vault

  create_key_vault
  create_private_key
  create_ssl_certificate
  create_secret

  # Déterminer le répertoire de téléchargement basé sur le nom d'utilisateur exécutant le script
  download_dir="/home/$LOGNAME/telechargements"

  # Afficher un message prévenant du téléchargement des fichiers
  show_download_message

  # Créer le répertoire de téléchargement s'il n'existe pas
  create_download_directory "$download_dir"

  # Télécharger les fichiers dans le répertoire de téléchargement
  download_keyvault_file $secret_name "$download_dir/$secret_name"
  download_keyvault_file $private_key_name "$download_dir/$private_key_name"
  download_keyvault_file $certificate_name "$download_dir/$certificate_name"

  # Vérifier si les fichiers ont été téléchargés avec succès
  if [ $? -ne 0 ]; then
    handle_error "Erreur lors du téléchargement des fichiers."
  fi

  echo "Les fichiers ont été téléchargés avec succès dans le répertoire : $download_dir"
  echo "Le Key Vault, la clé privée, le certificat SSL et le secret ont été créés avec succès."
}

# Exécution du script
run_script
