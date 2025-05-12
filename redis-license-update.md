# Redis Licensing Update & Valkey Alternative

Effective March 20, 2024, Redis versions 7.4 and later adopted a dual SSPLv1/RSALv2 license. This replaced the previous BSD-3-Clause license used for earlier versions.

- Redis versions _7.2.4 and older_ remain under the BSD-3-Clause license.
- Redis versions _7.4 and newer_ are subject to the SSPLv1/RSALv2 terms.

For users who prefer or require a BSD-3-Clause licensed datastore, Valkey is a compatible alternative.

## Valkey: A Drop-In BSD-Licensed Alternative

Valkey is a Linux Foundation project, forked from Redis 7.2.4. It serves as a drop-in replacement for Redis and continues under the BSD-3-Clause license. You can find the Valkey project on GitHub: [valkey-io/valkey](https://github.com/valkey-io/valkey).

Key aspects of Valkey:
- _Compatibility_: Valkey 7.2 maintains full compatibility with Redis 7.2. The Valkey installation provides symlinks for common Redis binaries (e.g., `redis-server`, `redis-cli`) to their Valkey counterparts.
- _Vendor Support_: Valkey is supported by major cloud providers and package maintainers like Bitnami, who offer `bitnami/valkey` images and dedicated Valkey Helm charts.

## Using Valkey with Howso Platform

If you choose to use Valkey, you can typically update your Helm chart configuration.

### Example: Updating Helm Chart to Use Valkey

To switch an existing Helm deployment (e.g., using a Bitnami-based chart) from Redis to Valkey, modify the `image` configuration in your `values.yaml` or direct chart parameters:

```yaml
image:
  repository: bitnami/valkey # Changed from bitnami/redis
  tag: "8.1.1-debian-12-r0"  # Specify your desired Valkey tag
``` 