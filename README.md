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
  * 2GB of hard disk
  * Internet access (HTTP/S)

## Host requirements

  * 64 bits OS
  * 2 GB of RAM (4 GB recommended)
  * 4 GB of hard disk
  * Internet access (HTTP/S)

## setup.ini options

See `setup.ini` file. You should remove the config options you don't need.

In order to use it, you must rename it to `setup.ini`.

## Issues

FrontStack is in beta stage, some things maybe are broken.
Please, feel free to report any issue you experiment via Github.

## License

Scripts under [WTFPL](http://www.wtfpl.net/txt/copying/) license
