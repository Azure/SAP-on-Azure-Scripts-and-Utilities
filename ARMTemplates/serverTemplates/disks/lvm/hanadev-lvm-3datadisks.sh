# Creating the /hana/data volume
sudo pvcreate /dev/sdc
sudo pvcreate /dev/sdd
sudo pvcreate /dev/sde

sudo vgcreate data-vg01 /dev/sdc /dev/sdd /dev/sde 
sudo lvcreate --extents 100%FREE --stripes 3 --name data-lv01 data-vg01
sudo mkfs -t ext4 /dev/data-vg01/data-lv01

sudo mkdir /hana /hana/data /hana/log
# Update fstab
echo "/dev/data-vg01/data-lv01  /hana  ext4  defaults  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/shared volume
sudo parted /dev/sdf --script mklabel gpt mkpart ext4part ext4 0% 100%
partprobe /dev/sdf1

sudo mkdir /hana/shared
# Update fstab
echo "/dev/sdf1 /hana/shared  ext4  defaults  0  2" | sudo tee -a /etc/fstab

# Creating the /usr/sap volume
sudo parted /dev/sdg --script mklabel gpt mkpart ext4part ext4 0% 100%
partprobe /dev/sdg1

sudo mkdir /usr/sap
# Update fstab
echo "/dev/sdg1 /usr/sap  ext4  defaults  0  2" | sudo tee -a /etc/fstab

# Creating the /hana/backup volume
sudo parted /dev/sdh --script mklabel gpt mkpart ext4part ext4 0% 100%
partprobe /dev/sdh1

sudo mkdir /hana/backup
# Update fstab
echo "/dev/sdh1 /hana/backup  ext4  defaults  0  2" | sudo tee -a /etc/fstab
