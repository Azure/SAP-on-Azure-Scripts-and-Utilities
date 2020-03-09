sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd

sudo vgcreate data-vg01 /dev/sdc /dev/sdd
sudo lvcreate --extents 100%FREE --stripes 2 --name data-lv01 data-vg01
sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /hana /hana/data

echo "/dev/data-vg01/data-lv01  /hana  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
(echo n; echo p; echo 1; echo ; echo ; echo w) | sudo fdisk /dev/sde
sudo mkfs -t ext4 /dev/sde1
sudo mkdir /hana/shared
# Update fstab
echo "/dev/sde1 /hana/shared  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
(echo n; echo p; echo 1; echo ; echo ; echo w) | sudo fdisk /dev/sdf
sudo mkfs -t ext4 /dev/sdf1

sudo mkdir /usr/sap
# Update fstab
echo "/dev/sdg1 /usr/sap  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo pvcreate /dev/sdg
sudo pvcreate /dev/sdh

sudo vgcreate backup-vg01 /dev/sdg /dev/sdh
sudo lvcreate --extents 100%FREE --stripes 2 --name backup-lv01 backup-vg01
sudo mkfs -t ext4 /dev/backup-vg01/backup-lv01
sudo mkdir /hana/backup

echo "/dev/backup-vg01/backup-lv01  /hana/backup  ext4  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

sudo -R chmod 0755 /hana
sudo -R chmod 0755 /usr/sap


