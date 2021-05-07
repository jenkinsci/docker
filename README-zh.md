# ONLYOFFICE on Docker

![](https://libs.websoft9.com/common/websoft9-cloud-installer.png) 

## 简介

[简体中文](/README-zh.md) | [English](/README.md) 

本项目是由 [Websoft9](https://www.websoft9.com) 研发的 **云原生程序** ，大大简化 ONLYOFFICE 复杂的安装及配置。

## 系统要求

安装本项目，确保符合如下的条件（[详细参考](https://github.com/onlyoffice/docker#recommended-system-requirements)）：

* **操作系统**: Red Hat, CentOS, Debian, Ubuntu 等主流 Linux等 操作系统
* **公有云**: AWS, Azure, Google Cloud, 阿里云, 腾讯云, 华为云等20多个全球主流云
* **私有云**: KVM, VMware, VirtualBox, OpenStack 等主流虚拟化架构
* **CPU架构**: Linux x86-64, ARM 32/64, Windows x86-64, IBM POWER8, x86/i686
* **内存**: 4GB以上
* **CPU**: 2核以上
* **存储**: 20GB以上
* **Swap分区**: 2GB以上
* **带宽**: 100M 以上体验更流畅

## 安装使用

### 自动安装（推荐）

登录 Linux，运行下面的**自动化命令**即可启动安装并显示安装结果。  

```
sudo wget -N https://raw.githubusercontent.com/Websoft9/docker-template/main/docker-installer.sh; sudo bash docker-installer.sh -r onlyoffice
```

另外，通过如下命令可以支持打包安装。
```
sudo wget -N https://raw.githubusercontent.com/Websoft9/docker-template/main/docker-installer.sh; sudo bash docker-installer.sh -r onlyoffice -p
```


### 手动安装

如果熟悉 Linux 以及 Docker，可以采用手动安装的方式

#### 准备 Docker 环境

如果您的服务器尚未安装 Docker，请使用如下命令安装它：

```
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
curl -L "https://github.com/docker/compose/releases/download/1.29.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose  /usr/bin
sudo systemctl start docker
```

#### 安装 ONLYOFFICE

直接运行下面的命令快速安装应用。如果你熟悉 Docker，建议先修改 [docker-compose](docker-compose-production.yml) 文件以满足自己的需求

```
git clone --depth=1 https://github.com/Websoft9/docker-onlyoffice
cd docker-onlyoffice
sudo docker-compose -f docker-compose-production.yml up -d
```

### 常见问题

#### 安装 ONLYOFFICE 前需要更改密码吗？

是的, 在生产环境中，您应该在 docker-compose 文件中修改所有数据库密码和应用程序密码

#### 端口冲突导致无法启动？

修改 [docker-compose](docker-compose-production.yml) 文件中冲突的端口，然后再启动容器


#### 问题1  
答案1  

#### 问题2  
答案2  

### 使用说明

启动应用后，本地浏览器访问 URL: *`http://服务器公网IP:9002`* 进入应用。  

下面是使用过程中可能需要的信息

#### 账号

本应用默认安装后的管理员用户名和密码如下：

| 用户名    | 密码 |
| ------- | -------- |
|  admin | 123456  |

#### 服务和端口

| 名称 | 端口号 | 用途 |  必要性 |
| --- | --- | --- | --- |
| onlyoffice-server | 9002 | 浏览器访问 ONLYOFFICE | Y |
| phpmyadmin | 9090 | 数据库可视化管理工具 | Y |
## 文档

[ONLYOFFICE 管理员手册](https://support.websoft9.com/docs/onlyoffice)

## 企业级支持

如果需要企业级支持，请订阅我们提供的 [ONLYOFFICE 企业级支持版](https://apps.websoft9.com/onlyoffice) 

订阅企业级产品后，您可获得：

* 精准知识：产品专家的解答和指导
* 全面支持：技术支持所需的一切，例如启用HTTPS、升级指南
* 安全顾问：安全服务和工具，可提高您软件的安全性
