# Overview
I needed to have a MID server for periodic large file downloads, but was denied permanent resources for a periodic need that granted the access needed. I decided to pursue options for temporary MIDs to handle the use case. I also had an interest in learning about Docker hosted MID Servers. Docker containers turned out to be a great option. I can spin up a MID when needed and shut it down to conserver resources when not being used. There were two downsides to using Docker containers. First, ServiceNow stopped supporting Windows MID Servers in Docker. Second, Docker containers are not auto-updated. This script addressed the second issue, but the first remains.

**NOTE**: This script sets up a very basic MID Server. The compose file contains the ServiceNow credentials in plain text and the export folders is mapped with 777 permissions... so anyone can access the content. Add additional security appropriately for your needs.

# Instructions:
1. Create a user account on the instance first.
     - Do not use the auto-generated password. Reset it to a valid value. 
2. Add the mid_server role to the new account.
3. Set the Internal Integration User flag.
4. Install or validate your host has the **GNU** version of the following utilities installed. 
     **NOTE**: The BSD version that comes with macos may have different switches and behaviors.
     bash
     curl
     unzip
5. Set the variables below as needed. Values can be set inside the main script or in the secrets.sh file.

```
    servicenow_instance="dev123456"
    mid_display_name="My-MID-Server"
    mid_server_name="my_docker_linux_mid_server"
    mid_username="demo.mid.user"
    mid_password="secret-password"
    create_console_script="no"
```

**Note**: The sensitive information can be saved to a separate file and sourced into the script. Remember to "export" the values from the secrets file. 

6. Execute the script.
    - The instance will be queried for the correct MID version
    - The linux docker recipe file will be downloaded from ServiceNow.
    - The recipe will be extracted and the image built.
    - An export folder will be created to map the container MID's exports
      to the host.
    - A docker-compose.yaml file will be created and an instance started.

**NOTE**: To update the MID Server after a platform patch or upgrade, just
       execute the script again. The existing MID will be shutdown and a 
       new MID server created and linked to the existing MID Server record
       in ServiceNow. You will need to re-validate the instance and manually
       remove the old docker container.

**NOTE**: If running on Alpine Linux, you must install curl, unzip, docker, 
       and docker-compose, then start the docker service and add the current 
       linux user to the docker group before running this script.
