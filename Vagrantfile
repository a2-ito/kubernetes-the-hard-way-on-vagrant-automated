# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

hostname1 = "master1"
ip1 = "192.168.33.11"
hostname2 = "worker1"
ip2 = "192.168.33.12"
hostname3 = "worker2"
ip3 = "192.168.33.13"

script = <<SCRIPT
#rpm -ivh /vagrant/docker/*.rpm
#systemctl start docker 

SCRIPT

Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  #config.vm.box = "minimal/centos7"
  #config.vm.box = "ubuntu/trusty64"
  #config.vm.box = "minimal/jessie64"
  config.vm.box = "bento/ubuntu-18.04"

  #config.vm.box = "CentOS72_x64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  #config.vbguest.auto_update = false
  #config.vbguest.no_remote = true  
  #config.vbguest.iso_path = "../VBoxGuestAdditions_6.0.4.iso"
  #config.vm.synced_folder ".", "/vagrant", disabled: false
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--usb", "on"]
    vb.customize ["modifyvm", :id, "--usbehci", "off"]
  end

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.define hostname1 do |node|
    hostname = hostname1
    ip = ip1

    node.vm.hostname = hostname
    node.vm.network "private_network", ip: ip
    node.vm.network "forwarded_port", guest: 6443, host: 6443, host_ip: "0.0.0.0"

    offset = (ip).split(".")[-1].to_i
    http_port = 8000 + offset
    ssh_port = 2200 + offset
    #node.vm.network "forwarded_port", id: "http", guest: 80, host: http_port
    node.vm.network "forwarded_port", id: "ssh", guest: 22, host: ssh_port

    # provisioning
    node.vm.provision "file", source: "~/.ssh/vagrant-key.pub", destination: "/home/vagrant/.ssh/id_rsa.pub"
    node.vm.provision "file", source: "~/.ssh/vagrant-key", destination: "~/.ssh/id_rsa"
    node.vm.provision "shell", inline: "cat ~vagrant/.ssh/id_rsa.pub >> ~vagrant/.ssh/authorized_keys"
    #node.vm.provision :shell, :inline => script
    node.vm.provision :shell, path: "ssh-config.sh"
    node.vm.provision "shell", inline: "pwd; ls -l"
    node.vm.provision "shell", inline: "cp -pr /vagrant/bootstrap.sh ~vagrant"
    node.vm.provision "shell", inline: "cp -pr /vagrant/scripts/ ~vagrant"
    node.vm.provision "shell", inline: "cp -pr /vagrant/manifests/ ~vagrant"
  end

  config.vm.define hostname2 do |node|
    hostname = hostname2
    ip = ip2

    node.vm.hostname = hostname
    node.vm.network "private_network", ip: ip
    #node.vm.network "forwarded_port", guest: 6443, host: 6443, host_ip: "0.0.0.0"

    offset = (ip).split(".")[-1].to_i
    http_port = 8000 + offset
    ssh_port = 2200 + offset
    #node.vm.network "forwarded_port", id: "http", guest: 80, host: http_port
    node.vm.network "forwarded_port", id: "ssh", guest: 22, host: ssh_port

    node.vm.provision "file", source: "~/.ssh/vagrant-key.pub", destination: "~/.ssh/id_rsa.pub"
    node.vm.provision "file", source: "~/.ssh/vagrant-key", destination: "~/.ssh/id_rsa"
    node.vm.provision "shell", inline: "cat ~vagrant/.ssh/id_rsa.pub >> ~vagrant/.ssh/authorized_keys"
    node.vm.provision :shell, path: "ssh-config.sh"
    #node.vm.provision :shell, path: "bootstrap.sh"
  end

  config.vm.define hostname3 do |node|
    hostname = hostname3
    ip = ip3

    node.vm.hostname = hostname
    node.vm.network "private_network", ip: ip
    #node.vm.network "forwarded_port", guest: 6443, host: 6443, host_ip: "0.0.0.0"

    offset = (ip).split(".")[-1].to_i
    http_port = 8000 + offset
    ssh_port = 2200 + offset
    #node.vm.network "forwarded_port", id: "http", guest: 80, host: http_port
    node.vm.network "forwarded_port", id: "ssh", guest: 22, host: ssh_port

    # provisioning
    node.vm.provision "file", source: "~/.ssh/vagrant-key.pub", destination: "~/.ssh/id_rsa.pub"
    node.vm.provision "file", source: "~/.ssh/vagrant-key", destination: "~/.ssh/id_rsa"
    node.vm.provision "shell", inline: "cat ~vagrant/.ssh/id_rsa.pub >> ~vagrant/.ssh/authorized_keys"
    node.vm.provision :shell, path: "ssh-config.sh"
    #node.vm.provision :shell, path: "bootstrap.sh"
  end


  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  #config.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
  #  vb.gui = true
  
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  #end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL


end
