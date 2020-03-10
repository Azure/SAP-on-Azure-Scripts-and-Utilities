# Creating the /hana volume 
sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde
sudo pvcreate /dev/sdf
sudo pvcreate /dev/sdg

sudo vgcreate data-vg01 /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg
sudo lvcreate --extents 100%FREE --stripes 5 --name data-lv01 data-vg01
sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /hana /hana/data /hana/log

echo "/dev/data-vg01/data-lv01  /hana  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
(echo n; echo p; echo 1; echo ; echo ; echo w) | sudo fdisk /dev/sdh
sudo mkfs -t ext4 /dev/sdh1

sudo mkdir /hana/shared
# Update fstab
echo "/dev/sdh1 /hana/shared  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
(echo n; echo p; echo 1; echo ; echo ; echo w) | sudo fdisk /dev/sdi
sudo mkfs -t ext4 /dev/sdi1

sudo mkdir /usr/sap
# Update fstab
echo "/dev/sdi1 /usr/sap  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo pvcreate /dev/sdj
sudo pvcreate /dev/sdk

sudo vgcreate backup-vg01 /dev/sdj /dev/sdk
sudo lvcreate --extents 100%FREE --stripes 2 --name backup-lv01 backup-vg01
sudo mkfs -t ext4 /dev/backup-vg01/backup-lv01
sudo mkdir /backup

echo "/dev/backup-vg01/backup-lv01  /hana/backup  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

sudo chmod -R 0755 /hana
sudo chmod -R 0755 /usr/sap
