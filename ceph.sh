#! /bin/bash
# 	CHENLIMIN :176.130.6.157
#      	DATE:2019-11
#	
#请确保"/linux-soft/02/ceph10.iso"镜像以挂载到ftp,因为yum源来自ceph镜像!
#完成操作需要额外添加两块硬盘,请自行添加!
read -p "您确认已经准备好ceph镜像跟硬盘了吗?  确认请输入\"y\" :" $1
if [ "$1" == "y" ];then
echo -e "\033[35mOK 航班即将起航.."
fi
############################################### 交互页面 ################################################
read -p "请输入您要搭建ceph的第一个ip : " ip1
read -p "请输入您要搭建ceph的第二个ip : " ip2
read -p "请输入您要搭建ceph的第三个ip : " ip3
echo "如需更多机器请自行添加..."
########################################### 判断ip是否能通信 ############################################
for i in  $ip{1..3}
do
   ping -c 2 $i 	&> /dev/null   
  if [ $? -ne 0 ];then
	echo "$i 这个ip通信不了.请检查"
        exit
  fi
done 
########################################### 本机配置"SSH" 免密传输#######################################
ssh-keygen   -f /root/.ssh/id_rsa    -N ''     &> /dev/null 
for i in $ip1 $ip2 $ip3                     
do
rpm -q expect  &> /dev/null  || yum -y install expect         &> /dev/null
expect <<EOF
spawn ssh-copy-id  $i                      
expect "password"  {send  "123456\r"}     
expect "password"  {send  "123456\r"}     
EOF
done
################################################ 交互页面 ###############################################
read -p "请输入您的第一台主机名(顺序与前面ip一致) : " h1
read -p "请输入您的第二台主机名 : " h2
read -p "请输入您的第三太主机名 : " h3
#########################################################################################################
#修改/etc/hosts域名解析记录, 同步给所有ceph节点
echo "$ip1 $h1
$ip2 $h2 
$ip3 $h3 " >> /etc/hosts

for i in $ip1 $ip2 $ip3    
do
scp /etc/hosts  $i:/etc/         &> /dev/null
done
##为所有ceph节点配置yum源，并将配置同步给所有节点
echo "
[mon]
name=mon
baseurl=ftp://192.168.4.254/ceph/MON
gpgcheck=0
[osd]
name=osd
baseurl=ftp://192.168.4.254/ceph/OSD
gpgcheck=0
[tools]
name=tools
baseurl=ftp://192.168.4.254/ceph/Tools
gpgcheck=0 "  >  /etc/yum.repos.d/ceph.repo  

yum repolist            &> /dev/null         
if [ $? -ne 0 ];then
  echo "您的yum配置有问题,请检查!"
  exit
fi
for i in $ip1 $ip2 $ip3 
do
scp /etc/yum.repos.d/ceph.repo   $i:/etc/yum.repos.d/ 		&> /dev/null    
done
##修改所有节点主机与真实主机的NTP服务器同步时间 
sed -i 's/# server 3.centos.pool.ntp.org iburst/server 192.168.4.254 iburst/' /etc/chrony.conf      

for i in $ip1 $ip2 $ip3 
do
 scp /etc/chrony.conf $i:/etc/ 		  &> /dev/null  
 ssh  $i  "systemctl restart chronyd" 	    
done
#########################################################################################################
echo -e "\033[35m正在为每个节点装包,请耐心等待...(预计5分钟...)"
# 安装管理服务
yum -y install ceph-deploy	    &> /dev/null
# 创建工作目录
mkdir ceph-cluster
cd  ceph-cluster
# 给所有ceph节点安装ceph相关软件包
for i in $ip1 $ip2 $ip3 
do
ssh $i "yum -y install ceph-mon ceph-osd ceph-mds"	   &> /dev/null
done
echo -e "\033[35m是不是等得不耐烦了呢? 请亲再骚等一下下,小妹正在快马加鞭的为您在工作呢.."
# 初始化MON 服务
ceph-deploy new $h1 $h2 $h3		   &> /dev/null
ceph-deploy mon create-initial		   &> /dev/null
#########################################################################################################
# 为磁盘分区
for i in $ip1 $ip2 $ip3
do
 ssh $i "parted /dev/vdb mklabel gpt"		   &> /dev/null
 ssh $i "parted /dev/vdb mkpart primary 1 100%"		   &> /dev/null
done
#########################################################################################################
# 临时修改权限,立即生效
for i in $ip1 $ip2 $ip3
do
ssh $i chown  ceph.ceph  /dev/vdb1	&> /dev/null
done
#########################################################################################################
# 永久修改权限
echo "ENV{DEVNAME}=="/dev/vdb1",OWNER="ceph",GROUP="ceph""  > /etc/udev/rules.d/70-vdb.rules
for i in $ip1 $ip2 $ip3 
do
scp /etc/udev/rules.d/70-vdb.rules  $i:/etc/udev/rules.d/	   &> /dev/null
done
ceph-deploy disk  zap  $h1:vdc  $h2:vdc $h3:vdc			   &> /dev/null
echo -e "\033[31m正在创建OSD存储设备...\033[0m"
# 创建osd存储设备，vdc为集群提供存储空间，vdb1提供JOURNAL缓存
# 一个存储设备对应一个缓存设备，缓存需要SSD，不需要很大
ceph-deploy osd create  $h1:vdc:/dev/vdb1 $h2:vdc:/dev/vdb1  $h3:vdc:/dev/vdb1		    &> /dev/null
# 为一台机器启动 "MSD" 服务
ceph-deploy mds create $h3		   &> /dev/null
# 创建存储池
ceph osd pool create cephfs_data 128	   &> /dev/null
ceph osd pool create cephfs_metadata 128	   	&> /dev/null
# 创建文件系统
ceph fs new myfs1 cephfs_metadata cephfs_data	   &> /dev/null
#####  解决 HEALTH_WARN  的问题!   #这部操作用于实验环境!
#echo  "mon_pg_warn_max_per_osd = 1000" >>  /etc/ceph/ceph.conf
for i in $ip1 $ip2 $ip3
do
ssh $i "echo \"mon_pg_warn_max_per_osd = 1000\" >>  /etc/ceph/ceph.conf "
#scp /etc/ceph/ceph.conf  $i:/etc/ceph/	&> /dev/null
ssh $i "systemctl restart ceph-mon.target"
done
ceph -s &> /dev/null 
#########################################################################################################
ok=`ceph -s | awk -F"_" '/HEALTH/{print $2}'`
for i in {1..10}
do
if [ "$ok" != "OK" ];then
 ceph -s &>  /dev/null 
fi
sleep 2
done
echo -e "\033[32m以完成!请输入\"ceph -s\" 验证\033[0m"
