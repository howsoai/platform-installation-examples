# Container Scanning

The simplest way to get all the images to scan is to extract them from the airgap bundle.


 tar -vtzf "${AIRGAP_ARCHIVE}" |  awk '{ if ($3 != 0) {print $6}}' | grep "^images/docker-archive/"


## Container registry 

Replicated hosted helm charts embed an customer's container secret in the chart, to simplify the installation process.  Extract your organization's container registry credentials from the Helm chart with the following one liner.  Make sure to have logged in first, as per the [prerequisites](../prereqs/README.md).
```
helm template oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-basic/manifests/howso-platform.yaml --show-only templates/image-pull-secret.yaml 2> /dev/null | yq eval '.data.".dockerconfigjson"'  | base64 -d | jq . > /tmp/config.json
```

You can't directly `docker login` to the proxy registry - but you can, add the `auths` key to your `~/docker/config.json` or use the config directly with the DOCKER_CONFIG environment variable.  Store it in a suitable location - tmp file used for demo purposes only.

## List all the images

Dealing just with the Howso Platform - you can template the chart and extract the images with something like the following.
```
# template the platform chart | grep for images | remove leading whitespace, image tag and trailing quotes 
helm template oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso | grep 'image: "proxy.replicated.com' 2> /dev/null | sed 's/^[ \t]*//' | sed 's/image: "//' | sed 's/"$//'
```

## Pull the images

DOCKER_CONFIG takes a directory, so use the one you extracted the config.json file to earlier.
i.e.
```
DOCKER_CONFIG=/tmp/  docker pull proxy.replicated.com/proxy/howso-platform/dpbuild-docker-edge.jfrog.io/dp/platform-worker:1.1.992
```

This can be scripted, or combined with `| xargs -n 1 docker pull` to pull all the images.