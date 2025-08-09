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

@allowed([
  'standard'
  'premium'
])
param storageAccountConfiguration string = 'standard'

param storageAccountName string

var containerAppConfigurationMap = {
  minimum: {
    cpu: '1.0'
    memory: '2Gi'
  }
  recommended: {
    cpu: '2.0'
    memory: '4Gi'
  }
}

var storageAccountConfigurationMap = {
  premium: {
    kind: 'FileStorage'
    sku: 'Premium_LRS'
  }
  standard: {
    kind: 'StorageV2'
    sku: 'Standard_LRS'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  kind: storageAccountConfigurationMap[storageAccountConfiguration].kind
  location: location
  name: storageAccountName
  properties: {
    minimumTlsVersion: 'TLS1_2'
  }
  sku: {
    name: storageAccountConfigurationMap[storageAccountConfiguration].sku
  }
  resource fileService 'fileServices' = {
    name: 'default'
    resource share 'shares' = {
      name: 'foundryvtt-v${foundryMajorVersion}-data'
      properties: {
        enabledProtocols: 'SMB'
        shareQuota: 100
      }
    }
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  location: location
  name: containerAppsEnvironmentName
  properties: {}
  resource storage 'storages' = {
    name: 'foundryvtt-v${foundryMajorVersion}-data'
    properties: {
      azureFile: {
        accessMode: 'ReadWrite'
        accountKey: storageAccount.listKeys().keys[0].value
        accountName: storageAccountName
        shareName: 'foundryvtt-v${foundryMajorVersion}-data'
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  location: location
  name: containerAppName
  properties: {
    configuration: {
      ingress: {
        external: true
        targetPort: 30000
      }
      secrets: [
        {
          name: 'foundry-admin-key'
          value: foundryAdminKey
        }
        {
          name: 'foundry-password'
          value: foundryPassword
        }
        {
          name: 'foundry-username'
          value: foundryUserName
        }
      ]
    }
    managedEnvironmentId: containerAppsEnvironment.id
    template: {
      containers: [
        {
          env: [
            {
              name: 'FOUNDRY_ADMIN_KEY'
              secretRef: 'foundry-admin-key'
            }
            {
              name: 'FOUNDRY_COMPRESS_WEBSOCKET'
              value: 'true'
            }
            {
              name: 'FOUNDRY_MINIFY_STATIC_FILES'
              value: 'true'
            }
            {
              name: 'FOUNDRY_PASSWORD'
              secretRef: 'foundry-password'
            }
            {
              name: 'FOUNDRY_TELEMETRY'
              value: 'false'
            }
            {
              name: 'FOUNDRY_USERNAME'
              secretRef: 'foundry-username'
            }
          ]
          image: 'docker.io/felddy/foundryvtt:${foundryMajorVersion}'
          name: containerAppName
          resources: {
            cpu: json(containerAppConfigurationMap[containerAppConfiguration].cpu)
            memory: containerAppConfigurationMap[containerAppConfiguration].memory
          }
          volumeMounts: [
            {
              mountPath: '/data'
              volumeName: 'foundryvtt-data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
      volumes: [
        {
          mountOptions: 'gid=1000,uid=1000'
          name: 'foundryvtt-data'
          storageName: containerAppsEnvironment::storage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}
