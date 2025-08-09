targetScope = 'subscription'

@allowed([
  'minimum'
  'recommended'
])
param containerAppConfiguration string = 'recommended'

param containerAppName string

param containerAppsEnvironmentName string

@secure()
param foundryAdminKey string

param foundryMajorVersion int = 13

@secure()
param foundryPassword string

@secure()
param foundryUserName string

param location string = 'australiaeast'

param resourceGroupName string

@allowed([
  'standard'
  'premium'
])
param storageAccountConfiguration string = 'standard'

param storageAccountName string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  location: location
  name: resourceGroupName
}

module resources './resources.module.bicep' = {
  name: 'resourcesModule'
  params: {
    containerAppConfiguration: containerAppConfiguration
    containerAppName: containerAppName
    containerAppsEnvironmentName: containerAppsEnvironmentName
    foundryAdminKey: foundryAdminKey
    foundryMajorVersion: foundryMajorVersion
    foundryPassword: foundryPassword
    foundryUserName: foundryUserName
    location: location
    storageAccountConfiguration: storageAccountConfiguration
    storageAccountName: storageAccountName
  }
  scope: resourceGroup
}
