#!/usr/bin/env bash

# Instructions:
#   1. Create a user account on the instance first.
#         - Do not use the auto-generated password. Reset it to a valid value. 
#   2. Add the mid_server role to the new account.
#   3. Set the Internal Integration User flag.
#   4. Install or validate your host has the unzip package installed.
#   5. Set the variables below as needed.
servicenow_instance="InstanceName"
mid_display_name="MID-Server-Name"
mid_server_name="${servicenow_instance}_docker_linux_mid_server"
mid_username="demo.mid"
mid_password="secret"
create_console_script="no"
#   6. Execute the script.
#        - The instance will be queried for the correct MID version
#        - The linux docker recipe file will be downloaded from ServiceNow.
#        - The recipe will be extracted and the image built.
#        - An export folder will be created to map the container MID's exports
#          to the host.
#        - A docker-compose.yaml file will be created and an instance started.
#
# NOTE: To update the MID Server after a platform patch or upgrade, just
#       execute the script again. The existing MID will be shutdown and a 
#       new MID server created and linked to the existing MID Server record
#       in ServiceNow. You will need to re-validate the instance and manually
#       remove the old docker container.
#
# NOTE: If running on Alpine Linux, you must install curl, unzip, docker, 
#       and docker-compose, then start the docker service and add the current 
#       linux user to the docker group before running this script.
#


if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "The ServiceNow MID Server Docker recipe only works on x86_64 architecture."
    echo "Terminating installation."
    exit
elif [[ "$(uname -s)" != "Linux" ]]; then
    echo "This script is intended for execution on Linux."
    echo "Terminating installation."
    exit
fi


# If there is a docker compose file, then make sure the container is stopped.
if test -f ./docker-compose.yaml; then
    echo "Shutting down the existing MID Server container..."
    docker compose down
fi

# Get the instance MID Server version information
url="https://${servicenow_instance}.service-now.com/api/now/table/sys_properties?sysparm_query=name=mid.version&sysparm_fields=value&sysparm_limit=1"
release=$( curl ${url} --request GET --header "Accept:application/json" --user ${mid_username}:${mid_password} )

if [[ "$release" =~ "error" ]]; then
    echo "An error has occured while trying to retrieve the MID Server version information."
    echo $release
    exit
fi

releasename=$( echo $release | cut -d '"' -f 6 )
release_date=$( echo $releasename | cut -d"_" -f4 )
rel_month=$( echo $release_date | cut -d"-" -f1 )
rel_day=$( echo $release_date | cut -d"-" -f2 )
rel_year=$( echo $release_date | cut -d"-" -f3 )

echo "Setting up a new MID Server for the ${servicenow_instance} at version ${releasename}."

# Get the recipe
filename=mid-linux-container-recipe.${releasename}.linux.x86-64.zip
curl -O https://install.service-now.com/glide/distribution/builds/package/app-signed/mid-linux-container-recipe/${rel_year}/${rel_month}/${rel_day}/${filename}

if [[ ! -f ./${filename} ]]; then
    echo "An error has occured while trying to retrieve the MID Server recipe file. No other information is available."
    exit
fi

# Create the recipe location and extract the recipe
recipe_location=./recipe
mkdir ${recipe_location}
file_name=$( ls mid-linux-container-recipe* )
unzip ./${file_name} -d ${recipe_location}
mid_server_version=$( echo ${file_name} | cut -f2 -d"." )

# Create an export folder and set permissions
mkdir ./export
chmod 777 ./export

# Build the image, then remove the recipe files
docker build --tag ${mid_server_name}:${mid_server_version} ${recipe_location}

rm -r ${recipe_location}
rm ./${file_name}

# Create a Docker Compose file and run the container
cat > docker-compose.yaml <<EOF
services:
  ${mid_server_name}:
    container_name: ${mid_server_name}
    image: ${mid_server_name}:${mid_server_version}
    restart: unless-stopped
    volumes:
        # Map the MID Servers export directory to the host
        - ./export:/opt/snc_mid_server/agent/export
    environment:
      MID_INSTANCE_URL: "https://${servicenow_instance}.service-now.com/"
      MID_INSTANCE_USERNAME: "${mid_username}"
      MID_INSTANCE_PASSWORD: "${mid_password}"
      MID_SERVER_NAME: "${mid_display_name}"

EOF

docker compose up -d

echo "Your MID server will start shortly. Do not forget to validate it!"

if test $create_console_script != "yes"; then
    exit
fi

# Create a shell script to connect to the container's BASH shell
cat > console.sh <<EOF
#!/usr/bin/env bash

docker exec -u 0 -it ${mid_server_name} bash
EOF

chmod u+x console.sh
