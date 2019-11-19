#! /bin/bash
                    ##First Shell !!   CHENLIMIN
## 请先拷贝lnmp_soft.tar.gz 到目标主机的 ~ 目录下!!
 echo "脚本正在奔跑...请稍等" 
pzwj="/usr/local/nginx/conf/nginx.conf"  ##定义Nginx配置文件为变量(方便使用)
yum -y install gcc pcre-devel  openssl-devel &> /dev/null  ## 安装编译器
cd	
tar -xf  lnmp_soft.tar.gz     &> /dev/null
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
mysql -e "grant all on wordpress.* to wordpress@$ip identified by 'wordpress'"
mysql -e "flush privileges"

echo "操作已完成! 感谢使用... "
   -----------------------------------
echo "请使用 firefox http://$ip  进行wordpress(博客网站)配置"
