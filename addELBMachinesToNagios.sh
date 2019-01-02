## Authors Leo Claus and Jake Tate 2018
#!/bin/bash
#
# Description : Dynamically add machines that are spun up by AWS ASG to Nagios configs
# Basic script taken from http://sharadchhetri.com and then heavily modified

# log statement
echo "Creating environment variables..."

# File Name for storing output values
_PROJECT_ELB_INSTANCES=elb_instance_dev
_PROJECT_NAGIOS_EXISTING_FILES=nagios_existing_files_dev

# Check ELB Name from AWS console and set the value in variable _PROJECT_ELB_NAME
_PROJECT_ELB_NAME=dev-aws-machine

# Give the AWS region name where the ELB exist
_AWS_REGION_NAME=us-east-1

# Give nagios host group name
_GROUP_NAME="ASG"

# Absolute paths of nagios config directories set for Autoscaling Group
_CURRENT_DIR=/usr/local/nagios/etc/objects/ASG/Dev
_ASG_DIR=/usr/local/nagios/etc/objects/ASG

# Give environment name eg, production/staging/Dev/Test
_ENVIRONMENT_NAME_=Dev

# Function to write the nagios config file for the machine
nagiosconfigfile () {
        # Log statement
        echo "writing host information to $_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT.cfg"

        echo "define host{" >>  "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg
        echo "        use                     linux-server" >> "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg
        echo "        host_name                $_ENVIRONMENT_NAME_$MY_PROJECT" >> "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg
        echo "        alias                   $_ENVIRONMENT_NAME_$MY_PROJECT" >> "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg
        echo "        hostgroups                   $_GROUP_NAME" >> "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg
        echo "        address                 $_PROJECT_PRIVATEIP" >> "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg
        echo '}' >> "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg
        echo "" >> "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg

}

# Function to remove dead machines
machineCleanup () {
        # Log statement
        echo "looking for dead machines to remove..."

        # Set path variables
        ELB_FILE=/usr/local/nagios/etc/objects/ASG/elb_instance_dev
        DIR_TO_SEARCH=/usr/local/nagios/etc/objects/ASG/Dev/

        # Use the 'cat' command to print a list of ELB info from the file and save it to a variable
        ELB_LIST=$(cat $ELB_FILE)

        # Loop through the directory that contains the config files and look for files not
        # in the ELB list (aka dead machine configs
        for f in $DIR_TO_SEARCH*;
        do
                VAR_TO_DELETE=$(ls $f | egrep -vi "$ELB_LIST")
                # If there is a file that is not in the ELB List, then remove it
                if [ "${#VAR_TO_DELETE}" -gt 0 ]
                then
                        # Log statement
                        echo "removing dead machine config file $VAR_TO_DELETE"
                        rm "$VAR_TO_DELETE"
                        # Restart the Nagios service to enable the changes
                        service nagios restart
                fi
        done
}

# Call function to remove dead machines
machineCleanup;

# Log statement
echo "pulling ELB info from AWS..."

# Information of instances behind the ELB saved in file (Variable Name = _PROJECT_ELB_INSTANCES)
aws --region $_AWS_REGION_NAME elb describe-load-balancers --load-balancer-names $_PROJECT_ELB_NAME --output text|grep INSTANCES|awk '{print $2}' > $_ASG_DIR/$_PROJECT_ELB_INSTANCES

# List the instance name which config files are already exist in nagios dir.
ls -1 $_CURRENT_DIR|sed "s/$_ENVIRONMENT_NAME_//g;s/.cfg//g" > $_ASG_DIR/$_PROJECT_NAGIOS_EXISTING_FILES

# Compare two files (variable of _PROJECT_ELB_INSTANCES and _PROJECT_NAGIOS_EXISTING_FILES)
# Then compare ouput value and store in variable called MY_PROJECT

grep -v -f $_ASG_DIR/$_PROJECT_NAGIOS_EXISTING_FILES $_ASG_DIR/$_PROJECT_ELB_INSTANCES |while read MY_PROJECT
do
_PROJECT_PRIVATEIP=$(aws --region $_AWS_REGION_NAME ec2 describe-instances --instance-ids $MY_PROJECT --query  'Reservations[].Instances[].[PrivateIpAddress]' --output text)
_PRIVATE_IP_WC=`echo $_PROJECT_PRIVATEIP|wc -l`

if [ "$_PRIVATE_IP_WC" -gt 0 ]
then
        cat /dev/null > "$_CURRENT_DIR/$_ENVIRONMENT_NAME_$MY_PROJECT".cfg;
        # Call function to write to the Nagios config file
        nagiosconfigfile;
        # Restart the Nagios service to enable the changes
        #systemctl restart nagios
        service nagios restart
fi
done

## End Of Line ##
