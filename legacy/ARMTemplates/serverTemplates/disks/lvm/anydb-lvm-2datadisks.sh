# Create the volumes

sudo pvcreate /dev/disk/azure/scsi1/lun0
sudo pvcreate /dev/disk/azure/scsi1/lun1

sudo vgcreate data-vg01 /dev/disk/azure/scsi1/lun0 /dev/disk/azure/scsi1/lun1
sudo lvcreate --extents 100%FREE --stripes 2 --name data-lv01 data-vg01
sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /data

echo "/dev/data-vg01/data-lv01  /data  ext4  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab
