# Create the volumes
# Checking which /dev/sd? is mapped to which LUN

read idTemp <<< $(sudo lsscsi -u  | grep /dev/sdc | awk '{print $1}' | awk -F ':' '{print $1}')
read id <<< ${idTemp:1}

read sdc <<< $(sudo lsscsi -u -i $id | grep $id:0:0:0 | awk '{print $4}')
read sdd <<< $(sudo lsscsi -u -i $id | grep $id:0:0:1 | awk '{print $4}')
read sde <<< $(sudo lsscsi -u -i $id | grep $id:0:0:2 | awk '{print $4}')
read sdf <<< $(sudo lsscsi -u -i $id | grep $id:0:0:3 | awk '{print $4}')
read sdg <<< $(sudo lsscsi -u -i $id | grep $id:0:0:4 | awk '{print $4}')
read sdh <<< $(sudo lsscsi -u -i $id | grep $id:0:0:5 | awk '{print $4}')

sudo pvcreate $sdc
sudo pvcreate $sdd

sudo vgcreate data-vg01 $sdc $sdd
sudo lvcreate --extents 100%FREE --stripes 2 --stripesize 256 --name data-lv01 data-vg01
sudo mkfs.xfs /dev/data-vg01/data-lv01
sudo mkdir /hana /hana/data

echo "/dev/data-vg01/data-lv01  /hana  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Create the /hana/shared volume
sudo pvcreate $sde
sudo vgcreate shared-vg01 $sde
sudo lvcreate --extents 100%FREE --name shared-lv01 shared-vg01
sudo mkfs.xfs /dev/shared-vg01/shared-lv01

sudo mkdir /hana/shared
# Update fstab
echo "/dev/shared-vg01/shared-lv01 /hana/shared  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
sudo pvcreate $sdf
sudo vgcreate usrsap-vg01 $sdf
sudo lvcreate --extents 100%FREE --name usrsap-lv01 usrsap-vg01
sudo mkfs.xfs /dev/usrsap-vg01/usrsap-lv01

sudo mkdir /usr/sap
# Update fstab
echo "/dev/usrsap-vg01/usrsap-lv01 /usr/sap  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo pvcreate $sdg
sudo pvcreate $sdh

sudo vgcreate backup-vg01 $sdg $sdh
sudo lvcreate --extents 100%FREE --stripes 2 --name backup-lv01 backup-vg01
sudo mkfs.xfs /dev/backup-vg01/backup-lv01
sudo mkdir /hana/backup

echo "/dev/backup-vg01/backup-lv01  /hana/backup  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

sudo chmod -R 0755 /hana
sudo chmod -R 0755 /usr/sap


