# Nginx Proxy Manager and Authelia Setup

This guide will walk you through setting up Nginx Proxy Manager (NPM) with Authelia for secure access to your home server services. This combination provides:

- A reverse proxy to route traffic to different services
- SSL certificate management with Let's Encrypt
- Single sign-on (SSO) for all your services
- Multi-factor authentication (MFA)
- Access control policies

## Docker Compose Setup

We'll use Docker Compose to set up both services. First, let's create the configuration files.

### Nginx Proxy Manager

Create a docker-compose.yml file for Nginx Proxy Manager:

```bash
cd ~/docker/nginx-proxy-manager
nano docker-compose.yml
```

Add the following content:

```yaml
version: '3.8'

services:
  nginx-proxy-manager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'  # Admin UI
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    environment:
      DB_MYSQL_HOST: "npm-db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm"
      DB_MYSQL_PASSWORD: "npm-password"  # Change this!
      DB_MYSQL_NAME: "npm"
    depends_on:
      - npm-db
    networks:
      - proxy
    profiles:
      - proxy

  npm-db:
    image: 'jc21/mariadb-aria:latest'
    container_name: npm-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: 'npm-password'  # Change this!
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: 'npm-password'  # Change this!
    volumes:
      - ./data/mysql:/var/lib/mysql
    networks:
      - proxy
    profiles:
      - proxy

networks:
  proxy:
    external: true
```

### Authelia

Now, let's set up Authelia. First, create the necessary configuration files:

```bash
cd ~/docker/authelia
mkdir -p config
```

Create the configuration.yml file:

```bash
nano config/configuration.yml
```

Add the following content:

```yaml
---
theme: light
jwt_secret: a_very_important_secret  # Change this!
default_redirection_url: https://auth.yourdomain.com

server:
  host: 0.0.0.0
  port: 9091

log:
  level: info
  format: text

totp:
  issuer: yourdomain.com  # Change this!
  period: 30
  skew: 1

authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 1
      key_length: 32
      salt_length: 16
      memory: 1024
      parallelism: 8

access_control:
  default_policy: deny
  rules:
    - domain: auth.yourdomain.com  # Change this!
      policy: bypass
    - domain: "*.yourdomain.com"  # Change this!
      policy: one_factor

session:
  name: authelia_session
  secret: unsecure_session_secret  # Change this!
  expiration: 12h
  inactivity: 45m
  domain: yourdomain.com  # Change this!

regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

storage:
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
```

Create the users database file:

```bash
nano config/users_database.yml
```

Add the following content (replace with your own user information):

```yaml
---
users:
  homeadmin:  # Change this username
    displayname: "Home Admin"
    password: "$argon2id$v=19$m=65536,t=3,p=4$CHANGE_THIS_PASSWORD_HASH"  # We'll generate this later
    email: your.email@example.com  # Change this
    groups:
      - admins
```

Now, create the docker-compose.yml file for Authelia:

```bash
nano docker-compose.yml
```

Add the following content:

```yaml
version: '3.8'

services:
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    restart: unless-stopped
    volumes:
      - ./config:/config
    ports:
      - "9091:9091"
    environment:
      - TZ=UTC
    networks:
      - proxy
    profiles:
      - auth

networks:
  proxy:
    external: true
```

## Starting the Services

### Start Nginx Proxy Manager

```bash
cd ~/docker/nginx-proxy-manager
docker-compose --profile proxy up -d
```

### Generate Password Hash for Authelia

```bash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'YourSecurePassword'
```

Replace the password hash in the users_database.yml file with the generated hash.

### Start Authelia

```bash
cd ~/docker/authelia
docker-compose --profile auth up -d
```

## Configuring Nginx Proxy Manager

1. Access the Nginx Proxy Manager admin interface at http://your-server-ip:81
2. Log in with the default credentials:
   - Email: admin@example.com
   - Password: changeme
3. You'll be prompted to change the default credentials

### Add SSL Certificates

1. Go to "SSL Certificates" and click "Add SSL Certificate"
2. Choose "Let's Encrypt" and enter:
   - Domain Names: yourdomain.com, *.yourdomain.com
   - Email Address: your.email@example.com
3. Check "Use a DNS Challenge" if you're using a wildcard certificate
4. Follow the instructions to verify domain ownership
5. Click "Save" to generate the certificate

### Configure Authelia Proxy Host

1. Go to "Hosts" > "Proxy Hosts" and click "Add Proxy Host"
2. Configure the following:
   - Domain Name: auth.yourdomain.com
   - Scheme: http
   - Forward Hostname / IP: authelia
   - Forward Port: 9091
3. Under the "SSL" tab:
   - Select your SSL certificate
   - Force SSL: Enabled
4. Click "Save"

## Integrating Authelia with Nginx Proxy Manager

To protect your services with Authelia, you'll need to add custom configurations to each proxy host.

1. Create a new proxy host or edit an existing one
2. Under the "Advanced" tab, add the following configuration:

```nginx
location /authelia {
    internal;
    set $upstream_authelia http://authelia:9091/api/verify;
    proxy_pass_request_body off;
    proxy_pass $upstream_authelia;
    proxy_set_header Content-Length "";
    
    # Timeout if the real server is dead
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    
    # [REQUIRED] Needed by Authelia
    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-Uri $request_uri;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Content-Length "";
    
    # [OPTIONAL] Timeout if Authelia is down
    proxy_connect_timeout 5s;
    proxy_send_timeout 5s;
    proxy_read_timeout 5s;
}

# [REQUIRED] Authentication request
auth_request /authelia;
auth_request_set $target_url $scheme://$http_host$request_uri;
auth_request_set $user $upstream_http_remote_user;
auth_request_set $groups $upstream_http_remote_groups;
auth_request_set $name $upstream_http_remote_name;
auth_request_set $email $upstream_http_remote_email;
proxy_set_header Remote-User $user;
proxy_set_header Remote-Groups $groups;
proxy_set_header Remote-Name $name;
proxy_set_header Remote-Email $email;

# [REQUIRED] Redirect to Authelia if not authenticated
error_page 401 =302 https://auth.yourdomain.com/?rd=$target_url;
```

3. Save the configuration

## Testing the Setup

1. Access your protected service at its domain (e.g., https://service.yourdomain.com)
2. You should be redirected to the Authelia login page
3. After successful authentication, you'll be redirected back to your service

## Troubleshooting

### Nginx Proxy Manager Issues

- Check logs: `docker logs nginx-proxy-manager`
- Verify port forwarding on your router
- Ensure DNS records are correctly configured

### Authelia Issues

- Check logs: `docker logs authelia`
- Verify configuration.yml syntax
- Check users_database.yml format and password hash

## Security Recommendations

1. Change all default passwords and secrets in configuration files
2. Enable two-factor authentication in Authelia
3. Use strong, unique passwords for all services
4. Regularly update Docker images: `docker-compose pull && docker-compose up -d`
5. Consider implementing IP-based access rules for additional security

## Next Steps

Now that you have Nginx Proxy Manager and Authelia set up, you can proceed to the next section to configure Prometheus and Grafana for monitoring your home server.
