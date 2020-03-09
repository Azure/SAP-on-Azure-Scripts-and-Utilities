sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde
sudo pvcreate /dev/sdf
sudo pvcreate /dev/sdg
sudo pvcreate /dev/sdh
sudo pvcreate /dev/sdi
sudo pvcreate /dev/sdj

sudo vgcreate data-vg01 /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg /dev/sdh /dev/sdi /dev/sdj
sudo lvcreate --extents 100%FREE --stripes 8 --name data-lv01 data-vg01
sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /hana
sudo mkdir /hana/data

echo "/dev/data-vg01/data-lv01  /hana/data  ext4  defaults  0  2" | sudo tee -a /etc/fstab



sudo pvcreate /dev/sdm
sudo pvcreate /dev/sdn
sudo pvcreate /dev/sdo
sudo pvcreate /dev/sdp

sudo vgcreate backup-vg01 /dev/sdm /dev/sdn /dev/sdo /dev/sdp
sudo lvcreate --extents 100%FREE --stripes 4 --name backup-lv01 backup-vg01
sudo mkfs -t ext4 /dev/backup-vg01/backup-lv01
sudo mkdir /backup

echo "/dev/backup-vg01/backup-lv01  /log  ext4  defaults  0  2" | sudo tee -a /etc/fstab


