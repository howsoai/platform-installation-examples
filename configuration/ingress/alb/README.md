# ALB (Application Load Balancer) Ingress

In addition to the main [setup](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html) - when using AWS Application Load Balancer (ALB) for ingress, certain annotations are required to ensure proper routing and load balancing.

## Key Annotations

The following additional annotations are required, otherwise multiple ALBs will be processing rules for the same host name.  The group order ensures that the most specific rules are processed first.

- `alb.ingress.kubernetes.io/group.name`: Specifies the ingress group name - which groups multiple ingress resources into a single ALB.
- `alb.ingress.kubernetes.io/group.order`: Defines the order of processing within the ingress group.

### platform-api-v2

```yaml
alb.ingress.kubernetes.io/group.name: api
alb.ingress.kubernetes.io/group.order: "3"
```

### platform-api-v3

```yaml
alb.ingress.kubernetes.io/group.name: api
alb.ingress.kubernetes.io/group.order: "2"
```

### platform-ums

```yaml
alb.ingress.kubernetes.io/group.name: api
alb.ingress.kubernetes.io/group.order: "1"
```

For more information on the available annotations see the [AWS Load Balancer Controller documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/annotations/).

## Example Manifest

For an example of ALB ingress configuration, see the [alb-ingress.yaml](manifests/alb-ingress.yaml) file.