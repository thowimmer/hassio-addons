#!/bin/bash

OPTIONS_PATH=/data/options.json
CONFIGURATION_YAML_PATH=/config/configuration.yaml
SECRETS_YAML_PATH=/config/secrets.yaml
PRIVATE_KEY_FILE_PATH=/data/id_rsa

SECRET_PREFIX_REGEX=^!secret\s*
HASS_PORT_IDENTIFIER=http.server_port
HASS_DEFAULT_PORT=8123

HOST=$(jq --raw-output ".host" $OPTIONS_PATH)
USER=$(jq --raw-output ".user" $OPTIONS_PATH)
REMOTE_SSH_PORT=$(jq --raw-output ".remoteSSHPort" $OPTIONS_PATH)
REMOTE_TUNNEL_PORT=$(jq --raw-output ".remoteTunnelPort" $OPTIONS_PATH)
SERVER_ALIVE_INTERVAL=$(jq --raw-output ".serverAliveInterval" $OPTIONS_PATH)
SERVER_ALIVE_COUNT_MAX=$(jq --raw-output ".serverAliveCountMax" $OPTIONS_PATH)
PRIVATE_KEY=$(jq --raw-output ".privateKey" $OPTIONS_PATH)

# ------------------------------------------------------------------------------
# Reads the value of the secret from the secrets.yaml in case the given string
# is a secret value identifier (!<some-secret-identifier>), or returns the given
# string as is otherwise.
#
# Arguments:
#   $1 the secret value identifier or the actual secret value.
# Returns:
#   The value of the secret.
# ------------------------------------------------------------------------------
function getSecret {
  if [[ $1 =~ $SECRET_PREFIX_REGEX ]]; then
    SECRET=$(getSecretFromSecretsYaml "$1") || return -1
    echo -e "$SECRET"
  else
    echo -e "$1"
  fi
}

function getSecretFromSecretsYaml {
  if [ ! -e $SECRETS_YAML_PATH ]; then
    echo secrets.yaml not found >&2
    return -1
  fi

  SECRET_NAME=$(echo "$1" | sed "s/$SECRET_PREFIX_REGEX//")
  SECRET=$(./yq r $SECRETS_YAML_PATH $SECRET_NAME)

  if [ "$SECRET" = "null" ]; then
    echo "$SECRET_NAME not found in secrets.yaml" >&2
    return -1
  fi

  echo -e "$SECRET"
}

function getHassPort {
  if [ ! -e $CONFIGURATION_YAML_PATH ]; then
    echo configuration.yaml not found >&2
    return -1
  fi

  HASS_PORT=$(./yq r $CONFIGURATION_YAML_PATH $HASS_PORT_IDENTIFIER)

  if [ "$HASS_PORT" = "null" ]; then
    echo $HASS_DEFAULT_PORT
  else
    echo $HASS_PORT
  fi
}

USER_SECRET=$(getSecret "$USER") || exit 1
PRIVATE_KEY_SECRET=$(getSecret "$PRIVATE_KEY") || exit 1
HASS_PORT=$(getHassPort) || exit 1

echo -e "$PRIVATE_KEY_SECRET" > "$PRIVATE_KEY_FILE_PATH"
chmod 600 $PRIVATE_KEY_FILE_PATH

echo Starting AutoSSH reverse tunnel through host $HOST

autossh \
-M 0 \
-o ServerAliveInterval=$SERVER_ALIVE_INTERVAL \
-o ServerAliveCountMax=$SERVER_ALIVE_COUNT_MAX \
-o ExitOnForwardFailure=yes \
-o StrictHostKeyChecking=no \
-i $PRIVATE_KEY_FILE_PATH \
-N \
-p $REMOTE_SSH_PORT \
-R $REMOTE_TUNNEL_PORT:localhost:$HASS_PORT $USER_SECRET@$HOST
