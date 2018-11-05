## Install Dlib on Jetson

#### Prepare swap memory

If we compile Dlib on Jetson directly, there is an issue that it does not have enough memory during the installation. So, we need manually set extra swap memory space for Jetson.

1. Incert a SD card (8 GB should be enough)
2. Go to Disk manager to unmount the SD card partition manually
3. Format SD card partition.
4. Run `sudo mkswap /dev/sd_partition_name` to format the partition (/dev/sd_partition_name) as swap
5. Go to disk manager to edit SD card partition as Linux Swap type.
6. Reboot the system. You should see the swap space (the same size as the SD card) in System Moiter.



#### Compile Dlib

1. Download [dlib ver19.16](http://dlib.net/files/dlib-19.16.tar.bz2)
2. Unzip downloaded file
3. `cd dlib-19.16`
4. `sudo python3 setup.py install --yes USE_AVX_INSTRUCTIONS --yes DLIB_USE_CUDA`