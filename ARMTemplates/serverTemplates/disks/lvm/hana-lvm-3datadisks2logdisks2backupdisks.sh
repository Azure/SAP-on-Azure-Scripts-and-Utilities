sudo zypper install lvm2

# Creating the /hana/data volume
sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde

sudo vgcreate data-vg01 /dev/sdc /dev/sdd /dev/sde 
sudo lvcreate --extents 100%FREE --stripes 3 --stripesize 256 --name data-lv01 data-vg01
sudo mkfs.xfs /dev/data-vg01/data-lv01

sudo mkdir /hana /hana/data
# Update fstab
echo "/dev/data-vg01/data-lv01  /hana/data  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/log volume
sudo pvcreate /dev/sdf
sudo pvcreate /dev/sdg
sudo vgcreate log-vg01 /dev/sdf /dev/sdg
sudo lvcreate --extents 100%FREE --stripes 2 --stripesize 32 --name log-lv01 log-vg01
sudo mkfs.xfs /dev/log-vg01/log-lv01

sudo mkdir /hana/log
# Update fstab
echo "/dev/log-vg01/log-lv01  /hana/log  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
sudo pvcreate /dev/sdh
sudo vgcreate shared-vg01 /dev/sdh
sudo lvcreate --extents 100%FREE --name shared-lv01 shared-vg01
sudo mkfs.xfs /dev/shared-vg01/shared-lv01

sudo mkdir /hana/shared
# Update fstab
echo "/dev/shared-vg01/shared-lv01 /hana/shared  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
sudo pvcreate /dev/sdi
sudo vgcreate usrsap-vg01 /dev/sdi
sudo lvcreate --extents 100%FREE --name usrsap-lv01 usrsap-vg01
sudo mkfs.xfs /dev/usrsap-vg01/usrsap-lv01

sudo mkdir /usr/sap
# Update fstab
echo "/dev/usrsap-vg01/usrsap-lv01 /usr/sap  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo pvcreate /dev/sdj
sudo pvcreate /dev/sdk
sudo vgcreate backup-vg01 /dev/sdj /dev/sdk
sudo lvcreate --extents 100%FREE --stripes 2 --name backup-lv01 backup-vg01
sudo mkfs.xfs /dev/backup-vg01/backup-lv01
sudo mkdir /hana/backup

echo "/dev/backup-vg01/backup-lv01  /hana/backup  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

sudo chmod -R 0755 /hana
sudo chmod -R 0755 /usr/sap



