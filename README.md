# Docker stack sample

Sample docker stack with deploy script

## Getting Started

This repository using traefik, consul, portainer, prometheus, grafana, alertmanager, cadvisor, node-exporter.

### Prerequisites && Installing

Please install docker and create swarm cluster first. Swarm have to include one or more manager node and one or more worker node.

* Install Docker Desktop for MAC: [https://docs.docker.com/docker-for-mac/install/](https://docs.docker.com/docker-for-mac/install/)

* Install Docker Desktop for Windows: [https://docs.docker.com/docker-for-windows/install/](https://docs.docker.com/docker-for-windows/install/)

* Create swarm: [https://docs.docker.com/engine/swarm/swarm-tutorial/create-swarm/](https://docs.docker.com/engine/swarm/swarm-tutorial)

* Docker for aws: [https://docs.docker.com/docker-for-aws/](https://docs.docker.com/docker-for-aws/)

## Deploy with deploy.sh

```bash
  sh ./deploy.sh
```

## Deploy with docker cli

Deploy proxy stack first and deploy swarmprom after proxy deployed.

### Deploy proxy stack

Traefik is reverse proxy service and generate let's encrypt certificate. Consul is store HTTPS certificates.

Traefik make certificate to use let's encrypt. Create an environment variable with your email for generate let's encrypt certificate.

```bash
  export EMAIL=email@example.com
```

Create an exvironment variable with your root domain for access traefik UI in your browser.

```bash
  export DOMAIN=example.com  # traefik web UI domain will be https://traefik.example.com
```

Create an environment variabke with username for traefik UI http basic auth.

```bash
  export USERNAME=example
```

Create an environment variable with password.

```bash
  export PASSWORD=examplepassword
```

Use openssl to generate hashed password and store it in an environment variable. If you don't have openssl, please install.

```bash
  export HASHED_PASSWORD=$(openssl passwd -apr1 $PASSWORD)
```

Deploy stack.

```bash
  docker stack deploy -c proxy.yml proxy
```

### Deploy swarmprom stack

Alertmanager handles alerts sent by client applications such as the Prometheus server. Cadvisor Analyzes resource usage and performance characteristics of running containers. Grafana is the open platform for analytics and monitoring. Node-exporter is Prometheus exporter for hardware and OS metrics exposed by *NIX kernels, written in Go with pluggable metric collectors. Portainer is a lightweight management UI which allows you to easily manage your Docker host or Swarm cluster. Prometheus is an open-source systems monitoring and alerting toolkit originally built at SoundCloud.


Create environment variabke with slack data for alertmanager.

```bash
  export SLACK_URL=slack_webhook_url_with_token
  export SLACK_CHANNEL=slack_channel_name
  export SLACK_USER=slack_user_name
```

Creat environment variabke with grafana admin account.

```bash
  export USERNAME=admin
  export PASSWORD=password
```

Create an environment variabke with your root domain for access grafana and portainer.

```bash
  export DOMAIN=example.com  # https://grafana.example.com, https://portainer.example.com
```

Add label to one of worker node to deploy grafana, prometheus, alertmanager.

```bash
  docker node update --label-add swarmprom=true WORKER_NODE
```

Add label to one of manager node to deploy portainer.

```bash
  docker node update --label-add portainer.portainer-data=true MANAGER_NODE
```

Deploy stack.

```bash
  docker stack deploy -c swarmprom.yml swarmprom
```

## Check deployment

If stack is successfully deployed, check your service list with followed command.

```bash
  ~ $ docker service ls
  ID                  NAME                        MODE                REPLICAS            IMAGE                                          PORTS
  08jk4ygz011x        proxy_consul-leader         replicated          1/1                 consul:latest                                  
  1gbyzofcxjgn        proxy_consul-replica        global              3/3                 consul:latest                                  
  ilgfu6abo3qf        proxy_traefik               global              3/3                 traefik:latest                                 *:80->80/tcp, *:443->443/tcp
  lpy3sr2tieth        swarmprom_alertmanager      replicated          1/1                 stefanprodan/swarmprom-alertmanager:v0.14.0    
  uydc6skm9a85        swarmprom_cadvisor          global              5/5                 google/cadvisor:latest                         
  0uwpr3poia4u        swarmprom_grafana           replicated          1/1                 stefanprodan/swarmprom-grafana:5.3.4           
  8b9943u04any        swarmprom_node-exporter     global              5/5                 stefanprodan/swarmprom-node-exporter:v0.16.0   
  vl8cfr65gcmq        swarmprom_portainer         replicated          1/1                 portainer/portainer:latest                     
  5977967ggnbv        swarmprom_portainer-agent   global              5/5                 portainer/agent:latest                         
  a8z9v9hogf6n        swarmprom_prometheus        replicated          1/1                 stefanprodan/swarmprom-prometheus:v2.5.0  
```

You can check stack list with followed command.

```bash
  ~ $ docker stack ls
  NAME                SERVICES            ORCHESTRATOR
  proxy               3                   Swarm
  swarmprom           7                   Swarm
```

And finally lets check each service web UI in your browser.

* traefik: https://traefik.yourdomain.com
* grafana: https://grafana.yourdomain.com
* portainer: https://portainer.yourdomain.com
