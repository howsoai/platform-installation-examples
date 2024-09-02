# Troubleshooting Howso Platform Certificates

## Cert-manager

### Discovering why a certificate is not issued

Cert-manager turns Certificate k8s resources into secrets.  Using kubectl it will indicate a Ready condition when the certificate is issued.  In the examples, this shouldn't take long, though with real world issuers, it may take longer.

```sh
kubectl get certificate -n howso 
```

If the certificate is not ready, there are a number of kubernetes resources that can be checked.  Starting with the certificate, look for the status conditions.  These appear as the last section of the output, when using the `--output yaml` flag.

```sh
kubectl get certificate platform-redis-server-cert -oyaml
```

For each certificate, there is a CertificateRequest that is created.  This is the request to the issuer to issue the certificate.  Check the status of the CertificateRequest.

```sh
kubectl get certificaterequest -n howso
# Get the name of the relevent cert, and check the status of the request
kubectl get certificaterequest platform-redis-server-cert-xxxxx -n howso -oyaml
```

In this example the status object displays the reason for the pending status.  In this case, the issuer is not found.
```sh
  - lastTransitionTime: "2024-09-02T11:19:58Z"
    message: 'Referenced "Issuer" not found: issuer.cert-manager.io "vault-ingress-issuer"
      not found'
    reason: Pending
    status: "False"
    type: Ready
```

## Check the Cert-manager logs


```sh
kubectl logs -n cert-manager -l app=cert-manager
```