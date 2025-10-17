package com.example;

import com.azure.core.credential.TokenCredential;
import com.azure.identity.ClientSecretCredential;
import com.azure.identity.ClientSecretCredentialBuilder;
import com.azure.resourcemanager.AzureResourceManager;
import com.azure.resourcemanager.appservice.models.DeploymentSlot;
import com.azure.resourcemanager.resources.ResourceManager;
import com.azure.core.management.profile.AzureProfile;
import com.azure.core.management.AzureEnvironment;

public class SetSlotImage {
  public static void main(String[] args) {
    String clientId       = mustGetEnv("AZURE_CLIENT_ID");
    String clientSecret   = mustGetEnv("AZURE_CLIENT_SECRET");
    String tenantId       = mustGetEnv("AZURE_TENANT_ID");
    String subscriptionId = mustGetEnv("AZURE_SUBSCRIPTION_ID");

    String resourceGroup  = mustGetEnv("RESOURCE_GROUP");
    String appName        = mustGetEnv("APP_NAME");   // e.g., wa-harness-1
    String slotName       = mustGetEnv("SLOT_NAME");  // e.g., staging

    String dockerNamespace   = mustGetEnv("DOCKER_NAMESPACE");
    String dockerRepository  = mustGetEnv("DOCKER_REPOSITORY");
    String dockerTag         = mustGetEnv("DOCKER_TAG");
    String image = dockerNamespace + "/" + dockerRepository + ":" + dockerTag;

    // Optional registry creds (for private images)
    String registryUrl  = System.getenv("DOCKER_REGISTRY_URL");   // e.g., https://index.docker.io or https://<acr>.azurecr.io
    String registryUser = System.getenv("DOCKER_REGISTRY_USER");
    String registryPass = System.getenv("DOCKER_REGISTRY_PASS");

    try {
      TokenCredential cred = clientSecretCredential(clientId, clientSecret, tenantId);
      AzureProfile profile = new AzureProfile(tenantId, subscriptionId, AzureEnvironment.AZURE);

      AzureResourceManager azure = AzureResourceManager
          .authenticate(cred, profile)
          .withSubscription(subscriptionId);

      // Get the deployment slot
      DeploymentSlot slot = azure.webApps()
          .getByResourceGroup(resourceGroup, appName)
          .deploymentSlots()
          .getByName(slotName);

      if (slot == null) {
        throw new RuntimeException("Deployment slot not found: " + appName + " / " + slotName);
      }

      System.out.printf("Setting image %s on %s (slot %s)%n", image, appName, slotName);

      // Public Docker Hub image:
      if (isNullOrEmpty(registryUrl) && isNullOrEmpty(registryUser)) {
        slot.update()
            .withPublicDockerHubImage(image)
            .apply();
      } else {
        // Private registry (Docker Hub private or ACR)
        if (isNullOrEmpty(registryUrl)) {
          // default Docker Hub URL if not provided
          registryUrl = "https://index.docker.io";
        }
        if (isNullOrEmpty(registryUser) || isNullOrEmpty(registryPass)) {
          throw new IllegalArgumentException("Private registry requires DOCKER_REGISTRY_USER and DOCKER_REGISTRY_PASS");
        }
        slot.update()
            .withPrivateRegistryImage(image, registryUrl)
            .withCredentials(registryUser, registryPass)
            .apply();
      }

      // Optionally restart the slot to force pull
      slot.restart();

      System.out.println("Done.");
    } catch (Exception ex) {
      ex.printStackTrace();
      System.exit(1);
    }
  }

  private static ClientSecretCredential clientSecretCredential(String clientId, String clientSecret, String tenantId) {
    return new ClientSecretCredentialBuilder()
        .clientId(clientId)
        .clientSecret(clientSecret)
        .tenantId(tenantId)
        .build();
  }

  private static String mustGetEnv(String name) {
    String v = System.getenv(name);
    if (v == null || v.isEmpty()) throw new IllegalArgumentException("Missing env var: " + name);
    return v;
  }

  private static boolean isNullOrEmpty(String s) { return s == null || s.isEmpty(); }
}
