sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd

sudo vgcreate data-vg01 /dev/sdc /dev/sdd
sudo lvcreate --extents 100%FREE --stripes 3 --name data-lv01 data-vg01
sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /data

echo "/dev/data-vg01/data-lv01  /data  ext4  defaults, barrier=0  0  2" | sudo tee -a /etc/fstab
