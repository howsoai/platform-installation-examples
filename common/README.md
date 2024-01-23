
## Login to the Howso Platform 

Hit the User Management Service (UMS) first.  Proceed passed the certifcate warning.  Login with the default admin credentials (platform-admin/platform).  You will be prompted to change the password. 

https://management.local.howso.com/

As you navigate you will be redirected to other subdomains - each of which will have a certificate warning to accept.  Calls to the api domain are cross domain, so navigate directly https://api.local.howso.com/.


> Note the certificate(s) offered by the k8s ingress by default will be signed by a platform ca (stored as a secret at platform-ca) - which can be extracted and trusted.  It is possible to override this behavior and use a custom ingress certificate.
 

## Create Client Environment 
### Create Test User
> Using UMS to create a test user and get the howso.yml config file

```
kubectl -n howso exec -it deploy/platform-ums -c ums -- /container_files/bin/setup_tests.sh create_user_and_get_diveplane_yml tester1 local.howso.com | awk '/START/{flag=1; next} /END/{flag=0} flag' | grep -v -e verify_ssl -e suppress_tls_warnings
```

## Setup Certs 
> Getting the platform cert from the ca secret

```
kubectl -n howso get secrets platform-ca -ojson | jq -r '.data."tls.crt"' | base64 -d
```

```
sudo cp -v ./howso-platform.crt /usr/local/share/ca-certificates/howso-platform.crt
```

```
sudo update-ca-certificates
```

## Create Python environment 
### Command Executed (from /home/dom/workspaces/howso-platform-start/components/platform-tests/envs/helm-replicated-k3d-howso-platform)
```
pip install -U howso-platform-client[full]
```

### Command Executed (from /home/dom/workspaces/howso-platform-start/components/platform-tests)
```
time python -m howso.utilities.installation_verification
```

