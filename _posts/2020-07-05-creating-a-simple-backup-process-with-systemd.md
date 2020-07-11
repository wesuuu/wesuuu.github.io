---
layout: post
title:  "Create a backup process with systemd"
date:   2020-07-04 22:24:13 +0000
categories: jekyll update
---

![systemd](https://upload.wikimedia.org/wikipedia/commons/3/35/Systemd_components.svg)

In this following guide, we'll do the following with systemd:

1. Mount a filesystem
2. Create a backup service to move compressed data onto the drive
3. Create a timer based off of the backup service

## Why use systemd?

To solve our requirements, we could use traditionally use the `mount`, `fstab`, and `crontab` to create a simple backup process like so [[1]](#mount-cmd):

1. Mount a filesystem (in this case, we'll use /dev/sda. I'll assume it's already formatted to the ext4 filesystem)
`mount /dev/sda /mnt/backup`
2. Make it permanent on reboot by appending the following to the `/etc/fstab` config file
`/dev/sda   /mnt/backup     etx4    defaults    0   1`
3. Create the backup job

`crontab -e # edit the crontab and add below`
```bash
# Schedule it to run at 1AM
0 1 * * * tar -zvcf /mnt/backup/home.tar.gz /home
```
<br/>
...Pretty simple, right? So why go through all the trouble of using systemd instead of this method?

### Advantages of systemd

systemd has some advantages over the previous method:

- It uses ```journalctl```. Typically, when executing a script/job/code with the crontab, you'll either have to handle the logging within the script, pipe stdout/stderr to some file, or setup some type of syslog service. ```journalctl``` is enabled by default when using systemd and we'll see how easily it's used to assess logs.
- Greater configurability. systemd works through directives, and there's directives for every lifecycle event for a service. For example, if you'd want to be notified if a service fails, you can specify the `OnFailure=` directive to execute a job. Doing this with the crontab/script can be cumbersome.
- Services can be triggered by other services and not just necessarily time. For example, if say you have a database service that you want to start up after the network service is online, you can do that easily with systemd.
- You can easily tell if a service has failed by use of `systemctl status <SERVICE_NAME>`. 

With that said, lets move on to actually fulfilling our requirements with systemd.

## Mount a filesystem with systemd

### Create the service file 

1. Navigate to `/etc/systemd/system` and create a file that has the name in the path separated by dashes with file extension `.mount`. For our path `/mnt/backup`, this will translate to `mnt-backup.mount`
2. Within the configuration file, specify what the configuration is and what you want mounted to where [[3]](#services-systemd):

    {% highlight ini %}
    [Unit]
    Description=Mount /dev/sda to /mnt/backup

    [Mount]
    What=/dev/sda
    Where=/mnt/backup
    Type=ext4
    Options=defaults

    [Install]
    WantedBy=multi-user.target
    {% endhighlight %}

### Start the mount service

1. Enable and start the mount using `systemctl`
    ```bash
    systemctl enable mnt-backup.mount
    systemctl start mnt-backup.mount
    ```
    `systemctl enable` allows the mount service to start on reboot and `systemctl start` (can you guess it?) starts the service
2. Check its status to confirm it's online

`systemctl status mnt-backup.mount`

## Create the backup service

We can now move on to create the backup service using systemd.

1. Within `/etc/systemd/system`, create a new service for the backup with file extension `.service`
    `vim backup-home.service`

    {% highlight ini %}
    [Unit]
    Description=Backup all home directories to /mnt/backup

    [Service]
    Type=simple
    ExecStart=tar -zvcf /mnt/backup/home.tar.gz /home

    [Install]
    WantedBy=multi-user.target
    {% endhighlight %}

You can confirm the service works by running `systemctl start backup-home.service` and then checking `systemctl status backup-home.service`. I wouldn't recommend running `systemctl enable` as it will start the service upon a reboot every time.

## Create and start the backup timer

1. Within `/etc/systemd/system`, create a new service for the backup with file extension `.timer` [[4]](#timers-systemd)
    
    `vim backup-home.timer`

    {% highlight ini %}
    [Unit]
    Description=backup-home.service at fixed interval

    [Timer]
    Unit=backup-home.service
    OnCalendar=*-*-* 1:00:00

    [Install]
    WantedBy=timers.target
    {% endhighlight %}

Here, we specified that `backup-home.service` should run at 1AM everyday.

You can now enable and start it again with `systemctl enable backup-home.timer` and `systemctl start backup-home.timer`

## Checking the event stream using journalctl

`journalctl` makes it really easy to see the logs of your services [[5]](#journalctl-systemd). 

To see the logs of the backup service, simply run `journalctl -u backup-home.service`.

## References

1. <a name="mount-cmd" href="https://linuxize.com/post/how-to-mount-and-unmount-file-systems-in-linux/">https://linuxize.com/post/how-to-mount-and-unmount-file-systems-in-linux/</a>
2. <a name="mount-systemd" href="https://www.thegeekdiary.com/how-to-auto-mount-a-filesystem-using-systemd/">https://www.thegeekdiary.com/how-to-auto-mount-a-filesystem-using-systemd/</a>
3. <a name="services-systemd" href="https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files">https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files</a>
4. <a name="timers-systemd" href="https://www.freedesktop.org/software/systemd/man/systemd.timer.html">https://www.freedesktop.org/software/systemd/man/systemd.timer.html</a>
5. <a name="journalctl-systemd" href="https://www.digitalocean.com/community/tutorials/how-to-use-journalctl-to-view-and-manipulate-systemd-logs">https://www.digitalocean.com/community/tutorials/how-to-use-journalctl-to-view-and-manipulate-systemd-logs</a>