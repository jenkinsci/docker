# Quickstart demo

This demo shows how to 

## Prerequisites:

* Docker is installed on your machine (Docker for Mac or Docker for Windows will work)

## Steps

1. Open the terminal and run the following command:

```bash
docker run -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts
```

2. Wait till Jenkins starts up (_Jenkins is up and running_ message in the log)
3. Go to `http://localhost:8080`. You should see the Jenkins web interface with the Installation wizard. Now you will need to unlock the instance
4. Go to the terminal and find the following message in the startup log:

```
*************************************************************

Jenkins initial setup is required. An admin user has been created
and a password generated.
Please use the following password to proceed to installation:

<PASSWORD>

This may also be found at: /var/jenkins_home/secrets/initialAdminP
assword

*************************************************************
```

5. Copy the password and paste it into the unlock screen. 
6. Use the the _Select plugins to install_ option in the **Customize CloudBees Jenkins Distribution** screen.
7 Select _None_ in the top panel of the window to unselect all plugins. Then click _Install_.
  * We do not need plugins for this quickstart
8. Your Jenkins is ready!
