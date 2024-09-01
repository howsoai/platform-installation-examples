
You've now set up cert-manager with a Vault issuer in your k3d cluster. This setup allows you to automatically issue and manage TLS certificates using Vault as your certificate authority.

Remember, this setup is for demonstration purposes. In a production environment, you would want to:
- Use HTTPS for Vault communication
- Use a more secure method for Vault authentication (like Kubernetes service account token authentication)
- Implement proper secret management for sensitive data like tokens
- Configure appropriate certificate lifetimes and renewal policies






platform-ca                         True    platform-ca                         5h26m
minio-server-cert                   True    platform-minio-server-tls           5h25m
platform-natsbox-nats-client-tls    True    platform-natsbox-nats-client-tls    5h25m
nats-cluster-tls                    True    nats-cluster-tls                    5h25m
nats-server-tls                     True    nats-server-tls                     5h25m
postgres-server-cert                True    platform-postgres-server-tls        5h24m
platform-postgres-client-tls        True    platform-postgres-client-tls        5h24m
platform-redis-server-cert          True    platform-redis-server-tls           5h23m
platform-redis-client-tls           True    platform-redis-client-tls           5h23m
platform-ums-ingress-tls            True    platform-ums-ingress-tls            5h23m
platform-ui-v2-ingress-tls          True    platform-ui-v2-ingress-tls          5h23m
platform-pypi-ingress-tls           True    platform-pypi-ingress-tls           5h23m
platform-api-v3-ingress-tls         True    platform-api-v3-ingress-tls         5h23m
platform-api-v3-nats-client-tls     True    platform-api-v3-nats-client-tls     5h23m
platform-notsvc-nats-client-tls     True    platform-notsvc-nats-client-tls     5h23m
platform-operator-nats-client-tls   True    platform-operator-nats-client-tls   5h23m
platform-sms-nats-client-tls        True    platform-sms-nats-client-tls        5h23m
platform-ums-nats-client-tls        True    platform-ums-nats-client-tls        5h23m
platform-ums-oauth-keys-cert        True    platform-ums-oauth-keys             5h23m
platform-worker-nats-client-tls     True    platform-worker-nats-client-tls     5h23m
test-example-com                         True    test-example-com-tls                     16m
 
kubectl create secret generic platform-ca \
    --from-file=ca.crt=root_ca.crt \
    -n howso
	