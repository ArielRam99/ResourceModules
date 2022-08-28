targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //
@description('Optional. The name of the resource group to deploy for a testing purposes')
@maxLength(90)
param resourceGroupName string = 'ms.cache.redis-${serviceShort}-rg'

@description('Optional. The location to deploy resources to')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment .Should be kept short to not run into resource-name length-constraints')
param serviceShort string = 'crdef'

// =========== //
// Deployments //
// =========== //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module resourceGroupResources 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-paramNested'
  params: {
    virtualNetworkName: 'dep-<<namePrefix>>-vnet-${serviceShort}'
  }
}

// ============== //
// Test Execution //
// ============== //

module testDeployment '../../deploy.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name)}-test-${serviceShort}'
  params: {
    name: '<<namePrefix>>${serviceShort}001'
    capacity: 2
    diagnosticLogCategoriesToEnable: [
      'ApplicationGatewayAccessLog'
      'ApplicationGatewayFirewallLog'
    ]
    diagnosticMetricsToEnable: [
      'AllMetrics'
    ]
    diagnosticSettingsName: 'redisdiagnostics'
    enableNonSslPort: true
    lock: 'CanNotDelete'
    minimumTlsVersion: '1.2'
    privateEndpoints: [
      {
        service: 'redisCache'
        subnetResourceId: resourceGroupResources.outputs.subnetResourceId
      }
    ]
    publicNetworkAccess: 'Enabled'
    redisVersion: '6'
    shardCount: 1
    skuName: 'Premium'
    systemAssignedIdentity: true
    tags: {
      resourceType: 'Redis Cache'
    }
  }
}