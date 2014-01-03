#
# For more information about Vagrantfile options and provisiones, see
# http://docs.vagrantup.com/v2/vagrantfile/
#
# OS autentication: vagrant / vagrant
#

Vagrant.configure("2") do |config|
  
  config.vm.box = "frontstack"
  
  #
  # configure your box image
  #
  # CentOS 6.5 minimal + VBox Adititions
  # OS release info: https://gist.github.com/casr/e89d304aa46918bbae49
  config.vm.box_url = "http://sourceforge.net/projects/frontstack/files/images/centos65-x86_64-20131219.box/download"
  # Docker-ready image (future use)
  #config.vm.box_url = "http://nitron-vagrant.s3-website-us-east-1.amazonaws.com/vagrant_ubuntu_12.04.3_amd64_virtualbox.box"

  #
  # ports to fordward (customize to your needs)
  #
  config.vm.network :forwarded_port, guest: 3000, host: 3000
  config.vm.network :forwarded_port, guest: 3001, host: 3001
  config.vm.network :forwarded_port, guest: 3002, host: 3002
  config.vm.network :forwarded_port, guest: 3003, host: 3003
  config.vm.network :forwarded_port, guest: 3010, host: 3010
  config.vm.network :forwarded_port, guest: 3011, host: 3011
  config.vm.network :forwarded_port, guest: 3443, host: 3443
  config.vm.network :forwarded_port, guest: 35729, host: 35729

  config.ssh.forward_agent = true

  #
  # Guest resources and custom configuration
  # do not edit 
  # 
  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--memory", 768]
    v.customize ["modifyvm", :id, "--name", "FrontStack VM"]
    v.customize ["modifyvm", :id, "--ioapic", "on" ]
    v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
    v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/workspace", "1"]
  end

  #
  # shared directories between guest and host
  #
  config.vm.synced_folder "./workspace", "/home/vagrant/workspace", id: "workspace"
  config.vm.synced_folder "./scripts", "/home/vagrant/scripts", id: "scripts"

  #
  # Provision package
  # Do not delete if you don't know exactly what you are doing
  #
  config.vm.provision "shell" do |s|
    s.path = "scripts/setup.sh"
  end

end