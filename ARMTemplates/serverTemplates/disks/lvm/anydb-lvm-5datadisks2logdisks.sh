sudo zypper install lvm2

sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde
sudo pvcreate /dev/sdf
sudo pvcreate /dev/sdg

sudo vgcreate data-vg01 /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg
sudo lvcreate --extents 100%FREE --stripes 5 --name data-lv01 data-vg01

sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /data

echo "/dev/data-vg01/data-lv01  /data  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

sudo pvcreate /dev/sdh
sudo pvcreate /dev/sdi

sudo vgcreate log-vg01 /dev/sdh /dev/sdi
sudo lvcreate --extents 100%FREE --stripes 2 --name log-lv01 log-vg01
sudo mkfs -t ext4 /dev/log-vg01/log-lv01
sudo mkdir /log

echo "/dev/log-vg01/log-lv01  /log  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab


