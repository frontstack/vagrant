# provisining and setup script
$provisionScript = <<SCRIPT
/home/vagrant/scripts/setup.sh
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "fronstack"
  config.vm.box_url = "https://dl.dropbox.com/u/7225008/Vagrant/CentOS-6.3-x86_64-minimal.box"

  #config.vm.network :private_network, ip: "192.168.56.101"

  # port forwarding
  config.vm.network :forwarded_port, guest: 3000, host: 3000
  config.vm.network :forwarded_port, guest: 3001, host: 3001
  # livereload
  config.vm.network :forwarded_port, guest: 35729, host: 35729

  config.ssh.forward_agent = true

  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--memory", 1024]
    v.customize ["modifyvm", :id, "--name", "FrontStack VM"]
  end

  config.vm.synced_folder "./workspace", "/home/vagrant/workspace", id: "workspace"
  config.vm.synced_folder "./scripts", "/home/vagrant/scripts", id: "scripts"

  #config.vm.provision :shell, :path => "scripts/setup.sh"
  config.vm.provision :shell, :inline => $provisionScript
end
