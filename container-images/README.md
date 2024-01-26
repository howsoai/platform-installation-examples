# Downloading Images for Airgap Installs and Scanning
- [Downloading Images for Airgap Installs and Scanning](#downloading-images-for-airgap-installs-and-scanning)
  - [Overview](#overview)
  - [Download Airgap Bundle](#download-airgap-bundle)
    - [Extracting the images](#extracting-the-images)
  - [Downloading from Container registry](#downloading-from-container-registry)
    - [Extracting the images](#extracting-the-images-1)
  - [Container registry](#container-registry)
    - [List all the images](#list-all-the-images)
    - [Pull the images](#pull-the-images)

## Overview 

The simplest approach for airgap helm installs is to Download the airgap bundle, and use the `kubect kots` command to push the images to a container registry.  Alternatively it is possible to access the container registry directly - and download the images yourself.

If you need to process the images in a pipeline, before running the install (i.e. to scan them), either approach is viable, it is possible to extract them from the bundle, by first pushing them to a registry.  Alternatively, if you capture the image names from the helm chart - you can access them from the registry directly. 


## Download Airgap Bundle

- Navigate to the Howso Customer Portal at [https://portal.howso.com/](https://portal.howso.com)
- In the top right drop-down, where your name appears, select 'Organizations', and select the appropriate value (usually your company name).
- Scroll down the organization page, and you'll see any licenses.  Airgap enabled licenses will have buttons to download the bundle and reset the password.  If you don't see an air-gapped license, contact your Howso representative.
- If this is your first time downloading an application bundle, or you've forgotten the password, select 'Reset Bundle Password' then copy the password and click OK.
- Select 'Air Gap Bundle' and enter the password to get to the Download Portal.
- In the 'Latest Howso Platform Airgap bundle' Section select 'Download air-gap bundle'
- Save the file (~ 1 Gig) via the browser, or copy the link and use wget or curl. 
- The [kots cli](https://kots.io/kots-cli/) can be used to push the images to a container registry.

### Extracting the images 

The airgap bundle format has changed, so it no longer directly contains the image tar.gz files.  Instead it splits the image layers, allowing images with shared layers to be combined.  Whilst this is efficient, it maeans extracting the images first requires using the `kots` cli to extract the images, push them to a registry - and then pull them back out again.  The following commands show how to do this.


```sh 
# Use appropriate registry host and credentials
kubectl kots admin-console push-images ~/2024.1.0.airgap registry-localhost:5000 --registry-username reguser --registry-password pw --namespace howso --skip-registry-check
```

If needed - you can list the images in the bundle with the following command. 
```sh
AIRGAP_ARCHIVE=~/2024.1.0.airgap # or wherever you saved the file
tar -xzOf "${AIRGAP_ARCHIVE}" ./airgap.yaml | yq e '.spec.savedImages[]' # The airgap.yaml file contains a list of the images in the bundle - if you don't have yq just remove that piped cmd
```


## Downloading from Container registry

Alternatively, you can access the container registry directly - and download the images yourself.

### Extracting the images 

The airgap bundle container the image layers, extracting them requires first using:
```sh
kubectl kots admin-console push-images ~/2024.1.0.airgap registry-localhost:5000 --registry-username reguser --registry-password pw --namespace howso --skip-registry-check
```

You can list the images in the bundle with the following command. 
```sh
AIRGAP_ARCHIVE=~/2024.1.0.airgap # or wherever you saved the file
tar -xzOf "${AIRGAP_ARCHIVE}" airgap.yaml | yq e '.spec.savedImages[]' # The airgap.yaml file contains a list of the images in the bundle - if you don't have yq just remove the piped cmd
```
> Note the image registry and namespace are in their original format.  For the public images - in the datastore/message-queue charts, you can pull them directly.

## Container registry 

Replicated hosted helm charts embed an customer's container secret in the chart, to simplify the installation process.  Extract your organization's container registry credentials from the Helm chart with the following one liner.  Make sure to have logged in first, as per the [prerequisites](../prereqs/README.md).
```
helm template oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --show-only templates/image-pull-secret.yaml 2> /dev/null | yq eval '.data.".dockerconfigjson"'  | base64 -d | jq . > /tmp/config.json
```

You can't directly `docker login` to the proxy registry - but you can, add the `auths` key to your `~/docker/config.json` or use the config directly with the DOCKER_CONFIG environment variable.
> Store it in a suitable location - tmp file used for demo purposes only.

### List all the images

Dealing just with the Howso Platform - you can template the chart and extract the images with something like the following.
```
# template the platform chart | grep for images | remove leading whitespace, image tag and trailing quotes 
helm template oci://registry.how.so/howso-platform/stable/howso-platform --values helm-basic/manifests/howso-platform.yaml  2> /dev/null | grep 'image: "' | sed 's/^[ \t]*//' | sed 's/image: "//' | sed 's/"$//'
```
> Note it is important that you run this from this repo, as the values file will alter the images to the correct format.

> A similar approach can be used for the other charts, though the images are also in public registies. 

### Pull the images

DOCKER_CONFIG takes a directory, so use the one you extracted the config.json file to earlier.
i.e.
```
DOCKER_CONFIG=/tmp/  docker pull proxy.replicated.com/proxy/howso-platform/dpbuild-docker-edge.jfrog.io/dp/platform-worker:1.1.992
```

This can be scripted, or combined with `| xargs -n 1 docker pull` to pull all the images.

```
export DOCKER_CONFIG=/tmp/
helm template oci://registry.how.so/howso-platform/stable/howso-platform --values helm-basic/manifests/howso-platform.yaml  2> /dev/null | grep 'image: "' | sed 's/^[ \t]*//' | sed 's/image: "//' | sed 's/"$//' | xargs -n 1 docker pull
unset DOCKER_CONFIG
```
> Note - any issues are likely to be swallowed up in the pipes - so you may want to run the commands individually to troubleshoot.
