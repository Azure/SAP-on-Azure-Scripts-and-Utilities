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
read sdi <<< $(sudo lsscsi -u -i $id | grep $id:0:0:6 | awk '{print $4}')
read sdj <<< $(sudo lsscsi -u -i $id | grep $id:0:0:7 | awk '{print $4}')
read sdk <<< $(sudo lsscsi -u -i $id | grep $id:0:0:8 | awk '{print $4}')
read sdl <<< $(sudo lsscsi -u -i $id | grep $id:0:0:9 | awk '{print $4}')
read sdm <<< $(sudo lsscsi -u -i $id | grep $id:0:0:10 | awk '{print $4}')
read sdn <<< $(sudo lsscsi -u -i $id | grep $id:0:0:11 | awk '{print $4}')
read sdo <<< $(sudo lsscsi -u -i $id | grep $id:0:0:12 | awk '{print $4}')
read sdp <<< $(sudo lsscsi -u -i $id | grep $id:0:0:13 | awk '{print $4}')

# Creating the /hana volume
sudo pvcreate $sdc
sudo pvcreate $sdd
sudo pvcreate $sde
sudo pvcreate $sdf
sudo pvcreate $sdg
sudo pvcreate $sdh
sudo pvcreate $sdi
sudo pvcreate $sdj

sudo vgcreate data-vg01 $sdc $sdd $sde $sdf $sdg $sdh $sdi $sdj
sudo lvcreate --extents 100%FREE --stripes 8 --stripesize 256 --name data-lv01 data-vg01
sudo mkfs.xfs /dev/data-vg01/data-lv01
sudo mkdir /hana /hana/data /hana/log
# Update fstab
echo "/dev/data-vg01/data-lv01  /hana  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
sudo pvcreate $sdk
sudo vgcreate shared-vg01 $sdk
sudo lvcreate --extents 100%FREE --name shared-lv01 shared-vg01
sudo mkfs.xfs /dev/shared-vg01/shared-lv01

sudo mkdir /hana/shared
# Update fstab
echo "/dev/shared-vg01/shared-lv01 /hana/shared  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
sudo pvcreate $sdl
sudo vgcreate usrsap-vg01 $sdl
sudo lvcreate --extents 100%FREE --name usrsap-lv01 usrsap-vg01
sudo mkfs.xfs /dev/usrsap-vg01/usrsap-lv01

sudo mkdir /usr/sap
# Update fstab
echo "/dev/usrsap-vg01/usrsap-lv01 /usr/sap  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume

sudo pvcreate $sdm
sudo pvcreate $sdn
sudo pvcreate $sdo
sudo pvcreate $sdp

sudo vgcreate backup-vg01 $sdm $sdn $sdo $sdp
sudo lvcreate --extents 100%FREE --stripes 4 --name backup-lv01 backup-vg01
sudo mkfs.xfs /dev/backup-vg01/backup-lv01
sudo mkdir /hana/backup

echo "/dev/backup-vg01/backup-lv01  /hana/backup  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

sudo chmod -R 0755 /hana
sudo chmod -R 0755 /usr/sap
