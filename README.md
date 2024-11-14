---
page_type: sample
languages:
- javascript
- typescript
- nodejs
products:
- azure
- azure-cosmos-db
- azure-functions
- azure-signalr
- azure-storage
- vs-code
urlFragment: azure-functions-and-signalr-javascript
name: "Enable real-time updates in a web application using Azure Functions and SignalR Service"
description: Change a JavaScript web app update mechanism from polling to real-time push-based architecture with SignalR Service, Azure Cosmos DB and Azure Functions. Use Vue.js and JavaScript to use SignalR using Visual Studio Code.
---

# SignalR with Azure Functions triggers and bindings

This repository is the companion to the following training module:

* [Enable automatic updates in a web application using Azure Functions and SignalR Service](https://learn.microsoft.com/training/modules/automatic-update-of-a-webapp-using-azure-functions-and-signalr/)

This solution displays fake stock prices as they update: 

* [Start](./start): uses polling every minute
* [Solution](./solution): uses database change notifications and SignalR

## Overview

This project demonstrates how to implement real-time updates in a web application using Azure Functions and SignalR Service. The client-side code is built with Vue.js, and the server-side functions are triggered by Cosmos DB change notifications and a SignalR binding to push data to clients.

### Requirements

- **Node.js**: Version 20.x or above
- **Azure CLI**: To deploy resources to Azure
- **Azure Functions Core Tools**: For local testing of Azure Functions
- **GitHub CLI (optional)**: To automate actions with GitHub
- **Vue CLI (for local development)**

## Setup Resources

The Azure resources are created from bash scripts in the `setup-resources` folder. This includes creating:
- **Azure Cosmos DB**: To store stock data and trigger change events
- **Azure SignalR**: To enable real-time client-server communication
- **Azure Storage**: For managing Azure Function triggers and bindings

## Ports

* Client: 3000 (default port used with Webpack for local client builds)
* Server: 7071 (default port for Azure Functions)

## Starting Project without SignalR

The starting project updates stock prices in a Cosmos DB database every minute with an Azure Function app and a timer trigger. The client polls for all the stock prices.

## Ending Project with SignalR Integration

The final solution upgrades the project to use SignalR for real-time updates. This setup pushes changes from Cosmos DB to clients via SignalR, removing the need for polling.

## Important Configuration Details

### Setting Up `BACKEND_URL`

Ensure the `BACKEND_URL` environment variable is configured correctly in GitHub Actions to point to the deployed backend endpoint. This is essential for the client to connect to the SignalR API.

- **GitHub Actions**: Set `BACKEND_URL` as a repository secret or environment variable to match the deployed Azure Function endpoint.
- **Local Development**: For local builds, ensure `.env` contains the correct `BACKEND_URL`.

### Workflow for Deploying to Azure

The project uses two GitHub Actions workflows to deploy the frontend and backend:

1. **Backend Deployment (Azure Functions)**:
   - Example GitHub Action workflow file:
   
     ```yaml
     name: Server - Build and deploy Node.js project to Azure Function App
     
     on:
       push:
         branches:
           - main
       workflow_dispatch:
     
     jobs:
       build:
         runs-on: ubuntu-latest
         steps:
           - uses: actions/checkout@v3
           - uses: actions/setup-node@v3
             with:
               node-version: '20.x'
           - run: |
               npm install
               npm run build --if-present
           - run: zip -r release.zip .
           - uses: actions/upload-artifact@v3
             with:
               name: node-app
               path: release.zip
     
       deploy:
         runs-on: ubuntu-latest
         needs: build
         steps:
           - uses: actions/download-artifact@v3
             with:
               name: node-app
           - uses: azure/login@v1
             with:
               client-id: ${{ secrets.AZURE_CLIENT_ID }}
               tenant-id: ${{ secrets.AZURE_TENANT_ID }}
               subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
           - uses: Azure/functions-action@v1
             with:
               app-name: 'your-function-app-name'
               package: './release.zip'
     ```

2. **Frontend Deployment (Azure Static Web Apps)**:
   - **Azure Static Web Apps** require the `Standard` plan type to use [bring your own backend](https://learn.microsoft.com/azure/static-web-apps/functions-bring-your-own) (BYOB).
   - Example GitHub Action workflow for Static Web App with environment variable injection for `BACKEND_URL`:
   
     ```yaml
     name: Azure Static Web Apps CI/CD

     on:
       push:
         branches:
           - main
       pull_request:
         branches:
           - main

     jobs:
       build_and_deploy_job:
         runs-on: ubuntu-latest
         steps:
           - uses: actions/checkout@v3
           - name: Build And Deploy
             uses: Azure/static-web-apps-deploy@v1
             with:
               azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
               app_location: "/solution/client"
               api_location: "/solution/api" # if you have an API folder
               output_location: "dist"
             env:
               BACKEND_URL: ${{ secrets.BACKEND_URL }}
     ```

### Configuring CORS

In the Azure Function App, configure CORS settings:
1. **Enable CORS** for the frontend's URL in the Azure Functions settings.
2. Check **Enable Access-Control-Allow-Credentials** to allow secure cross-origin requests.

### SignalR Negotiation and Connection Setup

Ensure the SignalR client code connects to the correct endpoint:
```javascript
const connection = new signalR.HubConnectionBuilder()
  .withUrl(`${BACKEND_URL}/api`)
  .configureLogging(signalR.LogLevel.Information)
  .build();
