# Jenkins on Docker

![](https://libs.websoft9.com/common/websoft9-cloud-installer.png) 

## 简介

[简体中文](/README-zh.md) | [English](/README.md) 

本项目是由 [Websoft9](https://www.websoft9.com) 研发的 **云原生程序** ，大大简化 Jenkins 复杂的安装及配置。

## 系统要求

安装本项目，确保符合如下的条件（[详细参考](https://www.jenkins.io/doc/book/installing/docker/)）：

* **操作系统**: Red Hat, CentOS, Debian, Ubuntu 等主流 Linux等 操作系统
* **公有云**: AWS, Azure, Google Cloud, 阿里云, 腾讯云, 华为云等20多个全球主流云
* **私有云**: KVM, VMware, VirtualBox, OpenStack 等主流虚拟化架构
* **CPU架构**: Linux x86-64, ARM 32/64, Windows x86-64, IBM POWER8, x86/i686
* **内存**: 1GB以上
* **CPU**: 1核以上
* **存储**: 1GB以上
* **Swap分区**: GB以上
* **带宽**: 100M以上体验更流畅

## 安装使用

### 自动安装（推荐）

登录 Linux，运行下面的**自动化命令**即可启动安装并显示安装结果。  

```
sudo wget -N https://raw.githubusercontent.com/Websoft9/StackHub/main/docker-installer.sh; sudo bash docker-installer.sh -r jenkins

```

### package包安装

1.生成package包
登录 Linux，运行下面的**自动化命令**即可生成所需的package包。
```
sudo wget -N https://raw.githubusercontent.com/Websoft9/StackHub/main/docker-installer.sh; sudo bash docker-installer.sh -r jenkins -p
```
2.复制package包后安装

将压缩的package包复制到想要安装的服务器或虚拟机，登录 Linux，运行下面的**自动化命令**即可启动安装并显示安装结果。
```
sudo bash install-jenkins
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

#### 安装 Jenkins

直接运行下面的命令快速安装应用。如果你熟悉 Docker，建议先修改 [docker-compose](docker-compose-production.yml) 文件以满足自己的需求

```
git clone --depth=1 https://github.com/Websoft9/docker-jenkins
cd docker-jenkins
sudo docker-compose -f docker-compose-production.yml --env-file .env_all up -d
```

### 常见问题

#### 安装 Jenkins 前需要更改密码吗？

是的, 在生产环境中，您应该在 docker-compose 文件中修改所有数据库密码和应用程序密码

#### 端口冲突导致无法启动？

修改 [docker-compose](docker-compose-production.yml) 文件中冲突的端口，然后再启动容器


### 使用说明

启动应用后，本地浏览器访问 URL: *`http://服务器公网IP:9001`* 进入应用。  

下面是使用过程中可能需要的信息

#### 服务和端口

| 名称 | 端口号 | 用途 |  必要性 |
| --- | --- | --- | --- |
| jenkins | 9001 | 浏览器访问 Jenkins | Y |
## 文档

[Jenkins 管理员手册](https://support.websoft9.com/docs/jenkins)

## 企业级支持

如果需要企业级支持，请订阅我们提供的 [Jenkins 企业级支持版](https://apps.websoft9.com/jenkins) 

订阅企业级产品后，您可获得：

* 精准知识：产品专家的解答和指导
* 全面支持：技术支持所需的一切，例如启用HTTPS、升级指南
* 安全顾问：安全服务和工具，可提高您软件的安全性