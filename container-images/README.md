# Downloading Images for Airgap Installs and Scanning

## Overview 

The simplest approach for airgap helm installs is to Download the airgap bundle, and use the `kubect kots` command to push the images to a container registry.  Alternatively it is possible to access the container registry directly - and download the images yourself.


## Download Airgap Bundle

- Navigate to the Howso Customer Portal at [https://portal.howso.com/](https://portal.howso.com)
- In the top right drop-down, where your name appears, select 'Organizations', and select the appropriate value (usually your company name).
- Scroll down the organization page, and you'll see any licenses.  Airgap enabled licenses will have buttons to download the bundle and reset the password.  If you don't see an air-gapped license, contact your Howso representative.
- If this is your first time downloading an application bundle, or you've forgotten the password, select 'Reset Bundle Password' then copy the password and click OK.
- Select 'Air Gap Bundle' and enter the password to get to the Download Portal.
- In the 'Latest Howso Platform Airgap bundle' Section select 'Download air-gap bundle'
- Save the file (~ 1 Gig) via the browser, or copy the link and use wget or curl. 

### Extracting the images 

The airgap bundle container the image layers, extracting them requires first using the 
kubectl kots admin-console push-images ~/2024.1.0.airgap registry-localhost:5000 --registry-username reguser --registry-password pw --namespace howso --skip-registry-check

You can list the images in the bundle with the following command. 

```sh
AIRGAP_ARCHIVE=~/2024.1.0.airgap # or wherever you saved the file
tar -xzOf "${AIRGAP_ARCHIVE}" ./airgap.yaml | yq e '.spec.savedImages[]' # The airgap.yaml file contains a list of the images in the bundle - if you don't have yq just remove the piped cmd
```


## Container registry 

Replicated hosted helm charts embed an customer's container secret in the chart, to simplify the installation process.  Extract your organization's container registry credentials from the Helm chart with the following one liner.  Make sure to have logged in first, as per the [prerequisites](../prereqs/README.md).
```
helm template oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --show-only templates/image-pull-secret.yaml 2> /dev/null | yq eval '.data.".dockerconfigjson"'  | base64 -d | jq . > /tmp/config.json
```

You can't directly `docker login` to the proxy registry - but you can, add the `auths` key to your `~/docker/config.json` or use the config directly with the DOCKER_CONFIG environment variable.  Store it in a suitable location - tmp file used for demo purposes only.

### List all the images

Dealing just with the Howso Platform - you can template the chart and extract the images with something like the following.
```
# template the platform chart | grep for images | remove leading whitespace, image tag and trailing quotes 
helm template oci://registry.how.so/howso-platform/stable/howso-platform --values helm-basic/manifests/howso-platform.yaml  2> /dev/null | grep 'image: ' | sed 's/^[ \t]*//' | sed 's/image: "//' | sed 's/"$//'
```
> Note it is important that you run this from this repo, as the values file will alter the images to the correct format.

### Pull the images

DOCKER_CONFIG takes a directory, so use the one you extracted the config.json file to earlier.
i.e.
```
DOCKER_CONFIG=/tmp/  docker pull proxy.replicated.com/proxy/howso-platform/dpbuild-docker-edge.jfrog.io/dp/platform-worker:1.1.992
```

This can be scripted, or combined with `| xargs -n 1 docker pull` to pull all the images.