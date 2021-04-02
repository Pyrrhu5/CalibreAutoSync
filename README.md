# E-Reader Sync

_The purpose is quite simple: a linux server serving Calibre-server, and I don't want to have to manually ( 🤮 ) transfer my ebooks to it_

This script takes care of, after plugging the e-reader :

1. Mounting it on a specific mount point
2. Fetching and transferring all new e-books since last sync
3. Unmounting the e-reader
4. Playing a sound

A `calibre-server` service running is actually not required, just the `metadata.db`of calibre is good enough.

## Some manual ( 🤮 ) setting-up

I promise, doing it once is enough

### This stuff is needed

`sqlite3 --version`

Otherwise `sudo apt install sqlite3` (I don't use Arch btw)

`aplay --version`

### Mount the device
#### Identify the device

Plug the device, then run `lsusb`, if it's impossible to know which is which, unplug it, rerun the command and compare.

The output should look like this:

```bash
Bus 001 Device 007: ID 2237:4228 Kobo Inc.
```

Take note of the vendor (here, 2237) and product (here, 4228) number

The `/dev/disk` needs to be identified.

**Method 1**
Either `by-label`, the name is explicit enough to guest which one is it (often a device from the same manufacturer will have the same label)
`ls /dev/disk/by-label`


**Method 2**
Or `by-id`
In this case, run (with your own vendor & product numbers)
`lsusb -d 2237:4228 -v | grep iSerial`

Example :
`iSerial                 5 N249850080827`

Then
`ls /dev/disk/by-id | grep N249850080827`
with your own output of the previous command instead of `N...`

Example:
`usb-Linux_File-Stor_Gadget_N249850080827-0:0`

#### Create the mount point

`mkdir /mnt/ereader`

Or whatever the path you want the device to be mounted on


#### Mount

Edit the `fstab` (use `nano` instead of `vim` if you don't know what vim is)

`sudo vim /etc/fstab`

And add a line at the end, adapt the beginning to the method used to identify the device and the mount point

`/dev/disk/by-label/KOBOeReader /mnt/ereader auto default,nofail 0 0`

#### Test it

Mount it first

`sudo mount /mnt/ereader`

Excepting no output

Check the content

`ls /mnt/ereader`

In my case, all the e-books are store directly there and will be recognized up by the reader even if I don't respect the folder hierarchy

### Set the script to auto-launch at plugged-in

This is a good time to download the script `autosync.sh` and put it somewhere (it will be in `~/ereadersync/` in the examples)

Edit it, to set some variables.

Make it executable:

`chmod +x ~/ereadersync/autosync.sh`

Copy the service `ereader.service` to the systemctl after editing the `User` and `ExecStart` lines with the proper path to the script

`vim ereader.service`

`mv ereader.service /etc/systemd/system/ereader.service`

Reload systemctl
`sudo systemctl daemon-reload`

Create a `udev` rule (named `ereader`, can be changed)

`sudo vim /etc/udev/rules.d/ereader.rules`

With the vendor and product numbers you grabbed with `lsubs`

`ACTION=="add", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="2237", ATTRS{idProduct}=="4228", RUN+="/bin/systemctl start ereader.service --no-block"`

Update the udevs rules

`sudo udevadm control --reload-rules`

`sudo systemctl restart udev.service`

Done \o/
