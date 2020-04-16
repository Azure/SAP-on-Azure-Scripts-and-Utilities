# Create the volumes

# Creating the /hana/data volume
sudo pvcreate /dev/disk/azure/scsi1/lun0
sudo pvcreate /dev/disk/azure/scsi1/lun1
sudo pvcreate /dev/disk/azure/scsi1/lun2
sudo pvcreate /dev/disk/azure/scsi1/lun3
sudo pvcreate /dev/disk/azure/scsi1/lun4
sudo pvcreate /dev/disk/azure/scsi1/lun5
sudo pvcreate /dev/disk/azure/scsi1/lun6
sudo pvcreate /dev/disk/azure/scsi1/lun7

sudo mkdir /hana /hana/data

sudo vgcreate data-vg01 /dev/disk/azure/scsi1/lun0 /dev/disk/azure/scsi1/lun1 /dev/disk/azure/scsi1/lun2 /dev/disk/azure/scsi1/lun3 /dev/disk/azure/scsi1/lun4 /dev/disk/azure/scsi1/lun5 /dev/disk/azure/scsi1/lun6 /dev/disk/azure/scsi1/lun7
sudo lvcreate --extents 100%FREE --stripes 8 --stripesize 256 --name data-lv01 data-vg01
# Updating fstab
echo "/dev/data-vg01/data-lv01  /hana/data  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/log volume
sudo pvcreate /dev/disk/azure/scsi1/lun8
sudo pvcreate /dev/disk/azure/scsi1/lun9

sudo vgcreate log-vg01 /dev/disk/azure/scsi1/lun8 /dev/disk/azure/scsi1/lun9
sudo lvcreate --extents 100%FREE --stripes 2 --stripesize 32 --name log-lv01 log-vg01
sudo mkfs.xfs /dev/log-vg01/log-lv01
sudo mkdir /hana/log
# Updating fstab
echo "/dev/log-vg01/log-lv01  /hana/log  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
sudo pvcreate /dev/disk/azure/scsi1/lun10
sudo vgcreate shared-vg01 /dev/disk/azure/scsi1/lun10
sudo lvcreate --extents 100%FREE --name shared-lv01 shared-vg01
sudo mkfs.xfs /dev/shared-vg01/shared-lv01

sudo mkdir /hana/shared
# Update fstab
echo "/dev/shared-vg01/shared-lv01 /hana/shared  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
sudo pvcreate /dev/disk/azure/scsi1/lun11
sudo vgcreate usrsap-vg01 /dev/disk/azure/scsi1/lun11
sudo lvcreate --extents 100%FREE --name usrsap-lv01 usrsap-vg01
sudo mkfs.xfs /dev/usrsap-vg01/usrsap-lv01

sudo mkdir /usr/sap
# Update fstab
echo "/dev/usrsap-vg01/usrsap-lv01 /usr/sap  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo pvcreate /dev/disk/azure/scsi1/lun12
sudo pvcreate /dev/disk/azure/scsi1/lun13
sudo pvcreate /dev/disk/azure/scsi1/lun14
sudo pvcreate /dev/disk/azure/scsi1/lun15

sudo vgcreate backup-vg01 /dev/disk/azure/scsi1/lun12 /dev/disk/azure/scsi1/lun13 /dev/disk/azure/scsi1/lun14 /dev/disk/azure/scsi1/lun15
sudo lvcreate --extents 100%FREE --stripes 4 --name backup-lv01 backup-vg01
sudo mkfs.xfs /dev/backup-vg01/backup-lv01
sudo mkdir /hana/backup
# Updating fstab
echo "/dev/backup-vg01/backup-lv01  /hana/backup  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab


sudo chmod -R 0755 /hana
sudo chmod -R 0755 /usr/sap





