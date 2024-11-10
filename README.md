# ns8-backuppc

## Install

Instantiate the module with:

    add-module ghcr.io/stephdl/backuppc:latest 1

The output of the command will return the instance name.
Output example:

    {"module_id": "backuppc1", "image_name": "backuppc", "image_url": "ghcr.io/stephdl/backuppc:latest"}

## Configure

Let's assume that the mattermost instance is named `backuppc1`.

Launch `configure-module`, by setting the following parameters:
- `host`: a fully qualified domain name for the application
- `http2https`: enable or disable HTTP to HTTPS redirection (true/false)
- `lets_encrypt`: enable or disable Let's Encrypt certificate (true/false)
- ldap_domain: basic for no LDAP authentication or set a valid LDAP domain
- auth_pass: password for basic authentication
- auth_user: user for basic authentication

Example:

```
api-cli run configure-module --agent module/backuppc1 --data - <<EOF
{
    "host": "backuppc.domain.org",
    "http2https": true,
    "lets_encrypt": true,
    "ldap_domain": "domain.org",
    "auth_pass": "password",
    "auth_user": "user"
}
EOF
```

The above command will:
- start and configure the backuppc instance
- configure a virtual host for trafik to access the instance

## Get the configuration
You can retrieve the configuration with

```
api-cli run get-configuration --agent module/backuppc1
```

## Backup

Only the volumes/logs, volumes/conf, and volumes/home directories are included in the NetheServer backup. The volumes/data directory is excluded to prevent the restic backup size from increasing excessively.

## Administrator of the CGI user interface

By default, only `backuppc` and `administrator` are granted administrative privileges in the CGI UI. If you want to add more users, you can define them in the `$Conf{CgiAdminUsers}` setting (Edit config > CGI). For more details, see the [BackupPC Documentation](https://backuppc.github.io/backuppc/BackupPC.html#_conf_cgiadminusers_).

Currently, it is not possible to read the LDAP group name; you must declare all administrators by their username or login.

## test email

Once the mail notification is configured in the cluster, the BackupPC module can send emails. You can test this by sending an email using the command line.

Before testing, ensure the EMailFromUserName setting (found in the BackupPC UI) is correctly set to your email address.

```
runagent -m backuppc1 podman exec backuppc-app su -s /bin/sh backuppc -c '/usr/local/BackupPC/bin/BackupPC_sendEmail -u foo@domain.com'
```

## copy the backuppc rsa key to a linux host

In order to use the rsync server to backup a linux host, yo have to send the rsa keys of backuppc to the remote host, this will allow to identify without password
As a side note, to be able to restore the file and copy without ownership issue, the root user is needed.

```
runagent -m backuppc1  podman exec -ti backuppc-app su -s /bin/sh backuppc
ssh-copy-id -i ~backuppc/.ssh/id_rsa.pub  root@192.168.1.10
```

## rsyncd on your windows client

Download and run cygwin-rsyncd-3.2.3.0_installer.exe to install rsyncd on your WinXX client for doing BackupPC backups.

See the customized version in the BackupPC repository : https://github.com/backuppc/cygwin-rsyncd

Or you can either install the version from cygwin : https://www.cygwin.com/

## login to the container

`runagent -m backuppc1  podman exec -ti backuppc-app bash`

## become the user agent

`runagent -m backuppc1`

## Uninstall

To uninstall the instance:

    remove-module --no-preserve backuppc1

# LDAP discovering

the module can achieve alone to auto discovery the available LDAP provider, it is a mandatory for the self service restoration

## Smarthost setting discovery

Some configuration settings, like the smarthost setup, are not part of the
`configure-module` action input: they are discovered by looking at some
Redis keys.  To ensure the module is always up-to-date with the
centralized [smarthost
setup](https://nethserver.github.io/ns8-core/core/smarthost/) every time
backuppc starts, the command `bin/discover-smarthost` runs and refreshes
the `state/smarthost.env` file with fresh values from Redis.

Furthermore if smarthost setup is changed when backuppc is already
running, the event handler `events/smarthost-changed/10reload_services`
restarts the main module service.

See also the `systemd/user/backuppc.service` file.

This setting discovery is just an example to understand how the module is
expected to work: it can be rewritten or discarded completely.


## Testing

Test the module using the `test-module.sh` script:


    ./test-module.sh <NODE_ADDR> ghcr.io/nethserver/backuppc:latest

The tests are made using [Robot Framework](https://robotframework.org/)

## UI translation

Translated with [Weblate](https://hosted.weblate.org/projects/ns8/).

To setup the translation process:

- add [GitHub Weblate app](https://docs.weblate.org/en/latest/admin/continuous.html#github-setup) to your repository
- add your repository to [hosted.weblate.org]((https://hosted.weblate.org) or ask a NethServer developer to add it to ns8 Weblate project
