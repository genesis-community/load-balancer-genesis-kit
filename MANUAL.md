# Load Balancer Genesis Kit Manual

The **Load Balancer Genesis Kit** deploys a haproxy-backed load
balancer for your CF.
Haproxy is a load balancing solution for Cloud Foundry. Haproxy 
allows you to define access control lists (or ACL's) to specify
what is allowed and what is blocked.

# Base Parameters

- `vm_type` - What type of VM to deploy.  This type must
  exist in your cloud config.  Defaults to `default`.

- `lb_network` - What network to deploy haproxy into.  This
  network must be defined in your cloud config.  Defaults to
  `default`.
- `advanced_haproxy_config` - Any configuration 
values you want to deploy verbatim into haproxy. If none,
set to null string.

- `load_balancers` - Any load balancers 
you want to deploy with haproxy. If none, set to 
empty array.



# Examples

A sample load-balancer to only allow internal ip addresses
to connect to a specified backend

```
---
kit:
  name: load-balancer
  version: 0.0.1

params:
  load_balancers:
  - name: front-door 
    mode: http       
    port: 443
    acls:
    - name: internal-only
      deny:
        - 10.0.0.0/8
    backend:
      addresses:
        - 10.200.0.100:3200 

    tls:
      certificates:
      - (( vault meta.vault "path/to/cert:combined" ))
  advanced_haproxy_config: null
  haproxy_network: default
  vm_type: default
```
