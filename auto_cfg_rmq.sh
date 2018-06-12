#!/bin/bash
#@Author Cheng
#@QQ 8416837
#init
#定义常量
#双主双从 互为主从 交叉部署
#【接收参数】接收参数0或者默认，是master - a、slave - b配置；接收参数1，是master - b、slave - a 配置
#双主双从 另一台机 broker-b
BROKER_MASTER="broker-a"
#双主双从 另一台机 broker-a
BROKER_SLAVE="broker-b"
L="[INFO]"
#--------------------------------
if [ "$1" = "1" ]; then
	BROKER_MASTER="broker-b"
	BROKER_SLAVE="broker-a"
	echo '配置第二台 broker-b做主机，broker-a做从机 ...' 
else 
	echo '配置第一台 broker-a做主机，broker-b做从机 ...' 
fi
#--------------------------------
RMQ_ZIP_LINK="http://mirrors.hust.edu.cn/apache/rocketmq/4.1.0-incubating/rocketmq-all-4.1.0-incubating-bin-release.zip"
NEWLINE="\\n"
HOST_CONFIG="192.168.4.193 rocketmq_master${NEWLINE}192.168.4.197 rocketmq_slave"
SUFFIX=".properties"
BROKER_SLAVE_S=${BROKER_SLAVE}"-s"
BROKER_M_CONFIG=${BROKER_MASTER}${SUFFIX}
BROKER_S_CONFIG=${BROKER_SLAVE_S}${SUFFIX}
#WAIT_NAMESRV=x
MASTER_CONFIG="namesrvAddr=rocketmq_master:9876;rocketmq_slave:9876${NEWLINE}brokerClusterName=xyz_mq_cluster_2${NEWLINE}brokerName=${BROKER_MASTER}${NEWLINE}brokerId=0${NEWLINE}deleteWhen=04${NEWLINE}fileReservedTime=48${NEWLINE}# ASYNC_MASTER 异步复制${NEWLINE}listenPort=10911${NEWLINE}brokerRole=ASYNC_MASTER${NEWLINE}flushDiskType=ASYNC_FLUSH${NEWLINE}storePathRootDir=/data/inetpub/apache-rocketmq/logs/store${NEWLINE}storePathCommitLog=/data/inetpub/apache-rocketmq/logs/store/commitlog${NEWLINE}autoCreateTopicEnable=false"
SLAVE_CONFIG="namesrvAddr=rocketmq_master:9876;rocketmq_slave:9876${NEWLINE}brokerClusterName=xyz_mq_cluster_2${NEWLINE}brokerName=${BROKER_SLAVE}${NEWLINE}brokerId=1${NEWLINE}deleteWhen=04${NEWLINE}fileReservedTime=48${NEWLINE}brokerRole=SLAVE${NEWLINE}flushDiskType=ASYNC_FLUSH${NEWLINE}#更改端口号 同一主机上两broker不可采用同端口 ${NEWLINE}listenPort=11911${NEWLINE}storePathRootDir=/data/inetpub/apache-rocketmq/logs-slave/store${NEWLINE}storePathCommitLog=/data/inetpub/apache-rocketmq/logs-slave/store/commitlog${NEWLINE}autoCreateTopicEnable=false"
#配置hosts
echo ${L}"配置hosts ..."
echo -e ${HOST_CONFIG} >> /etc/hosts
#进入下载目录
echo ${L}"rmq安装，下载->解包->改名->配置->启动 ..."
mkdir -p /data/inetpub/download/zip/rmq/
cd /data/inetpub/download/zip/rmq/
#获取rmq
echo ${L}"下载rmq ..."
wget -O rmq4.1.zip ${RMQ_ZIP_LINK}
#解压rmq
unzip -o rmq4.1.zip -d /data/inetpub/
echo ${L}"解压rmq - zip完毕，进入根目录 ..."
cd /data/inetpub/
#将现有rmq备份,如果/data/inetpub/apache-rocketmq/存在
d=`date "+%Y_%m%d_%H%M_%S"`
mv /data/inetpub/apache-rocketmq/ /data/inetpub/apache-rocketmq_BACKUP_${d}/
echo ${L}"将rmq目录改名成apache-rocketmq ..."
mv rocketmq-all-4.1.0-incubating apache-rocketmq
#配置服务器
echo ${L}"配置集群 ..."
#配置broker-a，配置文件已经存在，勿须创建
#写入配置
echo -e ${MASTER_CONFIG} > /data/inetpub/apache-rocketmq/conf/2m-2s-async/${BROKER_M_CONFIG}
#配置broker-b-s
#写入配置
echo -e ${SLAVE_CONFIG} > /data/inetpub/apache-rocketmq/conf/2m-2s-async/${BROKER_S_CONFIG}
#修改日志存储目录，将原生日志根目录改成/data/inetpub/apache-rocketmq/
echo ${L}"改日志根目录 ..."
cd /data/inetpub/apache-rocketmq/conf&&sed -i 's#${user.home}#/data/inetpub/apache-rocketmq#g' *.xml
#启动
#创建日志目录
echo ${L}"创建日志目录 ..."
mkdir -p /data/inetpub/apache-rocketmq/logs
cd /data/inetpub/apache-rocketmq/logs
echo ${L}"创建路由日志文件ns.log ..."
touch ns.log
#关闭namesrv
echo ${L}"关闭路由 ..."
sh /data/inetpub/apache-rocketmq/bin/mqshutdown namesrv
echo ${L}"sleep 2s"
sleep 2s
#启动namesrv
echo ${L}"启动路由namesrv ..."
nohup sh /data/inetpub/apache-rocketmq/bin/mqnamesrv >/data/inetpub/apache-rocketmq/logs/ns.log &
#关闭服务器
echo ${L}"关闭mq服务器"
sh /data/inetpub/apache-rocketmq/bin/mqshutdown broker
echo ${L}"sleep 3s"
sleep 3s
#启动broker（mq服务器）
echo ${L}"startover mq服务器 - master ..."
nohup sh /data/inetpub/apache-rocketmq/bin/mqbroker -c /data/inetpub/apache-rocketmq/conf/2m-2s-async/${BROKER_M_CONFIG} >/dev/null 2>&1 &
echo ${L}"startover mq服务器 - slave ..."
nohup sh /data/inetpub/apache-rocketmq/bin/mqbroker -c /data/inetpub/apache-rocketmq/conf/2m-2s-async/${BROKER_S_CONFIG} >/dev/null 2>&1 &
#启动完毕，检验
echo ${L}"sleep 3s"
sleep 3s
echo ${L}"java进程↓"
jps_array=`jps`
for process in ${jps_array[@]}  
do  
    echo ${process}  
done
