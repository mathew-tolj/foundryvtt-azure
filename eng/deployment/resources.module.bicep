@allowed([
  'minimum'
  'recommended'
])
param containerAppConfiguration string = 'recommended'

param containerAppName string

param containerAppsEnvironmentName string

@secure()
param foundryAdminKey string

param foundryMajorVersion int = 12

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
  standard: {
    kind: 'StorageV2'
    sku: 'Standard_LRS'
  }
  premium: {
    kind: 'FileStorage'
    sku: 'Premium_LRS'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountConfigurationMap[storageAccountConfiguration].sku
  }
  kind: storageAccountConfigurationMap[storageAccountConfiguration].kind
  properties: {
    minimumTlsVersion: 'TLS1_2'
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

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppsEnvironmentName
  location: location
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

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
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
              name: 'FOUNDRY_GID'
              value: 'root'
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
              name: 'FOUNDRY_UID'
              value: 'root'
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
          name: 'foundryvtt-data'
          storageName: 'foundryvtt-v${foundryMajorVersion}-data'
          storageType: 'AzureFile'
        }
      ]
    }
  }
}
