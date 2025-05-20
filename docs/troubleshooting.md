# Troubleshooting Guide

This guide provides solutions for common issues you might encounter when deploying and operating the Load Balancer Genesis Kit.

## Deployment Issues

### Failed to Deploy

#### Symptoms
- `genesis deploy` fails with errors
- BOSH task shows failures

#### Possible Causes and Solutions

1. **Cloud Config Issues**

   **Symptom**: Error messages about missing VM types, networks, or disk types
   
   **Solution**: 
   - Verify your cloud config has the VM types and networks specified in your deployment
   - Update your environment file to use VM types and networks that exist in your cloud config
   
   ```bash
   # Check available VM types and networks
   bosh cloud-config
   
   # Update your environment file as needed
   ```

2. **Missing or Invalid Parameters**

   **Symptom**: Error messages about missing parameters or validation failures
   
   **Solution**:
   - Check the error message for specific parameter names
   - Verify all required parameters are present in your environment file
   - Refer to the [Configuration Guide](configuration.md) for parameter details

3. **Certificate Issues**

   **Symptom**: Error messages about certificate validation or loading
   
   **Solution**:
   - Verify certificate paths in Vault or in your environment file
   - Ensure certificates are in PEM format
   - Check that certificates include both certificate and key when required
   
   ```bash
   # Check a certificate in Vault
   safe get secret/path/to/certificate
   
   # Validate a certificate file
   openssl x509 -in certificate.pem -text -noout
   ```

4. **Network Connectivity Issues**

   **Symptom**: Timeout errors or connection failures during deployment
   
   **Solution**:
   - Verify network connectivity between your BOSH director and deployment VMs
   - Check network firewalls and security groups
   - Ensure necessary ports are open for HAProxy and keepalived

## Runtime Issues

### Load Balancer Not Forwarding Traffic

#### Symptoms
- Services behind the load balancer are unreachable
- HAProxy is running but not forwarding traffic

#### Possible Causes and Solutions

1. **Backend Server Issues**

   **Solution**:
   - Verify backend servers are running and accessible
   - Check connectivity from HAProxy to backend servers
   
   ```bash
   # SSH to HAProxy VM
   bosh -d your-deployment ssh haproxy/0
   
   # Test connectivity to backend
   curl -I http://backend-ip:port
   ```

2. **HAProxy Configuration Issues**

   **Solution**:
   - Check HAProxy configuration for errors
   - Verify frontend and backend configurations match your services
   
   ```bash
   # Check HAProxy configuration
   bosh -d your-deployment ssh haproxy/0 "sudo cat /var/vcap/jobs/haproxy/config/haproxy.conf"
   
   # Verify configuration syntax
   bosh -d your-deployment ssh haproxy/0 "sudo haproxy -c -f /var/vcap/jobs/haproxy/config/haproxy.conf"
   ```

3. **ACL Blocking Traffic**

   **Solution**:
   - Review ACL configurations in your load balancer
   - Temporarily remove ACLs to test if they're causing the issue
   - Add appropriate allow rules for your clients
   
   ```yaml
   # Example of adding an allow rule
   acls:
     - name: my-acl
       allow:
         - your-client-cidr
   ```

4. **Port Conflicts or Firewall Issues**

   **Solution**:
   - Verify the HAProxy ports are open in your security groups/firewalls
   - Check for other services that might be using the same ports
   - Use netstat to check for listening ports
   
   ```bash
   bosh -d your-deployment ssh haproxy/0 "sudo netstat -tlnp"
   ```

### VIP Feature Not Working

#### Symptoms
- Virtual IP is not accessible
- Keepalived not holding the VIP

#### Possible Causes and Solutions

1. **Keepalived Configuration Issues**

   **Solution**:
   - Check keepalived configuration
   - Verify VRRP settings are correct
   - Ensure the virtual-router-id is unique on your network
   
   ```bash
   # Check keepalived configuration
   bosh -d your-deployment ssh haproxy/0 "sudo cat /var/vcap/jobs/keepalived/config/keepalived.conf"
   
   # Check keepalived status
   bosh -d your-deployment ssh haproxy/0 "sudo systemctl status keepalived"
   ```

2. **Network Limitations**

   **Solution**:
   - Some cloud providers don't allow gratuitous ARP or multicast, which keepalived requires
   - Check your cloud provider's documentation for VIP/floating IP support
   - Consider using cloud provider-specific load balancers instead

3. **Multiple Instances Holding VIP**

   **Solution**:
   - Check if multiple instances are trying to hold the VIP
   - Verify all instances have the same keepalived configuration
   - Check if the virtual-router-id is being used elsewhere on your network

### TLS/Certificate Issues

#### Symptoms
- HTTPS connections fail
- Certificate warnings in browsers
- HAProxy fails to start or load certificates

#### Possible Causes and Solutions

1. **Invalid Certificate Format**

   **Solution**:
   - HAProxy expects certificates in PEM format with both cert and key
   - Verify certificate format and content
   
   ```bash
   # Check certificate files on HAProxy VM
   bosh -d your-deployment ssh haproxy/0 "sudo ls -la /var/vcap/jobs/haproxy/config/ssl/"
   
   # Validate certificate
   bosh -d your-deployment ssh haproxy/0 "sudo openssl x509 -in /var/vcap/jobs/haproxy/config/ssl/cert.pem -text -noout"
   ```

2. **Certificate Path Issues**

   **Solution**:
   - Verify certificate paths in your configuration
   - Check if certificates are correctly stored in Vault
   - Ensure certificate references use the correct path format
   
   ```yaml
   # Example of correct certificate reference
   tls:
     certificates:
       - ((vault "secret/path/to/cert:combined"))
   ```

3. **Certificate Not Trusted**

   **Solution**:
   - Ensure your certificate is signed by a trusted CA
   - For self-signed certificates, add the CA to client trust stores
   - Check certificate expiration dates

## Monitoring and Maintenance Issues

### Cannot Access HAProxy Stats

#### Symptoms
- HAProxy stats page is inaccessible
- Cannot retrieve statistics

#### Possible Causes and Solutions

1. **Stats Not Configured**

   **Solution**:
   - Enable stats in HAProxy configuration
   
   ```yaml
   params:
     advanced_haproxy_config: |
       listen stats
         bind *:9000
         stats enable
         stats uri /
         stats realm HAProxy\ Statistics
         stats auth admin:admin
   ```

2. **Firewall Blocking Stats Port**

   **Solution**:
   - Verify firewall rules allow access to the stats port
   - Check security groups in your cloud provider

### Status Addon Failures

#### Symptoms
- `genesis do my-env -- st` fails or shows errors

#### Possible Causes and Solutions

1. **BOSH Connectivity Issues**

   **Solution**:
   - Verify BOSH director is accessible
   - Check your BOSH credentials and environment variables
   
   ```bash
   # Test BOSH connectivity
   bosh environments
   bosh deployments
   ```

2. **Deployment Not Found**

   **Solution**:
   - Verify the deployment exists
   - Check deployment name format
   
   ```bash
   # List deployments
   bosh deployments
   ```

## Advanced Debugging

### HAProxy Debugging

For advanced debugging of HAProxy:

```bash
# Enable HAProxy debug log
bosh -d your-deployment ssh haproxy/0 "sudo sed -i 's/log local0 notice/log local0 debug/' /var/vcap/jobs/haproxy/config/haproxy.conf"
bosh -d your-deployment ssh haproxy/0 "sudo monit restart haproxy"

# View debug logs
bosh -d your-deployment ssh haproxy/0 "sudo tail -f /var/vcap/sys/log/haproxy/haproxy.log"
```

### Network Traffic Analysis

For analyzing network traffic:

```bash
# Install tcpdump if needed
bosh -d your-deployment ssh haproxy/0 "sudo apt-get update && sudo apt-get install -y tcpdump"

# Capture traffic on a specific port
bosh -d your-deployment ssh haproxy/0 "sudo tcpdump -i any port 80 -n -vvv"
```

### Test Backend Connectivity

To test connectivity to backend servers:

```bash
# Test HTTP backend
bosh -d your-deployment ssh haproxy/0 "curl -v http://backend-ip:port"

# Test TCP backend
bosh -d your-deployment ssh haproxy/0 "nc -zv backend-ip port"
```

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [Genesis Community Slack](https://genesiscommunity.slack.com/)
2. File an issue on the [GitHub repository](https://github.com/genesis-community/load-balancer-genesis-kit)
3. Contact your Genesis support channel