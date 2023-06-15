#!/bin/bash

# Variables d'erreur et de succès
ERROR_PREFIX="Erreur :"
SUCCESS_PREFIX="Succès :"

# Variables et Paramètres
resource_group_name="$1"
vnet_name="$2"
vnet_prefix="10.2.0.0/26"
subnet_name="$3"
subnet_prefix="10.2.0.0/26"
location="$4"

# Fonction d'affichage des messages d'étape
print_step() {
  echo "Étape : $1"
}

# Fonction d'affichage des messages de succès
print_success() {
  echo "$SUCCESS_PREFIX $1"
}

# Fonction de nettoyage en cas d'erreur
cleanup() {
  print_step "Nettoyage en cours..."
  
  if [ -n "$subnet_name" ]; then
    delete_subnet
  fi
  
  if [ -n "$vnet_name" ]; then
    delete_virtual_network
  fi
  
  print_success "Nettoyage terminé."
}

# Fonction de vérification des paramètres
check_parameters() {
  if [ -z "$resource_group_name" ] || [ -z "$vnet_name" ] || [ -z "$subnet_name" ] || [ -z "$location" ]; then
    echo "$ERROR_PREFIX Tous les paramètres attendus doivent être spécifiés."
    echo "Veuillez entrer les paramètres attendus en suivant ce format : $0 <nom_du_groupe_de_ressources> <nom_du_réseau_virtuel> <nom_du_sous-réseau> <localisation>"
    exit 1
  fi
}

# Fonction de vérification du groupe de ressources existant
check_resource_group() {
  print_step "Vérification de l'existence du groupe de ressources en cours..."
  
  if ! az group exists --name "$resource_group_name" >/dev/null; then
    echo "$ERROR_PREFIX Le groupe de ressources '$resource_group_name' n'existe pas."
    read -p "Voulez-vous créer le groupe de ressources '$resource_group_name' ? (y/n) " choice
    if [[ $choice =~ ^[Yy]$ ]]; then
      az group create --name "$resource_group_name" --location "$location" >/dev/null
      print_success "Le groupe de ressources '$resource_group_name' a été créé avec succès."
    else
      echo "$ERROR_PREFIX Arrêt du script. Aucune ressource n'a été créée."
      exit 1
    fi
  else
    print_success "Le groupe de ressources '$resource_group_name' existe déjà."
  fi
}

# Fonction de création du réseau virtuel
create_virtual_network() {
  print_step "Création du réseau virtuel en cours..."
  
  if ! az network vnet show --resource-group "$resource_group_name" --name "$vnet_name" >/dev/null 2>&1; then
    az network vnet create --resource-group "$resource_group_name" --name "$vnet_name" --address-prefix "$vnet_prefix" >/dev/null
    print_success "Le réseau virtuel '$vnet_name' a été créé avec succès."
    echo "   Nom du réseau virtuel : $vnet_name"
    echo "   Adresse IP du réseau virtuel : $vnet_prefix"
  else
    echo "$ERROR_PREFIX Le réseau virtuel '$vnet_name' existe déjà."
    cleanup
    exit 1
  fi
}

# Fonction de création du sous-réseau
create_subnet() {
  print_step "Création du sous-réseau en cours..."
  
  if ! az network vnet subnet show --resource-group "$resource_group_name" --vnet-name "$vnet_name" --name "$subnet_name" >/dev/null 2>&1; then
    az network vnet subnet create --resource-group "$resource_group_name" --vnet-name "$vnet_name" --name "$subnet_name" --address-prefix "$subnet_prefix" >/dev/null
    print_success "Le sous-réseau '$subnet_name' a été créé avec succès."
    echo "   Nom du sous-réseau : $subnet_name"
    echo "   Adresse IP du sous-réseau : $subnet_prefix"
    echo "   Localisation : $location"
  else
    echo "$ERROR_PREFIX Le sous-réseau '$subnet_name' existe déjà."
    cleanup
    exit 1
  fi
}

# Fonction de suppression du réseau virtuel
delete_virtual_network() {
  print_step "Suppression du réseau virtuel en cours..."
  az network vnet delete --resource-group "$resource_group_name" --name "$vnet_name" >/dev/null
  print_success "Le réseau virtuel '$vnet_name' a été supprimé avec succès."
}

# Fonction de suppression du sous-réseau
delete_subnet() {
  print_step "Suppression du sous-réseau en cours..."
  az network vnet subnet delete --resource-group "$resource_group_name" --vnet-name "$vnet_name" --name "$subnet_name" >/dev/null
  print_success "Le sous-réseau '$subnet_name' a été supprimé avec succès."
}

# Vérifier si tous les paramètres sont spécifiés
check_parameters

# Vérifier si la localisation est spécifiée
if ! az account show >/dev/null 2>&1; then
  echo "$ERROR_PREFIX Vous devez vous connecter à Azure CLI."
  exit 1
fi

# Début de l'exécution du script
print_step "Début de l'exécution du script."

# Test Rollback
# this_is_an_invalid_command

check_resource_group
create_virtual_network
create_subnet

if [ $? -eq 0 ]; then
  read -p "Voulez-vous conserver le réseau virtuel et le sous-réseau créés ? (y/n) " choice
  if [[ $choice =~ ^[Nn]$ ]]; then
    cleanup
  fi

  print_success "Le script s'est exécuté avec succès."
  exit 0
else
  cleanup
  echo "$ERROR_PREFIX Une erreur s'est produite. Les ressources créées ont été supprimées."
  exit 1
fi
