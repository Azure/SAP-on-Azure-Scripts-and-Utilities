# Create the volumes


# Create the data volume 

sudo pvcreate /dev/disk/azure/scsi1/lun0
sudo pvcreate /dev/disk/azure/scsi1/lun1
sudo pvcreate /dev/disk/azure/scsi1/lun2
sudo pvcreate /dev/disk/azure/scsi1/lun3
sudo pvcreate /dev/disk/azure/scsi1/lun4
sudo pvcreate /dev/disk/azure/scsi1/lun5
sudo pvcreate /dev/disk/azure/scsi1/lun6
sudo pvcreate /dev/disk/azure/scsi1/lun7
sudo pvcreate /dev/disk/azure/scsi1/lun8
sudo pvcreate /dev/disk/azure/scsi1/lun9
sudo pvcreate /dev/disk/azure/scsi1/lun10
sudo pvcreate /dev/disk/azure/scsi1/lun11
sudo pvcreate /dev/disk/azure/scsi1/lun12

sudo vgcreate data-vg01 /dev/disk/azure/scsi1/lun0 /dev/disk/azure/scsi1/lun1 /dev/disk/azure/scsi1/lun2 /dev/disk/azure/scsi1/lun3 /dev/disk/azure/scsi1/lun4 /dev/disk/azure/scsi1/lun5 /dev/disk/azure/scsi1/lun6 /dev/disk/azure/scsi1/lun7 /dev/disk/azure/scsi1/lun8 /dev/disk/azure/scsi1/lun9 /dev/disk/azure/scsi1/lun10 /dev/disk/azure/scsi1/lun11 /dev/disk/azure/scsi1/lun12
sudo lvcreate --extents 100%FREE --stripes 13 --name data-lv01 data-vg01

sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /data
echo "/dev/data-vg01/data-lv01  /data  ext4  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

sudo pvcreate /dev/disk/azure/scsi1/lun13
sudo pvcreate /dev/disk/azure/scsi1/lun14
sudo pvcreate /dev/disk/azure/scsi1/lun15

sudo vgcreate log-vg01 /dev/disk/azure/scsi1/lun13 /dev/disk/azure/scsi1/lun14 /dev/disk/azure/scsi1/lun15
sudo lvcreate --extents 100%FREE --stripes 3 --name log-lv01 log-vg01
sudo mkfs -t ext4 /dev/log-vg01/log-lv01
sudo mkdir /log

echo "/dev/log-vg01/log-lv01  /log  ext4  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab
