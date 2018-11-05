## Installing dlib on Jetson

Dlib is a C++/Python library with useful tools for machine learning and computer vision. We will be using a trained version of dlib to extract facial embeddings for the purpose of facial comparison. Install dlib is normally easy on a desktop computer, but the Jetson can have some problems.

[dlib homepage](http://dlib.net/compile.html) | [dlib github](https://github.com/davisking/dlib)

## Prepare Swap Memory

If we compile dlib on Jetson directly, there is an issue that it does not have enough memory during the installation. So, we need to manually set extra swap memory space for Jetson.

1. Insert empty SD card (8 GB should be enough).
2. Go to **Disk Manager** to unmount the SD card partition manually.
3. Format SD card partition.
4. Run `sudo mkswap /dev/sd_partition_name` to format the partition (`/dev/sd_partition_name`) as swap
5. Go to disk manager to edit SD card partition as **Linux Swap** type.
6. Reboot the system. You should see the swap space (the same size as the SD card) in System Monitor.

## Compile Dlib

1. Download [dlib ver19.16](http://dlib.net/files/dlib-19.16.tar.bz2).
2. Unzip downloaded file.
3. `cd dlib-19.16`
4. `sudo python3 setup.py install --yes USE_AVX_INSTRUCTIONS --yes DLIB_USE_CUDA`

## Confirm Installation

If dlib was successfully installed into your Python environment, you should be able to fire up an intepreter and import it without error.

```bash
python3

>>> import dlib
>>> dlib.__version__
'19.16.0'
```