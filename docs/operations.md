# Operations Guide

This guide covers day-2 operations for managing and maintaining your Load Balancer deployment.

## Monitoring

### Checking Load Balancer Status

Use the `st` addon to view the current status of your load balancer:

```bash
genesis do site -- st
```

For more detailed information, including HAProxy statistics:

```bash
genesis do site -- st --detailed
```

### Accessing HAProxy Statistics

HAProxy provides a built-in statistics page that can be accessed by configuring a stats frontend:

1. Add a stats frontend to your configuration:
   ```yaml
   params:
     advanced_haproxy_config: |
       listen stats
         bind *:9000
         stats enable
         stats uri /
         stats realm HAProxy\ Statistics
         stats auth admin:admin  # Change this in production!
   ```

2. Redeploy your load balancer:
   ```bash
   genesis deploy site
   ```

3. Access the stats page at: `http://<load-balancer-ip>:9000/`

### Monitoring with Prometheus

To monitor HAProxy with Prometheus:

1. Generate and upload the HAProxy metrics runtime config:
   ```bash
   genesis do site -- rc --upload
   ```

2. Configure Prometheus to scrape metrics from port 9100 on your HAProxy instances.

## Scaling

### Horizontal Scaling

To scale your load balancer horizontally:

1. Update the number of instances in your environment file:
   ```yaml
   params:
     instances: 3  # Increase from the default of 2
   ```

2. Redeploy the environment:
   ```bash
   genesis deploy site
   ```

### Vertical Scaling

To increase the resources allocated to your load balancer VMs:

1. Update the VM resource configuration in your environment file:
   ```yaml
   params:
     cpu: 4         # Increase CPU allocation
     ram: 8192      # Increase RAM allocation (in MB)
     disk: 32768    # Increase disk allocation (in MB)
   ```

2. Redeploy the environment:
   ```bash
   genesis deploy site
   ```

## Certificate Management

### Rotating TLS Certificates

To rotate TLS certificates used by your load balancer:

1. Store the new certificate in Vault or update the existing entry
2. If using explicit certificate paths, update them in your environment file
3. Redeploy the environment:
   ```bash
   genesis deploy site
   ```

## Configuration Changes

### Modifying Load Balancer Configuration

You can modify your load balancer configuration in two ways:

#### 1. Using the Interactive Addon

```bash
genesis do site -- cf
```

This will present an interactive menu that allows you to:
- Add new load balancers
- Modify existing load balancers
- Remove load balancers
- Reset to default configuration

#### 2. Editing the Environment File

1. Edit your environment file to update the configuration
2. Redeploy the environment:
   ```bash
   genesis deploy site
   ```

### Adding a New Load Balancer

To add a new load balancer:

1. Edit your environment file to add a new entry to the `load_balancers` array:
   ```yaml
   params:
     load_balancers:
     - name: existing-lb
       # existing configuration...
     
     - name: new-lb
       mode: http
       port: 8080
       backend:
         addresses:
           - 10.0.0.10:8080
   ```

2. Redeploy the environment:
   ```bash
   genesis deploy site
   ```

### Removing a Load Balancer

To remove a load balancer:

1. Edit your environment file to remove the entry from the `load_balancers` array
2. Redeploy the environment:
   ```bash
   genesis deploy site
   ```

## Backup and Restore

### Backing Up Configuration

The most important thing to back up is your environment configuration file, which contains all the necessary information to recreate your deployment.

1. Back up your environment file:
   ```bash
   cp /path/to/your/deployment-repo/site.yml /path/to/backup/site.yml
   ```

2. Back up any certificates or secrets stored in Vault:
   ```bash
   safe export secret/path/to/certificates > certificates-backup.json
   ```

### Restoring from Backup

To restore your deployment from backup:

1. Restore your environment file:
   ```bash
   cp /path/to/backup/site.yml /path/to/your/deployment-repo/site.yml
   ```

2. Restore any certificates or secrets to Vault:
   ```bash
   safe import < certificates-backup.json
   ```

3. Redeploy the environment:
   ```bash
   genesis deploy site
   ```

## Troubleshooting

### Common Issues

#### Load Balancer Not Forwarding Traffic

1. Check if HAProxy is running:
   ```bash
   genesis do site -- st --detailed
   ```

2. Verify backend servers are responding:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "curl -I http://BACKEND_IP:BACKEND_PORT"
   ```

3. Check HAProxy logs:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "sudo cat /var/vcap/sys/log/haproxy/haproxy.log"
   ```

4. Check HAProxy configuration for errors:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "sudo cat /var/vcap/jobs/haproxy/config/haproxy.conf"
   ```

#### VIP Not Working

1. Verify keepalived is running:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "sudo systemctl status keepalived"
   ```

2. Check keepalived logs:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "sudo cat /var/vcap/sys/log/keepalived/keepalived.log"
   ```

3. Check keepalived configuration:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "sudo cat /var/vcap/jobs/keepalived/config/keepalived.conf"
   ```

4. Check network configuration:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "sudo ip addr show"
   ```

#### Certificate Issues

1. Verify certificate files exist:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "sudo ls -la /var/vcap/jobs/haproxy/config/ssl/"
   ```

2. Check certificate validity:
   ```bash
   bosh -d site-load-balancer ssh haproxy/0 "sudo openssl x509 -in /var/vcap/jobs/haproxy/config/ssl/CERT_NAME.pem -text -noout"
   ```

### Diagnostic Commands

#### HAProxy Status

```bash
bosh -d site-load-balancer ssh haproxy/0 "sudo systemctl status haproxy"
```

#### HAProxy Configuration Check

```bash
bosh -d site-load-balancer ssh haproxy/0 "sudo haproxy -c -f /var/vcap/jobs/haproxy/config/haproxy.conf"
```

#### HAProxy Statistics

```bash
bosh -d site-load-balancer ssh haproxy/0 "echo 'show stat' | sudo socat unix-connect:/var/vcap/sys/run/haproxy/haproxy.sock stdio"
```

#### Network Connectivity Testing

```bash
bosh -d site-load-balancer ssh haproxy/0 "sudo tcpdump -i any port 80 -n"
```

#### Backend Connectivity Testing

```bash
bosh -d site-load-balancer ssh haproxy/0 "curl -v http://BACKEND_IP:BACKEND_PORT"
```