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
sudo lvcreate --extents 100%FREE --stripes 8 --name data-lv01 data-vg01
# Updating fstab
echo "/dev/data-vg01/data-lv01  /hana/data  ext4  defaults  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/log volume
sudo pvcreate /dev/sdk
sudo pvcreate /dev/sdl

sudo vgcreate log-vg01 /dev/sdk /dev/sdl
sudo lvcreate --extents 100%FREE --stripes 2 --name log-lv01 log-vg01
sudo mkfs -t ext4 /dev/log-vg01/log-lv01
sudo mkdir /hana/log
# Updating fstab
echo "/dev/log-vg01/log-lv01  /hana/log  ext4  defaults  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
sudo parted /dev/sdm --script mklabel gpt mkpart ext4part ext4 0% 100%
partprobe /dev/sdm1

sudo mkdir /hana/shared
# Update fstab
echo "/dev/sdm1 /hana/shared  ext4  defaults  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
sudo parted /dev/sdn --script mklabel gpt mkpart ext4part ext4 0% 100%
partprobe /dev/sdn1

sudo mkdir /usr/sap
# Update fstab
echo "/dev/sdi1 /usr/sap  ext4  defaults  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo pvcreate /dev/sdo
sudo pvcreate /dev/sdp
sudo pvcreate /dev/sdq
sudo pvcreate /dev/sdr

sudo vgcreate backup-vg01 /dev/sdo /dev/sdp /dev/sdq /dev/sdr
sudo lvcreate --extents 100%FREE --stripes 4 --name backup-lv01 backup-vg01
sudo mkfs -t ext4 /dev/backup-vg01/backup-lv01
sudo mkdir /hana/backup
# Updating fstab
echo "/dev/backup-vg01/backup-lv01  /hana/backup  ext4  defaults  0  2" | sudo tee -a /etc/fstab




