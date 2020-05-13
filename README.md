# [ZEVENET Load Balancer](https://www.zevenet.com)
This is the repository of **ZEVENET Load Balancer** Community Edition (**Zen Load Balancer** CE next generation) and it'll guide you to install a development and testing instance of load balancer.

## Repository Contents
In this repository you'll find the source code usually placed into the folder `/usr/local/zevenet/` with the following structure:
- **app/**: Applications, binaries and libraries that ZEVENET Load Balancer requires.
- **bin/**: Additional application binaries directory. 
- **backups/**: Default folder where the configuration backups will be placed.
- **config/**: Default folder where the load balancing services, health checks and network configuration files will be placed.
- **etc/**: Some system files to configure ZEVENET Load Balancer services.
- **lib/**: Folder where Zevenet funcionality library is located.
- **share/**: Folder for templates and other data.
- **www/**: Backend API source files of ZEVENET Load Balancer.
- *other*: License and this readme information.
And `/usr/share/perl5/Zevent` with the entire Zevenet backend core.

## ZEVENET Load Balancer Installation and Updates
Currently, there is only available package for Debian Buster, the installation is not supported out of this operating system.

### Requirements
Please, take into account these requirements before installing the load balancer:

1. You'll need at least 1,5 GB of storage.

2. Install a fresh and basic Debian Buster (64 bits) system with *openssh* and the basic system tools package recommended during the distribution installation.

3. Configure the load balancer with a static IP address. ZEVENET Load Balancer doesn't support DHCP yet.

4. Configure the *apt* repositories in order to be able to install some dependencies.

### Installation on Debian Buster
Get a Debian ISO installable from [debian.org](https://www.debian.org/distrib/). This installation process has been only tested with the 64 bits version.

This git repository only contains the source code, the installable packages based in this code are updated in our Zevenet APT repos, you can use them configuring your Debian Baster system as follows: 

```
root@zevenetlb#> wget -O - http://repo.zevenet.com/zevenet.com.gpg.key | apt-key add -

```
Now, update the local APT database
```
root@zevenetlb#> apt-get update
```
And finally, install the Zevenet CE
```
root@zevenetlb#> apt-get install zevenet
```
### Updates
Please use the Zevenet APT repo in order to check if updates are available. 


## How to Contribute
You can contribute with the evolution of the ZEVENET Load Balancer in a wide variety of ways:

- **Creating content**: Documentation in the [GitHub project wiki](https://github.com/zevenet/zlb/wiki), doc translations, documenting source code, etc.
- **Help** to other users through the mailing lists.
- **Reporting** and **Resolving Bugs** from the [GitHub project Issues](https://github.com/zevenet/zlb/issues).
- **Development** of new features.

### Reporting Bugs
Please use the [GitHub project Issues](https://github.com/zevenet/zlb/issues) to report any issue or bug with the software. Try to describe the problem and a way to reproduce it. It'll be useful to attach the service and network configurations as well as system and services logs.

### Development & Resolving Bugs
In order to commit any change, as new features, bug fix or improvement, just perform a `git clone` of the repository, `git add` when all the changes has been made and `git commit` when you're ready to send the change.

During the submit, please ensure that every change is associated to a *logical change* in order to be easily identified every change.

In the commit description please use the following format:
```
[CATEGORY] CHANGE_SHORT_DESCRIPTION

OPTIONAL_LONGER_DESCRIPTION

SIGNED_OFFS

MODIFIED_FILES
```

Where:
- `CATEGORY` is either: **Bugfix** for resolving bugs or issues, **Improvement** for enhancements of already implemented features or **New Feature** for new developments that provides a new feature not implemented before.
- `CHANGE_SHORT_DESCRIPTION` is a brief description related with the change applied and allows to identify easily such modification. If it's related to a bug included in the Issues section it's recommended to include the identification reference for such bug.
- `OPTIONAL_LONGER_DESCRIPTION` is an optional longer description to explain details about the change applied.
- `SIGNED_OFFS` is the `Signed-off-by` entry where the username followed by the email can be placed.
- `MODIFIED_FILES` are the list of files that hace been modified, created or deleted with the commit.

Usually, executing `git commit -a -s` will create the fields described above.

Finally, just execute a `git push` and request a pull of your changes. In addition, you can use `git format-patch` to create your patches and send them through the official distribution list.

### Creating & Updating Documentation or Translations
In the official [GitHub wiki](https://github.com/zevenet/zlb/wiki) there is available a list of pages and it's translations. Please clone the wiki, apply your changes and request a pull in order to be applied.

### Helping another Users
The official distribution list could be accessed through the [zevenet-ce-users google group](https://groups.google.com/a/zevenet.com/group/zevenet-ce-users/).

To post in this group, send email to [zevenet-ce-users@zevenet.com](mailto:zevenet-ce-users@zevenet.com).

But **you need to request a join** first into the group by sending an email to [zevenet-ce-users+subscribe@zevenet.com](mailto:zevenet-ce-users+subscribe@zevenet.com).

To unsubscribe from this group, send email to zevenet-ce-users+unsubscribe@zevenet.com

For more options, visit https://groups.google.com/a/zevenet.com/d/optout


## [www.zevenet.com](https://www.zevenet.com)

