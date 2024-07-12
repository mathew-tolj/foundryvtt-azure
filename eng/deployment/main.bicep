targetScope = 'subscription'

param location string = 'australiaeast'
param resourceGroupName string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}
