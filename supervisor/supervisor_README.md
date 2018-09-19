## Supervisor

**Supervisor** is a process control system. It will be used on the local (edge) devices to ensure that a unique instance of FaceEngine is always running automatically. Supervisor is able to start, stop, restart the process, generate output logs, and automatically restart the process if it crashes for whatever reason.



#### Overview

The goal of Supervisor is to facilitate, autonomously, the constant up-time and logging of the FaceEngine app.

- To start an instance of the app when the machine is turned on.
- To restart the app automatically in the event of a crash.
- To track the process ID of the app, so that we can start, stop, and query the status of the single instance from any terminal user (the app is run in the background).
- Allow the user to manually restart the app in the event of an update.
- To keep a detailed output and error log of the app.



#### Installation

1. Install supervisor using a package manager. If supervisor is installed this way, it should be started up automatically when the system reboots.

   `sudo apt-get install supervisor`

2. You can also restart it to make sure that it is running properly.

   `sudo service supervisor restart`

3. The next step is to add in the configuration file. This file must go into `/etc/supervisor/conf.d/`.

   `sudo vim /etc/supervisor/conf.d/conuter.conf`

4. This will open the file with the vim editor. Below is the configuration on Jetson we should use to automatically run Counter.

   Copy the code in `counter.conf` into this configuration file.

5. Now, update  and restart the supervisor for the new config to take place.

    `sudo supervisorctl update`

    `sudo supervisorctl restart all`



#### Operation

For the most part, supervisor should be automatic. But there may be times when you want some manual control over it.

To start, stop, or restart the processes.

`sudo supervisorctl stop all`

`sudo supervisorctl restart all`

To find out the status (state, uptime) of all the registered processes.

`sudo supervisorctl status`



#### Logs

Supervisor runs its sub-processes in the background so any output will not be seen in the console. It instead writes all the output to an out log and an error log. The location of the logs are specified by the config file.

To read the latest logs, as per the above location you can just *cat* it.

`cat /var/log/counter.out.log`

`cat /var/log/counter.err.log`

If you want the log to be updating live in the console, then use the *tail* command. This will follow the file, and show the last 100 lines of the log.

`tail -f -n 100 /var/log/counter.out.log`

