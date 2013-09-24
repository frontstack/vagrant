#
# For more information about Vagrantfile options and provisiones, see
# http://docs.vagrantup.com/v2/vagrantfile/
#

Vagrant.configure("2") do |config|
  config.vm.box = "fronstack"
  # configure your box image
  config.vm.box_url = "https://dl.dropbox.com/u/7225008/Vagrant/CentOS-6.3-x86_64-minimal.box"

  # sample port forward
  config.vm.network :forwarded_port, guest: 3000, host: 3000

  config.ssh.forward_agent = true

  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--memory", 1024]
    v.customize ["modifyvm", :id, "--name", "FrontStack VM"]
  end

  config.vm.synced_folder "./workspace", "/home/vagrant/workspace", id: "workspace"
  config.vm.synced_folder "./scripts", "/home/vagrant/scripts", id: "scripts"

  config.vm.provision "shell" do |s|
    s.path = "scripts/setup.sh"
    s.args   = "'/home/vagrant/scripts/setup.ini'"
  end

end
