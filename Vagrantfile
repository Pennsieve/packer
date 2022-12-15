# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX = "ubuntu/bionic64"
CPUS = "2"
HOST_NAME = "puppettest"
MEMORY = "2048"
PRIVATE_IP = "192.168.7.7"

#########################
# Vagrant Configuration #
#########################
Vagrant.configure("2") do |config|
  config.vm.box= "#{BOX}"

  config.vm.provider :virtualbox do |vb|
   vb.customize ["guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000]
   vb.customize ["modifyvm", :id, "--memory", MEMORY]
   vb.customize ["modifyvm", :id, "--cpus", CPUS]
   vb.customize ["modifyvm", :id, "--ioapic", "on"]
   vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  config.vm.provision "shell", path: "scripts/install_puppet.sh"
  config.vm.provision "shell", path: "scripts/jenkins.sh"

  config.vm.define "#{HOST_NAME}" do |c|
    c.vm.box = "#{BOX}"
    c.vm.hostname = "#{HOST_NAME}"
    #c.vm.network "forwarded_port", guest: 80, host: 80
    #c.vm.network :private_network,  type: "dhcp"
    c.vm.network :private_network,  ip: PRIVATE_IP
  end

end
