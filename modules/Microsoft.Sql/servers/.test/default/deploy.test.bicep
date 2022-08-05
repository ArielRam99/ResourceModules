targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for a testing purposes')
@maxLength(90)
param resourceGroupName string = '${serviceShort}-ms.sql-servers-rg'

@description('Optional. The location to deploy resources to')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints')
param serviceShort string = 'sqlpar'

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
    managedIdentityName: 'dep-<<namePrefix>>-msi-${serviceShort}-01'
    virtualNetworkName: 'adp-<<namePrefix>>-vnet-${serviceShort}-01'
    deploymentScriptName: 'adp-<<namePrefix>>-ds-kv-${serviceShort}-01'
    keyVaultName: 'adp-<<namePrefix>>-kv-${serviceShort}-01'
    passwordSecretName: 'adminPassword'
    location: location
  }
}

resource keyVaultReference 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: 'adp-<<namePrefix>>-kv-${serviceShort}-01'
  scope: resourceGroup
}

// Diagnostics
// ===========
module diagnosticDependencies '../../../../.shared/dependencyConstructs/diagnostic.dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-diagDep'
  params: {
    storageAccountName: 'dep<<namePrefix>>azsa${serviceShort}01'
    logAnalyticsWorkspaceName: 'dep-<<namePrefix>>-law-${serviceShort}-01'
    eventHubNamespaceEventHubName: 'dep-<<namePrefix>>-evh-${serviceShort}-01'
    eventHubNamespaceName: 'dep-<<namePrefix>>-evhns-${serviceShort}-01'
    location: location
  }
}

// ============== //
// Test Execution //
// ============== //

module testDeployment '../../deploy.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name)}-test-servers-${serviceShort}'
  params: {
    name: '<<namePrefix>>-${serviceShort}-001'
    lock: 'CanNotDelete'
    administratorLogin: 'adminUserName'
    administratorLoginPassword: keyVaultReference.getSecret(resourceGroupResources.outputs.secretName)
    location: location
    minimalTlsVersion: '1.2'
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Reader'
        principalIds: [
          resourceGroupResources.outputs.managedIdentityPrincipalId
        ]
      }
    ]
    vulnerabilityAssessmentsObj: {
      name: 'default'
      emailSubscriptionAdmins: true
      recurringScansIsEnabled: true
      recurringScansEmails: [
        'test1@contoso.com'
        'test2@contoso.com'
      ]
      vulnerabilityAssessmentsStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
    }
    databases: [
      {
        name: '<<namePrefix>>-${serviceShort}db-001'
        collation: 'SQL_Latin1_General_CP1_CI_AS'
        skuTier: 'BusinessCritical'
        skuName: 'BC_Gen5'
        skuCapacity: 12
        skuFamily: 'Gen5'
        maxSizeBytes: 34359738368
        licenseType: 'LicenseIncluded'
        diagnosticLogsRetentionInDays: 7
        diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
        diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
        diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
        diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
      }
    ]
    firewallRules: [
      {
        name: 'AllowAllWindowsAzureIps'
        endIpAddress: '0.0.0.0'
        startIpAddress: '0.0.0.0'
      }
    ]
    securityAlertPolicies: [
      {
        name: 'Default'
        state: 'Enabled'
        emailAccountAdmins: true
      }
    ]
    systemAssignedIdentity: true
    userAssignedIdentities: {
      '${resourceGroupResources.outputs.managedIdentitResourceId}': {}
    }
    privateEndpoints: [
      {
        subnetResourceId: resourceGroupResources.outputs.privateEndpointSubnetResourceId
        service: 'sqlServer'
      }
    ]
  }
}