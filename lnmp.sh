#! /bin/bash
                    ##First Shell !!  搭建WORDPRESS(博客网站) "CHENLIMIN"  
## 请先拷贝lnmp_soft.tar.gz 到目标主机的 ~ 目录下!!
 yum repolist   &> /dev/null
if [ $? -ne 0 ];then
  echo "yum源不可用,请检查配置"
  exit
fi
  echo "脚本正在奔跑...请稍等" 
pzwj="/usr/local/nginx/conf/nginx.conf"  ##定义Nginx配置文件为变量(方便使用)
yum -y install gcc pcre-devel  openssl-devel &> /dev/null  ## 安装编译器
cd	
tar -xf  lnmp_soft.tar.gz     &> /dev/null
if [ $? -ne 0 ];then
  echo "请先把'lnmp_soft'目录拷贝到当前家目录下"
  exit
fi
cd lnmp_soft
tar -xvf nginx-1.12.2.tar.gz 	  &> /dev/null
cd nginx-1.12.2                      ## 编译安装nginx!
useradd -s /sbin/nologin  nginx   
./configure --user=nginx --group=nginx --with-http_ssl_module --with-http_stub_status_module &> /dev/null
make        &> /dev/null  ##编译  
make install    &> /dev/null	 
yum -y install   mariadb   mariadb-server   mariadb-devel  &> /dev/null  ##安装LNMP的M(数据库服务)
yum -y  install  php   php-mysql   php-fpm   &> /dev/null   ##安装LNMP的P(语言)
systemctl start  mariadb 
systemctl enable mariadb    &> /dev/null
systemctl start php-fpm
systemctl enable php-fpm    &> /dev/null
sed -i '65,71 s/#//'  $pzwj      
sed -i '/SCRIPT/d'      $pzwj     ##修改配置文件信息,实现读写分离!
sed -i 's/fastcgi_params/fastcgi.conf/'  $pzwj	 
sed -i 's/index  index.html index.htm;/index index.php index.html index.htm;/' $pzwj		 
/usr/local/nginx/sbin/nginx      ##启动Nginx服务
yum -y install unzip	  &> /dev/null
cd
cd lnmp_soft
unzip wordpress.zip    &> /dev/null
cd wordpress/   
tar -xf wordpress-5.0.3-zh_CN.tar.gz   &> /dev/null
cp -r  wordpress/*  /usr/local/nginx/html/
chown -R apache.apache  /usr/local/nginx/html/  
ip=`ifconfig | awk '/inet 192/{print $2}p'` 	# AWK精确查找本机ip(用于授权数据库使用)
mysql -e "create database wordpress character set utf8mb4" 
mysql -e "grant all on wordpress.* to wordpress@'localhost' identified by 'wordpress'"
mysql -e "grant all on wordpress.* to wordpress@$ip identified by 'wordpress'" #如有多个相似ip,还请手动填上
mysql -e "flush privileges"
##############################################
ss -ntupl | grep :80   &> /dev/null
if [ $? -eq 0 ];then
 echo "Nginx 已搭建完毕!"
else
	echo "Nginx 搭建出故障.请检查配置"
fi
##############################################
ss -ntupl | grep :3306  &> /dev/null
if [ $? -eq 0 ];then
 echo "数据库搭建已完毕!"
else
	echo "数据库 搭建出故障,请检查配置"
fi
##############################################
ss -ntupl | grep :9000  &> /dev/null
 if [ $? -eq 0 ];then
   echo "网站语言 PHP 已搭建完毕"
else 
	echo "PHP 搭建出故障,请检查配置"
fi
##############################################
echo "所有操作已完成!  感谢使用... "
echo "请使用 firefox http://$ip  进行wordpress(博客网站)配置"
