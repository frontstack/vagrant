# FrontStack Vagrant

## Usage

1. Be sure you have VirtualBox and Vagrant already installed

2. Customize `Vagrantfile` and `setup.ini` (optionally)

3. From the `Vagrantfile` directory directory, run: 
  
  ```
  $ vagrant up 
  ```

  and if all goes fine, run:
  ```
  $ vagrant ssh
  ```

## Guest requirements

  * GNU/Linux 64 bits
  * 512MB RAM (>=768MB recommended)
  * 1GB free disk space
  * Internet access (HTTP/S)

## Host requirements

  * 64 bits OS
  * 2GB RAM (4GB recommended)
  * 4GB free disk space
  * Internet access (HTTP/S)

## Configuration

See [setup.ini][1] file and adapt it to your needs.
You can comment the options you don't need

## Issues

Please, feel free to report any issue you experiment via Github

## License

Scripts under [WTFPL](http://www.wtfpl.net/txt/copying/) license

[1]: https://github.com/frontstack/vagrant/blob/master/setup/setup.ini