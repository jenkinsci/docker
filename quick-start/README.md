# How-To do a quickstart of Jenkins Docker container

## Prerequisites

Docker is installed on your machine (Docker for Mac or Docker for Windows will work)

## Steps

- Open the terminal and run the following command:

            docker run -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts

- Wait till Jenkins starts up (Jenkins is up and running message in the log)

- Go to [your Jenkins host](http://localhost:8080). You should see the Jenkins web interface with the Installation wizard.

- To unlock the Jenkins instance - go to the terminal and find the following message in the startup log:

            *************************************************************

            Jenkins initial setup is required. An admin user has been created
            and a password generated.
            Please use the following password to proceed to installation:

            <PASSWORD>

            This may also be found at: /var/jenkins_home/secrets/initialAdminPassword

            *************************************************************

- Copy the password and paste it into the unlock screen.
Use the "Select plugins to install" option in the Customize Jenkins screen,  select None in the top panel of the window to unselect all plugins. Then click Install.
We do not need plugins for this quickstart
Your Jenkins is ready!
