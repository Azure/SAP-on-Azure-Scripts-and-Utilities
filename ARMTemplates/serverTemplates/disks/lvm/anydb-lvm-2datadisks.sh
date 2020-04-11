# Create the volumes

# Checking which /dev/sd? is mapped to which LUN

read sdc <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:0 | awk '{print $4}')
read sdd <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:1 | awk '{print $4}')

sudo pvcreate $sdc
sudo pvcreate $sdd

sudo vgcreate data-vg01 $sdc $sdd
sudo lvcreate --extents 100%FREE --stripes 2 --name data-lv01 data-vg01
sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /data

echo "/dev/data-vg01/data-lv01  /data  ext4  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab
