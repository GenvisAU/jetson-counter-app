# Jetson-TX2-docs



#### JetPack Installation and Reflash Jetson

1. Download [JatPack3.3](https://developer.nvidia.com/embedded/downloads#?search=jetpack%203.3) on a Linux computer
2. Follow Nvida [documentation](https://docs.nvidia.com/jetpack-l4t/index.html#jetpack/4.0ea/install.htm%3FTocPath%3D_____3) to install JetPack on Ubuntu (16.04 or 18.04)
3. Click *Next* and *Accept* all the licenses until the step 10 in the [documentation](https://docs.nvidia.com/jetpack-l4t/index.html#jetpack/4.0ea/install.htm%3FTocPath%3D_____3)
4. Choose *Device accesses Internet via router/switch* in the setp 10
5. Before clicking *Next*, you need to:
   - use two Ethnet cables to link: the computer and the router, the Jetson and the router
   - use USB cable to link Jetson and the computer
   - make sure the Jetson is powered
6. Continue clicking *Next* until *Installation Complete*
7. During Installation, if the warinings about time occurs, please use ssh to change the time on Jetson. Use the command `sudo date --set="2018-09-16 00:00:00"`



#### Install Tensorflow on Jetson

1. Download [Nvidia official prebuilt wheel file](https://nvidia.app.box.com/v/TF1101-Py35-wTRT) of Tensorflow
2. 

