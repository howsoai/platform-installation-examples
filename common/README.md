
## Login to the Howso Platform 

Hit the User Management Service (UMS) first.  Proceed passed the certifcate warning.  Login with the default admin credentials (platform-admin/platform).  You will be prompted to change the password. 

https://management.local.howso.com/

As you navigate you will be redirected to other subdomains - each of which will have a certificate warning to accept.  Calls to the api domain are cross domain, so navigate directly https://api.local.howso.com/.


> Note the certificate(s) offered by the k8s ingress by default will be signed by a platform ca (stored as a secret at platform-ca) - which can be extracted and trusted.  It is possible to override this behavior and use a custom ingress certificate.
 

## Create Client Environment 

### Create Client Credentials
This is just a quick set-up.  The admin user wouldn't typically have their own client credentials, but would be used to bootstrap other users.
From the Project Page > New Project > "Test Project".
From Howso Admin Drop-down > Profile > Preferences > Default Project > "Test Project" > Save
From Howso Admin Drop-down > Credentials > New Credential > "test" Copy|Download as howso.yaml in ~/.howso/howso.yaml or in your local working directory.

Either [Trust the Certs](#trust-the-certs) or [Disable SSL Verification](#disable-ssl-verification) before proceeding.

## Disable SSL Verification
Edit the `howso.yaml` file and set `verify_ssl: false.


## Trust the Certs 
Get the platform cert from the ca secret
```
kubectl -n howso get secrets platform-ca -ojson | jq -r '.data."tls.crt"' | base64 -d > howso-platform.crt
```

### Linux/WSL
```
sudo mv -v ./howso-platform.crt /usr/local/share/ca-certificates/howso-platform.crt
sudo update-ca-certificates
```

## Create Python environment 

- Create a python virtual environment using your preferred method. 

- Navigate to Howso Admin Drop-down > Client Setup. 

- Copy the pip install command, and run in your new virtual environment. 
i.e.
```
pip install -U --trusted-host pypi.local.howso.com --extra-index-url https://mySecretPypiToken@pypi.local.howso.com/simple/ howso-platform-client[full]
```

## Test the install

Run the verification script to ensure everything is working.
```
python -m howso.utilities.installation_verification
```

