# Create the volumes
# Checking which /dev/sd? is mapped to which LUN

read sdc <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:0 | awk '{print $4}')
read sdd <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:1 | awk '{print $4}')
read sde <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:2 | awk '{print $4}')
read sdf <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:3 | awk '{print $4}')
read sdg <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:4 | awk '{print $4}')
read sdh <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:5 | awk '{print $4}')
read sdi <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:6 | awk '{print $4}')
read sdj <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:7 | awk '{print $4}')
read sdk <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:8 | awk '{print $4}')
read sdl <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:9 | awk '{print $4}')
read sdm <<< $(sudo lsscsi -u -i 3 | grep 3:0:0:10 | awk '{print $4}')

# Creating the /hana/data volume
sudo pvcreate $sdc
sudo pvcreate $sdd
sudo pvcreate $sde
sudo pvcreate $sdf
sudo vgcreate data-vg01 $sdc $sdd $sde $sdf 
sudo lvcreate --extents 100%FREE --stripes 4 --stripesize 256 --name data-lv01 data-vg01
sudo mkfs.xfs /dev/data-vg01/data-lv01

sudo mkdir /hana /hana/data
# Update fstab
echo "/dev/data-vg01/data-lv01  /hana/data  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/log volume
sudo pvcreate $sdg
sudo pvcreate $sdh
sudo vgcreate log-vg01 $sdg $sdh
sudo lvcreate --extents 100%FREE --stripes 2 --stripesize 32 --name log-lv01 log-vg01
sudo mkfs.xfs /dev/log-vg01/log-lv01

sudo mkdir /hana/log
# Update fstab
echo "/dev/log-vg01/log-lv01  /hana/log  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
sudo pvcreate $sdi
sudo vgcreate shared-vg01 $sdi
sudo lvcreate --extents 100%FREE --name shared-lv01 shared-vg01
sudo mkfs.xfs /dev/shared-vg01/shared-lv01

sudo mkdir /hana/shared
# Update fstab
echo "/dev/shared-vg01/shared-lv01 /hana/shared  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
sudo pvcreate $sdj
sudo vgcreate usrsap-vg01 $sdj
sudo lvcreate --extents 100%FREE --name usrsap-lv01 usrsap-vg01
sudo mkfs.xfs /dev/usrsap-vg01/usrsap-lv01

sudo mkdir /usr/sap
# Update fstab
echo "/dev/usrsap-vg01/usrsap-lv01 /usr/sap  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo pvcreate $sdk
sudo pvcreate $sdl
sudo pvcreate $sdm

sudo vgcreate backup-vg01 $sdk $sdl $sdm
sudo lvcreate --extents 100%FREE --stripes 3 --name backup-lv01 backup-vg01
sudo mkfs.xfs /dev/backup-vg01/backup-lv01
sudo mkdir /hana/backup
# Update fstab
echo "/dev/backup-vg01/backup-lv01  /hana/backup  xfs  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

sudo chmod -R 0755 /hana
sudo chmod -R 0755 /usr/sap


