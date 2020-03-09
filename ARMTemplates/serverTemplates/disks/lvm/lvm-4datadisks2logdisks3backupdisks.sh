sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde
sudo pvcreate /dev/sdf


sudo vgcreate data-vg01 /dev/sdc /dev/sdd /dev/sde /dev/sdf 
sudo lvcreate --extents 100%FREE --stripes 4 --name data-lv01 data-vg01
sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /data

echo "/dev/data-vg01/data-lv01  /data  ext4  defaults  0  2" | sudo tee -a /etc/fstab

sudo pvcreate /dev/sdg
sudo pvcreate /dev/sdh

sudo vgcreate log-vg01 /dev/sdg /dev/sdh
sudo lvcreate --extents 100%FREE --stripes 2 --name log-lv01 log-vg01
sudo mkfs -t ext4 /dev/log-vg01/log-lv01
sudo mkdir /log

echo "/dev/log-vg01/log-lv01  /log  ext4  defaults  0  2" | sudo tee -a /etc/fstab

sudo pvcreate /dev/sdk
sudo pvcreate /dev/sdl
sudo pvcreate /dev/sdm

sudo vgcreate backup-vg01 /dev/sdk /dev/sdl /dev/sdm
sudo lvcreate --extents 100%FREE --stripes 3 --name backup-lv01 backup-vg01
sudo mkfs -t ext4 /dev/backup-vg01/backup-lv01
sudo mkdir /backup

echo "/dev/backup-vg01/backup-lv01  /backup  ext4  defaults  0  2" | sudo tee -a /etc/fstab



