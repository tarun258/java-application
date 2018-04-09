#!/bin/bash -e
set -o pipefail

# Set path to conjur-appliance tar file
CONJUR_CONTAINER_TARFILE="appliance/conjur-appliance-4.9.9.0.tar"

# Set necessary environment variables for Conjur configuration
CONJUR_INGRESS_NAME=conjur
CONJUR_MASTER_HOSTNAME=conjur-master 
CONJUR_MASTER_ORGACCOUNT=$(basename "$PWD")
CONJUR_MASTER_PASSWORD=$(date +%s | sha256sum | base64 | head -c 32)

main () {

    printf "\n\n*******************************************************************\n"
    printf "* Bringing down all running containers and restarting.            *\n"
    printf "*                                                                 *\n"
    printf "* This will destroy your currently running environment - proceed? *\n"
    printf "*******************************************************************\n\n"

    select yn in "Yes" "No"; do
        case $yn in
          Yes ) break;;
          No ) exit;;
        esac
    done

    all_down                            # Bring down any leftover containers from previous runs

    conjur_up                           # Bring Conjur Enterprise Edition online
    cli_up                              # Bring Conjur CLI online

    echo "-----"
    echo "Bringing up Weavescope"
    docker-compose up -d scope          # Bring Weavescope online
    
    echo "-----"
    echo "Bringing up Jenkins Open Source"
    docker-compose up -d jenkins        # Bring Jenkins Open Source online
    JENKINS_CONT_ID=$(docker-compose ps -q jenkins)

    echo "-----"
    echo "Bringing up Artifactory Open Source"
    docker-compose up -d artifactory    # Bring Artifactory Open Source online

    echo "-----"
    echo "Building Java application Docker container"
    docker build .

    echo
    echo "Demo environment ready!"
    echo "The Conjur service is running as hostname: $CONJUR_INGRESS_NAME"
    echo
    echo "Conjur user Administrator created with the following password:"
    echo "     $CONJUR_MASTER_PASSWORD"
    echo
    echo "The Conjur CLI client container has already been logged in as Admin."
    echo
    echo "The Jenkins Administrative password can be retrieved by doing:"
    echo "     docker-compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
    echo
    echo

}

#####################################
# FUNCTION: all_down()              #
#####################################
all_down() {
    
    echo "-----"
    printf "\n-----\nBringing down all running services & deleting dangling volumes.\n"

    # Docker-Compose down the entire environment with the remove orphans switch
    docker-compose down --remove-orphans
    
    # Add all 'dangling volumes' to a variable
    dangling_vols=$(docker volume ls -qf dangling=true)
    
    # If the variable is not empty...
    if [[ "dangling_vols" != "" ]]; then
        
        # Remove them!
        docker volume rm $dangling_vols

    fi

}

#####################################
# FUNCTION: conjur_up()             #
#####################################
conjur_up() {
    
    echo "-----"

    #####################################
    # CHECK CONJUR APPLIANCE IMAGE/TAR  #
    #####################################

    # If the CONJUR_CONTAINER_TARFILE path set doesn't contain a valid file...
    if [[ ! -f $CONJUR_CONTAINER_TARFILE ]]; then
        
        printf "\n\nFile set to CONJUR_CONTAINER_TARFILE in this script is not found.  Continuing to load from Docker host...\n\n"
        
        # If the Docker host doesn't return back any images with 'conjur-appliance' in the name...
        if [[ "$(docker images --format {{.Repository}} | grep conjur-appliance)" == "" ]]; then
            
            printf "\n\nNo Docker image found loaded on this host."
            printf "\n\nEdit this script to set CONJUR_CONTAINER_TARFILE to a valid location of the Conjur appliance tarfile to load.\n\n"

            # Exit script since we hit an error
            exit -1

        fi

    else

        printf "\n\nLoading image from tarfile...\n\n"
        LOAD_MSG=$(docker load -q -i $CONJUR_CONTAINER_TARFILE)
        # Parse image name as the 3rd field in "Loaded image: xx" message
        IMAGE_ID=$(cut -d " " -f 3 <<< "$LOAD_MSG")
        sudo docker tag $IMAGE_ID conjur-appliance:latest

    fi

    #####################################
    # CREATE CONJUR APPLIANCE CONTAINER #
    #####################################

    echo "Bringing up Conjur"

    # Bring up Conjur Enterprise Edition appliance in the background
    docker-compose up -d conjur

    # Set environment variable for Conjur Master Container ID
    CONJUR_MASTER_CONT_ID=$(docker-compose ps -q conjur)

    #####################################
    # CONFIGURE CONJUR MASTER           #
    #####################################

    echo "-----"
    echo "Initializing Conjur Master"

    docker exec $CONJUR_MASTER_CONT_ID \
                evoke configure master \
                -j /src/etc/conjur.json \
                -h $CONJUR_MASTER_HOSTNAME \
                -p $CONJUR_MASTER_PASSWORD \
                $CONJUR_MASTER_ORGACCOUNT
    
    echo "-----"
    echo "Get certificate from Conjur"

    # Remove any previously left certificates
    rm -f ./etc/conjur-$CONJUR_MASTER_ORGACCOUNT.pem

    # Cache new certificate for copying to other containers
    docker cp -L $CONJUR_MASTER_CONT_ID:/opt/conjur/etc/ssl/conjur.pem ./etc/conjur-$CONJUR_MASTER_ORGACCOUNT.pem

}

#####################################
# FUNCTION: cli_up()                #
#####################################
cli_up() {

    echo "-----"
    echo "Bringing up Conjur CLI Client"

    # Bring up Conjur CLI Client container in the background
    docker-compose up -d cli 

    # Set environment variable for Conjur CLI Container ID
    CLI_CONT_ID=$(docker-compose ps -q cli)

    echo "-----"
    echo "Copy Conjur config and certificate to CLI"

    # Copy conjur.conf configuration file to Conjur CLI Container /etc
    docker cp -L ./etc/conjur.conf $CLI_CONT_ID:/etc
    # Copy conjur-$CONJUR_MASTER_APPLIANCE.pem to Conjur CLI Container /etc
    docker cp -L ./etc/conjur-$CONJUR_MASTER_ORGACCOUNT.pem $CLI_CONT_ID:/etc
    # Execute a shell on the CLI container and login as admin to Conjur CLI
    docker-compose exec cli conjur authn login -u admin -p $CONJUR_MASTER_PASSWORD
    # Execute another shell on the CLI container and begin quietly bootstrapping Conjur
    docker-compose exec cli conjur bootstrap -q

}

main "$@"