# AutoSSH reverse tunnel addon for Hass.io

# About
This addon enables remote access to Home Assistant via an [AutoSSH](https://linux.die.net/man/1/autossh) reverse tunnel.

This is useful when you do NOT want to expose your Hassio machine via port forwarding in your home network as described in the [Home Assistant documentation]( https://www.home-assistant.io/docs/configuration/remote/):

## Pros & Cons over port forwarding in your home network
### Pros
* No configuration of your home network / router required
* Turn-off remote access by simply stopping this addon
* Benefit from security infrastructure & configuration of your remote server provider
 * Firewall configuration
 * DDoS prevention
 * ...

### Cons
* Additional public accessible Linux machine required

# Prerequisite
Since this addon deals with SSH tunneling and web proxying the following
setup is necessary:

* Linux machine which is public accessible from the World Wide Web.
  * **Note:** I'm using a virtual Debian 9.4 instance but every common Linux distribution
  should be fine
  * Any cheap vServer intance (e.g. AWS EC2) will be enough

* OpenSSH server installed on this machine.  

# Installation
## 1. Create a restricted SSH User for SSH tunneling only
The first part of the installation describes how to set up an SSH user
which is only capable to perform SSH tunneling. For security reasons I
I recommend to setup a dedicated SSH user for this addon. Nevertheless you can
use any SSH user which is able to perform SSH tunneling using SSH-key based
authentication.

### 1.1 Create an user on the remote machine
First of all we have to create a new user on the remote machine which we will
be using for this addon:
```
$ sudo useradd -m limited-user
```

### 1.2 Create a new SSH key for the user on the remote machine
The next step is to create a new SSH key for the this user.
We do not set a passphrase for the private key since we don't want to enter this
passphrase always during the start of the addon.
```
$ sudo su limited-user
$ ssh-keygen -t rsa -b 4096 -C "AutoSSH reverse tunnel key"
Generating public/private rsa key pair.
Enter file in which to save the key (/home/limited-user/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/limited-user/.ssh/id_rsa.
Your public key has been saved in /home/limited-user/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:xoLvPuicrMMu4HhNiEHxvj1gMx8pzVj3eLEBZHFrr/o AutoSSH reverse tunnel key
The key's randomart image is:
+---[RSA 4096]----+
| ..   .=..       |
| ..   . o .      |
|.  . . . =       |
|. . =.o.+ =      |
| o X.=..S+ .     |
|o o X..o. .      |
|+. + =.  .       |
|o.+oooo .        |
| +o+=.oo.E       |
+----[SHA256]-----+
```
**Note:** It is common practice to disable Password Authentication for SSH.
Therefore this addon only supports SSH-key based authentication.

### 1.3 Add the public key to authorized_keys file of the limited-user
Next
```
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
```

### 1.4 Apply restrictions in /etc/ssh/sshd_config
At this stage you have a new SSH user which is able to perform any SSH
operations as configured in your SSH server.
But since our newly created user should only be able to do a SSH tunneling
we override the SSH configuration for this user in the /etc/ssh/sshd_config
file:

```
Match User limited-user
  AllowTcpForwarding yes
  X11Forwarding no
  PermitTunnel no
  GatewayPorts no
  AllowAgentForwarding no
  PermitOpen localhost:<port>
  ForceCommand echo 'This account can be used for reverse tunnel only'
```
For further explanation of this configuration see [this AskUbuntu answer](https://askubuntu.com/a/50000).

**Note:** Replace `<port>` with the remoteTunnelPort.

### 1.5 Set ClientAliveInterval & ClientAliveCountMax
In order to prevent that dead SSH tunnels are not recognized by the SSH Server
I recommend to set the [ClientAliveInterval](https://man.openbsd.org/sshd_config#ClientAliveInterval) and  [ClientAliveCountMax](https://man.openbsd.org/sshd_config#ClientAliveCountMax)  in the /etc/ssh/sshd_config file:
```
ClientAliveInterval 30
ClientAliveCountMax 1
```
This ensures that the SSH server closes the connection to the client if there has been no answers to client alive messages for 30 seconds.

This is especially useful for long living persistent SSH connections to clients with dynamic IPs.

You can configure the according client side properties in the addon configuration.

> I ran into scenarios where AutoSSH was not able to reastablish a new SSH connection after an IP change of my Internet Service Provider since the connection drop was not recognized on the SSH Server. Setting this options on the server side fixed this issue.

### 1.6 Restart the SSH daemon
Finally we have to restart the SSH daemon so that the change configuration is
applied on the SSH server:
```
sudo service ssh restart
```
**Note:** This command is valid for Ubuntu machines. Please check for the
distribution of your remote machine.

## 2. Reverse proxy setup
Now that we have our SSH tunneling setup in place, the next step is to setup
a reverse proxy on our remote machine.
For a lightweight and easy setup I recommend using the [Caddy](https://caddyserver.com/)
web server for the following reasons:
* HTTPS by default !
  * This is a MUST whenever exposing a service to the public web (especially for home automation)
  * You don't have to deal with certificates on your own. Everything is managed by Caddy transparently using Let's Encrypt.
  * Free and trusted Let's Encrypt certificates.
* No dependencies
    * Caddy consists of statically compiled Go binaries whereby no additional runtime environment is required.
* Easy for beginners
  * You have an up and running reverse proxy in a few minutes even if you did not worked
  with webservers before - Trust me ;-)
* See https://caddyserver.com/features for further features

Therefore I will describe how to setup a reverse proxy using Caddy. However there are many ways how to setup a reverse proxy using other major webservers or reverse proxy software, which can be used to achieve an identical setup.

### 2.1 Install Caddy
The Caddy website has an excellent documentation to get quickly started:
https://caddyserver.com/tutorial.
I used the [official Docker Image](https://hub.docker.com/r/abiosoft/caddy/) to setup Caddy in a Docker container, but this is just a personal preference.

### 2.2 Create reverse proxy in Caddyfile
Once Caddy is intalled we add a reverse proxy configuration in our Caddyfile
which forwards all requests to our tunnel:
```
<some.host.com> {
     proxy / 127.0.0.1:<port> {
        websocket
        transparent
    }
}
```
**Note:**
* Replace `<some.host.com>` with the base URL under which the Home Assistant instance should be reachable.
* Replace `<port>` with the remoteTunnelPort.

## 3. Reverse proxy setup

### Configuration

```json
{
  "host": "some.host.com",
  "user": "!secret reverse_tunnel_user",
  "privateKey": "!secret reverse_tunnel_private_key",
  "remoteSSHPort": 22,
  "remoteTunnelPort": 8123,
  "serverAliveInterval": 30,
  "serverAliveCountMax": 1
}
```
### Required Configuration

#### Option: `host`
The host address of the remote machine.

#### Option: `user`
The SSH user name. (See [Installation](#1.3-create-an-user-on-the-remote-machine)).

**Note**: This option support secrets, e.g., `!secret reverse_tunnel_user`.

#### Option: `privateKey`
The SSH private key used for tunneling. (See [Installation](#1.3-create-an-user-on-the-remote-machine)).

**Note**: Multiline private keys (as in standard private key files) are not supported ! Use `TODO command` to convert a private key file into a single line string supported by this addon.

**Note**: This option support secrets, e.g., `!secret reverse_tunnel_private_key`.

### Optional Configuration

#### Option: `remoteSSHPort`
SSH port used for remote tunneling.

**Default** `22`

#### Option: `remoteTunnelPort`
The port where the Home Assistant instance is exposed on the remote machine.

**Default** `8123`

#### Option: `serverAliveInterval`
Timeout interval in seconds after which a message will be sent to the server if no data has been received by the server. (See [OpenSSH docs](https://man.openbsd.org/ssh_config.5#ServerAliveInterval))

**Default** `30`

#### Option: `serverAliveCountMax`
Number of unanswered server alive messages after which the client will terminate the SSH connection. (See [OpenSSH docs](https://man.openbsd.org/ssh_config.5#ServerAliveCountMax))

**Default** `1`

**Example**: If `serverAliveInterval` is 30 and `serverAliveCountMax` is 2 the client will close the connection after 60 seconds if there was no answer from the server. The addon will automatically try to reestablish a connection in this case.
