# Create the volumes
# Checking which /dev/sd? is mapped to which LUN

read sdc <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:0 | awk '{print $4}')
read sdd <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:1 | awk '{print $4}')
read sde <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:2 | awk '{print $4}')
read sdf <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:3 | awk '{print $4}')
read sdg <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:4 | awk '{print $4}')
read sdh <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:5 | awk '{print $4}')
read sdi <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:6 | awk '{print $4}')
read sdj <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:7 | awk '{print $4}')
read sdk <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:8 | awk '{print $4}')
read sdl <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:9 | awk '{print $4}')

# Create the data volume 
sudo pvcreate $sdc
sudo pvcreate $sdd
sudo pvcreate $sde
sudo pvcreate $sdf
sudo pvcreate $sdg
sudo pvcreate $sdh
sudo pvcreate $sdi
sudo pvcreate $sdj

sudo vgcreate data-vg01 $sdc $sdd $sde $sdf $sdg $sdh $sdi $sdj
sudo lvcreate --extents 100%FREE --stripes 8 --name data-lv01 data-vg01

sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /data

echo "/dev/data-vg01/data-lv01  /data  ext4  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

sudo pvcreate $sdk
sudo pvcreate $sdl

sudo vgcreate log-vg01 $sdk $sdl
sudo lvcreate --extents 100%FREE --stripes 2 --name log-lv01 log-vg01
sudo mkfs -t ext4 /dev/log-vg01/log-lv01
sudo mkdir /log

echo "/dev/log-vg01/log-lv01  /log  ext4  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab


