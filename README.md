# ZEVENET Load Balancer
This is the repository of **ZEVENET Load Balancer** Community Edition (**Zen Load Balancer** CE next generation).

## Repository Contents
In this repository you'll find the source code usually placed into the folder `/usr/local/zenloadbalancer/` with the following structure:
- **app/**: Applications, binaries and libraries that ZEVENET Load Balancer requires.
- **backups/**: Default folder where the configuration backups will be placed.
- **config/**: Default folder where the load balancing services, health checks and network configuration files will be placed.
- **etc/**: Some system files to configure ZEVENET Load Balancer services.
- **logs/**: Default folder where the logs will be placed.
- **www/**: Frontend and Backend source files of ZEVENET Load Balancer.
- **zlb-debian-installer.sh**: Script to automate the installation of ZEVENET Load Balancer over a Fresh Debian Jessie installation.
- *other*: License and this readme information.

## ZEVENET Load Balancer Installation
Currently, there is only available the installer for Debian Jessie.

### Requirements
Please, take into account these requirements before installing the load balancer:
1. You'll need at least 1,5 GB of storage.
2. Install a fresh and basic Debian Jessie (32 bits) system with *openssh* and the basic system tools package recommended during the distro installation.
3. Configure the load balancer with a static IP address. ZEVENET Load Balancer doesn't support DHCP yet.
4. Configure the *apt* repositories in order to be able to install some dependencies.

### Debian Jessie Installation
Get a Debian ISO installable from [debian.org](https://www.debian.org/distrib/). This installation process has been only tested with the 32 bits version.

Follow the instructions to fully install the distro, taking care of the requirements listed above.

Once a fresh installation has been finished, reboot the system and login with *root* user. Execute the following commands in a shell terminal in order to install the *git* package and run the ZEVENET Load Balancer installer.
```
apt-get install git
cd /usr/local
git clone https://github.com/zevenet/zlb.git
cd /usr/local/zlb
./zlb_debian_installer.sh
```
The installer script will install all the dependencies from the *apt* repository, it'll migrate the network configuration and some perl libraries from *CPAN*. Answer *yes* to all questions to proceed with the installation of every component.

