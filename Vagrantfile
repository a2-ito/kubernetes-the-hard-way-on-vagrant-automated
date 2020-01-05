# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

hostname = "node1"
ip = "192.168.33.11"
hostname2 = "node2"
ip2 = "192.168.33.12"
hostname3 = "node3"
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
  config.vm.box = "generic/centos7"
  #config.vm.box = "ubuntu/trusty64"
  #config.vm.box = "bento/ubuntu-18.04"

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
  #config.vbguest.iso_path = "/mnt/d/mywork/linux_home/a2-ito/vagrant/VBoxGuestAdditions_6.0.4.iso"
  config.vbguest.iso_path = "/mnt/d/mywork/linux_home/a2-ito/vagrant/VBoxGuestAdditions_5.2.34.iso"
  config.vm.synced_folder ".", "/vagrant", disabled: false

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.define "node1" do |node1|
    node1.vm.hostname = hostname
    node1.vm.network "private_network", ip: ip
    node1.vm.network "forwarded_port", guest: 6443, host: 6443, host_ip: "0.0.0.0"

    # provisioning
    node1.vm.provision "file", source: "~/.ssh/keys/vagrant-key.pub", destination: "/home/vagrant/.ssh/id_rsa.pub"
    node1.vm.provision "file", source: "~/.ssh/keys/vagrant-key", destination: "~/.ssh/id_rsa"
    node1.vm.provision "shell", inline: "cat ~vagrant/.ssh/id_rsa.pub >> ~vagrant/.ssh/authorized_keys"
    #node1.vm.provision :shell, :inline => script
    node1.vm.provision :shell, path: "ssh-config.sh"
  end

  config.vm.define "node2" do |node|
    node.vm.hostname = hostname2
    node.vm.network "private_network", ip: ip2
    #node.vm.network "forwarded_port", guest: 6443, host: 6443, host_ip: "0.0.0.0"

    node.vm.provision "file", source: "~/.ssh/keys/vagrant-key.pub", destination: "~/.ssh/id_rsa.pub"
    node.vm.provision "file", source: "~/.ssh/keys/vagrant-key", destination: "~/.ssh/id_rsa"
    node.vm.provision "shell", inline: "cat ~vagrant/.ssh/id_rsa.pub >> ~vagrant/.ssh/authorized_keys"
    node.vm.provision :shell, path: "ssh-config.sh"
    #node.vm.provision :shell, path: "bootstrap.sh"
  end

#  config.vm.define "node3" do |node3|
#    node3.vm.hostname = hostname3
#    node3.vm.network "private_network", ip: ip3
    #node3.vm.network "forwarded_port", guest: 6443, host: 6443, host_ip: "0.0.0.0"

    # provisioning
#    node3.vm.provision "file", source: "~/.ssh/keys/vagrant-key.pub", destination: "~/.ssh/id_rsa.pub"
#    node3.vm.provision "file", source: "~/.ssh/keys/vagrant-key", destination: "~/.ssh/id_rsa"
#    node3.vm.provision "shell", inline: "cat ~vagrant/.ssh/id_rsa.pub >> ~vagrant/.ssh/authorized_keys"
#    node3.vm.provision :shell, path: "ssh-config.sh"
#  end


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
