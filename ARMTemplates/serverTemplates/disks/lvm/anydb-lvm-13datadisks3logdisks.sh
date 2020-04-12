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
read sdq <<< $(sudo lsscsi -u -i $id | grep $id:0:0:14 | awk '{print $4}')
read sdr <<< $(sudo lsscsi -u -i $id | grep $id:0:0:15 | awk '{print $4}')

# Create the data volume 

sudo pvcreate $sdc
sudo pvcreate $sdd
sudo pvcreate $sde
sudo pvcreate $sdf
sudo pvcreate $sdg
sudo pvcreate $sdh
sudo pvcreate $sdi
sudo pvcreate $sdj
sudo pvcreate $sdk
sudo pvcreate $sdl
sudo pvcreate $sdm
sudo pvcreate $sdn
sudo pvcreate $sdo

sudo vgcreate data-vg01 $sdc $sdd $sde $sdf $sdg $sdh $sdi $sdj $sdk $sdl $sdm $sdn $sdo
sudo lvcreate --extents 100%FREE --stripes 13 --name data-lv01 data-vg01

sudo mkfs -t ext4 /dev/data-vg01/data-lv01
sudo mkdir /data
echo "/dev/data-vg01/data-lv01  /data  ext4  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab

sudo pvcreate $sdp
sudo pvcreate $sdq
sudo pvcreate $sdr

sudo vgcreate log-vg01 $sdp $sdq $sdr
sudo lvcreate --extents 100%FREE --stripes 3 --name log-lv01 log-vg01
sudo mkfs -t ext4 /dev/log-vg01/log-lv01
sudo mkdir /log

echo "/dev/log-vg01/log-lv01  /log  ext4  defaults,nobarrier,nofail  0  2" | sudo tee -a /etc/fstab
