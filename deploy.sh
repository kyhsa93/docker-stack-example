# /bin/sh

checkSwarm() {
  swarm=$(docker info --format {{.Swarm.LocalNodeState}})
  if [ "$swarm" = "inactive" ];then
    echo "\033[31m"Error: Swarm mode is inactive. Please run \'docker swarm init\' or \'docker swarm join\' first."\033[0m"
    exit
  fi
}

createDomain() {
  echo "Please wirte user root domain: "\\c
  read domain

  if [ -z $domain ];then
    echo "\033[31m"Argument is omitted. Root domain will be deploied localhost."\033[0m"
    domain="localhost"
  fi
  echo "Selected root domain is "$domain
}

createAdmin() {
  echo "New admin ID: "\\c
  read user

  if [ -z $user ] || [ ${#user} -lt 5 ];then
    echo "\033[31m"Error: Admin ID length must be over 5. Please try again."\033[0m"
    createAdmin
  fi

  echo "New admin password: "\\c
  read password

  if [ -z $password ] || [ ${#password} -lt 8 ];then
    echo "\033[31m"Error: Admin password length must be over 8. Please try again."\033[0m"
    createAdmin
  fi

  echo "confirm password: "\\c
  read confirm

  if [ "$password" != "$confirm" ];then
    echo "\033[31m"Error: Admin passwrod confirm is fail. Please try again."\033[0m"
    createAdmin
  fi
}

craeteAcmeEmail() {
  echo "email for traefik acme: "\\c
  read email

  if [ -z $email ] || [ ${#email} -lt 5 ];then
    echo "\033[31m"Error: Email adderess is empty or too short. Please try again."\033[0m"
    craeteAcmeEmail
  fi
}

proxy() {
  # checkSwarm
  createDomain

  network=$(docker network ls --filter name=traefik-public --format {{.Name}})

  # if [ "$network" != "traefik-public" ];then
  #   docker network create --driver overlay traefik-public
  # fi

  overlay=$(docker network ls --filter name=traefik-public --filter driver=overlay --format {{.Name}})

  if [ "$network" = "traefik-public" ] && [ "$overlay" != "traefik-public" ];then
    echo "\033[31m"Error: traefik-public network driver is not overlay."\033[0m"
    exit
  fi

  echo "Create traefik auth"
  echo " "
  createAdmin
  craeteAcmeEmail

  hashedPassword=$(openssl passwd -apr1 $password)

  if [ -z $hashedPassword ];then
    echo "\033[31m"Error: Generate hashed password is failed with openssl."\033[0m"
    exit
  fi

  export DOMAIN=$domain
  export USERNAME=$user
  export HASHED_PASSWORD=$hashedPassword
  export EMAIL=$email
  docker stack deploy -c proxy.yml proxy
  exit
}

checkProxy() {
  consulLeader=$(docker service ls --filter name=proxy_consul-leader --format {{.Name}})
  consulReplica=$(docker service ls --filter name=proxy_consul-replica --format {{.Name}})
  traefik=$(docker service ls --filter name=proxy_traefik --format {{.Name}})
  network=$(docker network ls --filter name=traefik-public --filter driver=overlay --format {{.Name}})

  if [ -z $consulLeader ] || [ -z $consulReplica ] || [ -z $traefik ] || [ -z $network ];then
    echo "\033[31m"Error: proxy stack must be recreate. Please check proxy stack and recreate."\033[0m"
    exit
  fi
}

swarmprom() {
  checkSwarm
  createDomain
  checkProxy

  echo "slack webhook url for alert (option): "\\c
  read slackUrl

  echo "slack channel name for alert (option): "\\c
  read slackChannel

  echo "slack user name for alert (option): "\\c
  read slackUser

  echo "Crate grafana account."
  echo " "
  createAdmin

  export SLACK_URL=$slackUrl
  export SLACK_CHANNEL=$slackChannel
  export SLACK_USER=$slackUser

  export USERNAME=$user
  export PASSWORD=$password

  export DOMAIN=$domain
  docker stack deploy -c swarmprom.yml swarmprom

  grafana=$(docker service ls --filter name=swarmprom_grafana --format {{.Replicas}})
  prometheus=$(docker service ls --filter name=swarmprom_prometheus --format {{.Replicas}})
  alertmanager=$(docker service ls --filter name=swarmprom_alertmanager --format {{.Replicas}})

  if [ ${grafana:0:1} = 0 ] && [ ${prometheus:0:1} = 0 ] && [ ${alertmanager:0:1} = 0 ];then
    echo "\033[31m"Error: Can not deploy grafana, prometheus and alertmanager. Please add label \'swarmprom=true\' at one of worker node."\033[0m"
    echo "\033[31m"Start remove swarmprom stack."\033[0m"
    docker stack rm swarmprom
    exit
  fi

  portainer=$(docker service ls --filter name=swarm_portainer --format {{.Replicas}})

  if [ ${portainer:0:1} = 0 ];then
    echo "\033[31m"Error: Can not deploy portainer. Please add label \'portainer.portainer-data=true\' at one of manager node."\033[0m"
    echo "\033[31m"Start remove swarmprom stack."\033[0m"
    docker stack rm swarmprom
  fi
  exit
}

fMenu() {
  echo "menu"
  echo " "
  echo "    1. deploy proxy stack"
  echo "    2. deploy swarmprom stack"
}

unexpected() {
  clear
  echo "\033[31m"Error: Unexpected input. Please try again."\033[0m"
  echo " "
}

clear

while :
do
  fMenu
  echo " "
  echo "Please select menu. (Exit: q): "\\c
  read MenuNo
  case "$MenuNo" in
    "q" ) exit ;;
    "1" ) proxy ;;
    "2" ) swarmprom ;;
    "3" ) staging ;;
    "4" ) production ;;
    * ) unexpected ;;
  esac
done
