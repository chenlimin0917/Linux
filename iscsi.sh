#! /bin/bash
					##CHENLIMIN##
#此脚本在用于server(172.25.0.11)跟desktop(172.25.0.10)上 ,如需在别的机器运行,还请自行更改!
#DATE:2019-11
#配置一个5G的磁盘去共享
ip=172.25.0.11   #ip可自行更改,
ip1=172.25.0.10  #客户端ip
server=iqn.2019-11.com.example:server0   #定义服务端名
desktop=iqn.2019-11.com.example:desktop0  #定义客户端名
juan=iscsi_store   #后端卷名
###########################################  服务端配置 #################################################
firewall-cmd --set-default-zone=trusted   &> /dev/null #设置防火墙
echo -e "\033[35m正在准备环境..."
yum -y install expect			&> /dev/null
ssh-keygen   -f /root/.ssh/id_rsa  -N ''	&> /dev/null
##实现免密远程
expect <<SSH			
spawn ssh-copy-id $ip1
expect "?" {send "yes\r"}
expect "password" {send "redhat\r"} 
expect "password" {send "redhat\r"} 
SSH
ssh $ip1 "yum -y install expect"	&> /dev/null

rpm -q targetcli &> /dev/null  || yum -y install targetcli &> /dev/null  # 安装iscsi工具
#准备磁盘空间
echo -e "\033[35m正在准备磁盘空间..."
sleep 2
expect  <<EOF
spawn fdisk /dev/vdb
expect "："  {send "n\r"}
expect "Select"  {send "\r"}
expect "："  {send "\r"}
expect "："  {send "\r"}
expect "："  {send "+5G\r"}
expect "："  {send "wq\r"}
expect "："  {send "wq\r"}
EOF
echo -e "\033[35m分区以准备好,现在进行配置iscsi磁盘.."
partprobe /dev/vdb	&> /dev/null  # 刷新分区
#配置 iscsi 磁盘
expect <<OPPO
spawn targetcli
expect "/>" {send "backstores/block create $juan /dev/vdb1\r"}
expect "/>" {send "/iscsi/  create $server \r"}
expect "/>" {send "/iscsi/iqn.2019-11.com.example:server0/tpg1/acls create $desktop\r"}
expect "/>" {send "/iscsi/iqn.2019-11.com.example:server0/tpg1/luns create /backstores/block/$juan\r"}
expect "/>" {send "/iscsi/iqn.2019-11.com.example:server0/tpg1/portals create $ip 3260\r"}
expect "/>" {send "saveconfig\r"}
expect "/>" {send "exit\r"}
OPPO
systemctl restart target  && systemctl enable target &> /dev/null  #配置完重启服务并实现开机自启
echo -e "\033[32m服务端以准备完毕!现在进行配置服务端..."
############################################ 客户端配置 ################################################
#desktop
#远程安装 iscsi客户端服务  
ssh $ip1 "rpm -q iscsi-initiator-utils &> /dev/null || yum -y install iscsi-initiator-utils" &> /dev/null
#设置本机iqn名
ssh $ip1  " echo InitiatorName=$desktop  > /etc/iscsi/initiatorname.iscsi   "   &> /dev/null
ssh $ip1   " systemctl restart iscsid  && systemctl enable iscsid"	&> /dev/null  #重启服务,更新iqn
ssh $ip1   "iscsiadm -m discovery -t st -p $ip"		&> /dev/null  #发现磁盘
ssh $ip1   "iscsiadm -m node -L all"		&> /dev/null	#手动连接磁盘测试
##客户端连接磁盘后进行分区
echo -e "\033[35m正在准备磁盘空间...\033[0m"
ssh $ip1    expect <<eof	
spawn fdisk /dev/sda 
expect "：" {send "n\r"}
expect "Select" {send "\r"}
expect "：" {send "\r"}
expect "：" {send "\r"}
expect "：" {send "+4900M\r"}
expect "：" {send "wq\r"}
expect "：" {send "wq\r"}
eof
ssh $ip1   " partprobe /dev/sda "		&> /dev/null ##刷新分区
ssh $ip1   " mkfs.ext4 /dev/sda1 "		&> /dev/null	##格式化分区
ssh $ip1   " mkdir /mnt/data "		  ##创建挂载目录
ssh $ip1   "sed -i '/UUID/a \/dev\/sda1 \/mnt\/data ext4 _netdev 0 0' /etc/fstab"	&> /dev/null
#ssh $ip1 "blkid /dev/sda1 ; awk '{print $2 \" /mnt/data ext4 _netdev 0 0\"}' >> /etc/fstab"  #不完善
ssh $ip1   "mount -a"	 ##检测挂载
echo -e "\033[35m配置以完成,请放心使用\033[0m"
