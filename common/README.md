## Create Client Environment 

### Login to the Howso Platform 

Hit the User Management Service (UMS) first.  Proceed passed the certifcate warning.  Login with the default admin credentials (platform-admin/platform).  You will be prompted to change the password. 

https://management.local.howso.com/

As you navigate you will be redirected to other subdomains - each of which will have a certificate warning to accept.  Calls to the api domain are cross domain, so navigate directly https://api.local.howso.com/.


> Note the certificate(s) offered by the k8s ingress by default will be signed by a platform ca (stored as a secret at platform-ca) - which can be extracted and trusted.  It is possible to override this behavior and use a custom ingress certificate.
 


### Create Client Credentials
This is just a quick set-up.  The admin user wouldn't typically have their own client credentials, but would be used to bootstrap other users.
 - From the Project Page > New Project > "Test Project".
 - From Howso Admin Drop-down > Profile > Preferences > Default Project > "Test Project" > Save
 - From Howso Admin Drop-down > Credentials > New Credential > "test" Copy|Download as howso.yml in ~/.howso/howso.yml or in your local working directory.

Either [Trust the Certs](#trust-the-certs) or [Disable SSL Verification](#disable-ssl-verification) before proceeding.

### Disable SSL Verification
Edit the `howso.yml` file and set `verify_ssl: false.


### Trust the Certs 
The python client environmnet, uses the certifi package for root certs, and not the os trust store.  So to trust the platform ca - we'll extract it from the platform and then set it explicityly as trusted in our `howso.yml`


- Get the platform cert from the ca secret
```
kubectl -n howso get secrets platform-ca -ojson | jq -r '.data."tls.crt"' | base64 -d > howso-platform.crt
```
- Alternatively, you can retrieve it from https://www.local.howso.com/ca-crt.txt in a browser, and save it as `howso-platform.crt`.

- Update the howso.yml with a full path to the cert file, under key `security.ssl_ca_cert`.  i.e.
```
security:
    ssl_ca_cert: /full/path/howso-platform.crt
    ...
howso:
  ...
```


### Create Python environment 

- Create a python virtual environment using your preferred method. 

- Navigate to Howso Admin Drop-down > Client Setup. 

- Copy the pip install command, and run in your new virtual environment. 
i.e.
```
pip install -U --trusted-host pypi.local.howso.com --extra-index-url https://mySecretPypiToken@pypi.local.howso.com/simple/ howso-platform-client[full]
```
> Note - a fuller install would create a secret for the pypi token - above is the default.

### Test the install

Run the verification script to ensure everything is working.
```
python -m howso.utilities.installation_verification
```


## Troubleshooting

- Access all the values for howso-platform
```sh
helm show  values oci://registry.how.so/howso-platform/stable/howso-platform | less
```