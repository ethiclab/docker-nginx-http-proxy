#!/bin/bash

#######################################################################################
# BEGIN: utilities from https://github.com/montoyaedu/Trish/blob/master/test_tools.sh #
#######################################################################################

CAT=$(which cat)

function read_input {
    "${CAT}" -
}

function debug {
    $(>&2 echo $@)
}

function is {
    local -r actual=$(read_input)
    local -r expected="${@}"
    if [ "${actual}" == "${expected}" ]; then
        return 0
    else
        debug "expected '${expected}' but got '${actual}'"
        return 1
    fi
}

#####################################################################################
# END: utilities from https://github.com/montoyaedu/Trish/blob/master/test_tools.sh #
#####################################################################################

function __easy_command_proxy_help {
 echo "usage:"
 echo "    easy proxy create"
 echo "    easy proxy sh"
 echo "    easy proxy log"
 echo "    easy proxy build"
 echo "    easy proxy new"
 echo "    easy proxy id"
 echo "    easy proxy status"
 echo "    easy proxy start"
 echo "    easy proxy stop"
 echo "    easy proxy destroy"
 echo "    easy proxy restart"
 echo "    easy proxy reload"
 echo "    easy proxy certbot"
 echo "    easy proxy rfc2136"
 echo "    easy proxy help"
}

function __easy_command_proxy {
 if [[ -z "${EASY_DIR}" ]]; then
  echo "Invalid EASY_DIR"
  return 1
 fi
 if [[ "create" == "$2" ]]; then
   __easy_command_proxy_create
   return $?
 fi
 if [[ "help" == "$2" ]]; then
   __easy_command_proxy_help
   return $?
 fi
 if [[ "rfc2136" == "$2" ]]; then
  if [[ -z "${EASY_LETSENCRYPT_EMAIL}" ]]; then
   echo "Invalid Email. Set environment variable EASY_LETSENCRYPT_EMAIL"
   return 1
  fi
  if [[ -z "${EASY_LETSENCRYPT_DOMAIN}" ]]; then
   echo "Invalid Domain. Set environment variable EASY_LETSENCRYPT_DOMAIN"
   return 1
  fi
  docker run --rm -i --name certfbot -v "${EASY_LETSENCRYPT_DIR}:/etc/letsencrypt" certbot/dns-rfc2136 certonly --renew-by-default --dns-rfc2136-credentials /etc/letsencrypt/secret.txt --dns-rfc2136 -d "${EASY_LETSENCRYPT_DOMAIN},*.${EASY_LETSENCRYPT_DOMAIN}" --agree-tos
  return $?
 fi
 if [[ "certbot" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  if [[ -z "${EASY_LETSENCRYPT_EMAIL}" ]]; then
   echo "Invalid Email. Set environment variable EASY_LETSENCRYPT_EMAIL"
   return 1
  fi
  if [[ -z "${EASY_LETSENCRYPT_DOMAIN}" ]]; then
   echo "Invalid Domain. Set environment variable EASY_LETSENCRYPT_DOMAIN"
   return 1
  fi
  docker exec -it "${EASY_PROXY}" sudo certbot --email ${EASY_LETSENCRYPT_EMAIL} --agree-tos --manual-public-ip-logging-ok certonly --manual --preferred-challenges dns -d "${EASY_LETSENCRYPT_DOMAIN},*.${EASY_LETSENCRYPT_DOMAIN}"
  return $?
 fi
 if [[ "reload" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  docker exec -it "${EASY_PROXY}" sudo nginx -c /usr/local/share/easy/nginx.conf -s reload
  return $?
 fi
 if [[ "build" == "$2" ]]; then
  docker build "${EASY_DIR}" -t ethiclab/nginx-easy
  return $?
 fi
 if [[ "new" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  if [[ "$#" -ne 6 ]]; then
   echo "Too few arguments"
   echo "Usage:"
   echo "    easy proxy new [http|https] <fully qualified servername> <domain> <http target server>"
   echo "For instance:"
   echo "    easy proxy new http myserver.mydomain.com mydomain.com http://someserver:someport"
   return 1
  fi
  if [[ "http" == "$3" ]]; then
   docker exec -it "${EASY_PROXY}" /usr/local/share/easy/add_subdomain_http $4 $5 $6
  elif [[ "https" == "$3" ]]; then
   docker exec -it "${EASY_PROXY}" /usr/local/share/easy/add_subdomain_https $4 $5 $6
  else
   echo "Invalid protocol $3"
   return 1
  fi
  return $?
 fi
 if [[ "sh" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy id)
  docker exec -it "${EASY_PROXY}" bash
  return $?
 fi
 if [[ "log" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy id)
  docker logs -f "${EASY_PROXY}" 
  return $?
 fi
 if [[ "destroy" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy id)
  docker stop "${EASY_PROXY}"
  docker rm "${EASY_PROXY}"
  rm $EASY_DIR/.id
  return $?
 fi
 if [[ "start" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy id)
  docker start "${EASY_PROXY}" 
  return $?
 fi
 if [[ "stop" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy id)
  docker stop "${EASY_PROXY}" 
  return $?
 fi
 if [[ "restart" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy id)
  docker restart "${EASY_PROXY}" 
  return $?
 fi
 if [[ "id" == "$2" ]]; then
  [[ -f $EASY_DIR/.id ]] && cat $EASY_DIR/.id
  return $?
 fi
 if [[ "status" == "$2" ]]; then
  [[ -f $EASY_DIR/.id ]] && easy proxy id >/dev/null && docker ps -q -f id=$(easy proxy id)
  return $?
 fi
 if [[ -z "$2" ]]; then
  __easy_command_proxy_default
  return $?
 else
  __easy_command_proxy_help
  return 1
 fi
}

function __easy_command_proxy_create {
 local EASY_PROXY=$(easy proxy id)
 if [[ ! -z "${EASY_PROXY}" ]]; then
  echo "There is already an easy proxy instance with docker id ${EASY_PROXY}"
  return 1
 fi
 if [[ -z "${EASY_LETSENCRYPT_DIR}" ]]; then
  echo "Invalid EASY_LETSENCRYPT_DIR"
  return 1
 fi
 local CONTAINER_ID=$(docker run -d \
 -v ${EASY_DOMAINS_DIR}:/domains \
 -v ${EASY_LETSENCRYPT_DIR}:/etc/letsencrypt \
 -v ${EASY_DIR}/easyhome:/usr/local/share/easy \
 -p 80:80 \
 -p 443:443 \
 -t ethiclab/nginx-easy)
 if [[ "$?" == "0" ]]; then
   echo $CONTAINER_ID > $EASY_DIR/.id
 fi
 easy proxy id
}

function __easy_command_proxy_default {
  __easy_command_proxy_help
  return 1
}
