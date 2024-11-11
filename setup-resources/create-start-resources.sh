#!/bin/bash

set -e

printf "Param 1: $1\n"

LOCATION="canadacentral"
printf "Location: $LOCATION\n"

# Check if user is logged into Azure CLI
if ! az account show &> /dev/null
then
  printf "You are not logged into Azure CLI. Please log in with 'az login' and try again.\n"
  exit 1
fi
printf "User logged in\n"

NODE_ENV_FILE="./.env"

# Get user name
USER_NAME=$(az account show --query 'user.name' -o tsv)
# Capture name before `@` in user.name
USER_NAME=${USER_NAME%%@*}
printf "User name: $USER_NAME\n"

# Get the default subscription if not provided as a parameter
SUBSCRIPTION_NAME=$1
if [ -z "$SUBSCRIPTION_NAME" ]; then
  SUBSCRIPTION_NAME=$(az account show --query 'id' -o tsv)
fi
printf "Using subscription: $SUBSCRIPTION_NAME\n"

# Set the resource group name if not provided as a parameter
RANDOM_STRING=$(openssl rand -hex 5)
RESOURCE_GROUP_NAME="$USER_NAME-signalr-$RANDOM_STRING"
printf "Resource group name: $RESOURCE_GROUP_NAME\n"

# Create a resource group
az group create \
  --subscription "$SUBSCRIPTION_NAME" \
  --name "$RESOURCE_GROUP_NAME" \
  --location $LOCATION
printf "Resource group created: $RESOURCE_GROUP_NAME\n"

# Set default resource group
az configure --defaults group="$RESOURCE_GROUP_NAME"
printf "Using resource group $RESOURCE_GROUP_NAME\n"

export STORAGE_ACCOUNT_NAME=signalr$(openssl rand -hex 5)
export COSMOSDB_NAME=signalr-cosmos-$(openssl rand -hex 5)

printf "Subscription Name: $SUBSCRIPTION_NAME\n"
printf "Resource Group Name: $RESOURCE_GROUP_NAME\n"
printf "Storage Account Name: $STORAGE_ACCOUNT_NAME\n"
printf "CosmosDB Name: $COSMOSDB_NAME\n"

printf "Creating Storage Account\n"
az storage account create \
  --subscription "$SUBSCRIPTION_NAME" \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --kind StorageV2 \
  --sku Standard_LRS
printf "Storage account created: $STORAGE_ACCOUNT_NAME\n"

printf "Creating CosmosDB Account\n"
az cosmosdb create  \
  --subscription "$SUBSCRIPTION_NAME" \
  --name $COSMOSDB_NAME \
  --resource-group $RESOURCE_GROUP_NAME
printf "CosmosDB account created: $COSMOSDB_NAME\n"

printf "Get storage connection string\n"
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --query "connectionString" -o tsv)
printf "Storage connection string: $STORAGE_CONNECTION_STRING\n"

printf "Get account name\n"
COSMOSDB_ACCOUNT_NAME=$(az cosmosdb list \
  --subscription "$SUBSCRIPTION_NAME" \
  --resource-group $RESOURCE_GROUP_NAME \
  --query [0].name -o tsv)
printf "CosmosDB account name: $COSMOSDB_ACCOUNT_NAME\n"

printf "Get CosmosDB connection string\n"
COSMOSDB_CONNECTION_STRING=$(az cosmosdb keys list --type connection-strings \
  --name $COSMOSDB_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --subscription "$SUBSCRIPTION_NAME" \
  --query "connectionStrings[?description=='Primary SQL Connection String'].connectionString" -o tsv)
printf "CosmosDB connection string: $COSMOSDB_CONNECTION_STRING\n"

printf "\n\nReplace <STORAGE_CONNECTION_STRING> with:\n$STORAGE_CONNECTION_STRING\n\nReplace <COSMOSDB_CONNECTION_STRING> with:\n$COSMOSDB_CONNECTION_STRING\n"

# Create a .env file with the connection strings and keys
cat >> $NODE_ENV_FILE <<EOF
