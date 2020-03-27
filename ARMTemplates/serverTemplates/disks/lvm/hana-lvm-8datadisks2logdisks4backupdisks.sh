sudo zypper install lvm2

# Creating the /hana/data volume
sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde
sudo pvcreate /dev/sdf
sudo pvcreate /dev/sdg
sudo pvcreate /dev/sdh
sudo pvcreate /dev/sdi
sudo pvcreate /dev/sdj

sudo mkdir /hana /hana/data

sudo vgcreate data-vg01 /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg /dev/sdh /dev/sdi /dev/sdj
sudo lvcreate --extents 100%FREE --stripes 8 --stripesize 256 --name data-lv01 data-vg01
# Updating fstab
echo "/dev/data-vg01/data-lv01  /hana/data  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/log volume
sudo pvcreate /dev/sdk
sudo pvcreate /dev/sdl

sudo vgcreate log-vg01 /dev/sdk /dev/sdl
sudo lvcreate --extents 100%FREE --stripes 2 --stripesize 32 --name log-lv01 log-vg01
sudo mkfs.xfs /dev/log-vg01/log-lv01
sudo mkdir /hana/log
# Updating fstab
echo "/dev/log-vg01/log-lv01  /hana/log  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
sudo pvcreate /dev/sdm
sudo vgcreate shared-vg01 /dev/sdm
sudo lvcreate --extents 100%FREE --name shared-lv01 shared-vg01
sudo mkfs.xfs /dev/shared-vg01/shared-lv01

sudo mkdir /hana/shared
# Update fstab
echo "/dev/shared-vg01/shared-lv01 /hana/shared  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
sudo pvcreate /dev/sdn
sudo vgcreate usrsap-vg01 /dev/sdn
sudo lvcreate --extents 100%FREE --name usrsap-lv01 usrsap-vg01
sudo mkfs.xfs /dev/usrsap-vg01/usrsap-lv01

sudo mkdir /usr/sap
# Update fstab
echo "/dev/usrsap-vg01/usrsap-lv01 /usr/sap  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo pvcreate /dev/sdo
sudo pvcreate /dev/sdp
sudo pvcreate /dev/sdq
sudo pvcreate /dev/sdr

sudo vgcreate backup-vg01 /dev/sdo /dev/sdp /dev/sdq /dev/sdr
sudo lvcreate --extents 100%FREE --stripes 4 --name backup-lv01 backup-vg01
sudo mkfs.xfs /dev/backup-vg01/backup-lv01
sudo mkdir /hana/backup
# Updating fstab
echo "/dev/backup-vg01/backup-lv01  /hana/backup  xfs  defaults,barrier=0,nofail  0  2" | sudo tee -a /etc/fstab


sudo chmod -R 0755 /hana
sudo chmod -R 0755 /usr/sap





