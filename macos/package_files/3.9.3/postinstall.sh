#! /bin/bash
# By Spransy, Derek" <DSPRANS () emory ! edu> and Charlie Scott
# Modified by Santiago Bassett (http://www.wazuh.com) - Feb 2016
# alterations by bil hays 2013
# -Switched to bash
# -Added some sanity checks
# -Added routine to find the first 3 contiguous UIDs above 100,
#  starting at 600 puts this in user space
# -Added lines to append the ossec users to the group ossec
#  so the the list GroupMembership works properly
GROUP="ossec"
USER="ossec"
DIR="/Library/Ossec"
INSTALLATION_SCRIPTS_DIR="${DIR}/packages_files/agent_installation_scripts"
SCA_FILES_DIR="${INSTALLATION_SCRIPTS_DIR}/sca"

# Default for all directories
chmod -R 750 ${DIR}/
chown -R root:${GROUP} ${DIR}/

chown -R root:wheel ${DIR}/bin
chown -R root:wheel ${DIR}/lib

# To the ossec queue (default for agentd to read)
chown -R ${USER}:${GROUP} ${DIR}/queue/{alerts,diff,ossec,rids}

chmod -R 770 ${DIR}/queue/{alerts,ossec}
chmod -R 750 ${DIR}/queue/{diff,ossec,rids}

# For the logging user
chmod 770 ${DIR}/logs
chown -R ${USER}:${GROUP} ${DIR}/logs
find ${DIR}/logs/ -type d -exec chmod 750 {} \;
find ${DIR}/logs/ -type f -exec chmod 660 {} \;

chown -R root:${GROUP} ${DIR}/tmp
chmod 1750 ${DIR}/tmp

chmod 770 ${DIR}/etc
chown ${USER}:${GROUP} ${DIR}/etc
chmod 640 ${DIR}/etc/internal_options.conf
chown root:${GROUP} ${DIR}/etc/internal_options.conf
chmod 640 ${DIR}/etc/local_internal_options.conf
chown root:${GROUP} ${DIR}/etc/local_internal_options.conf
chmod 640 ${DIR}/etc/client.keys
chown root:${GROUP} ${DIR}/etc/client.keys
chmod 640 ${DIR}/etc/localtime
chmod 770 ${DIR}/etc/shared # ossec must be able to write to it
chown -R root:${GROUP} ${DIR}/etc/shared
find ${DIR}/etc/shared/ -type f -exec chmod 660 {} \;
chown root:${GROUP} ${DIR}/etc/ossec.conf
chmod 640 ${DIR}/etc/ossec.conf


chmod 750 ${DIR}/.ssh

# For the /var/run
chmod -R 770 ${DIR}/var
chown -R root:${GROUP} ${DIR}/var

chown root:${GROUP} /etc/ossec-init.conf

. ${INSTALLATION_SCRIPTS_DIR}/src/init/dist-detect.sh

upgrade=$(launchctl getenv WAZUH_PKG_UPGRADE)

if [ "${upgrade}" = "false" ]; then
    ${INSTALLATION_SCRIPTS_DIR}/gen_ossec.sh conf agent ${DIST_NAME} ${DIST_VER}.${DIST_SUBVER} ${DIR} > ${DIR}/etc/ossec.conf
    chown root:ossec ${DIR}/etc/ossec.conf
    chmod 0640 ${DIR}/etc/ossec.conf
fi

launchctl unsetenv WAZUH_PKG_UPGRADE

# Install the SCA files
if [ -d "${SCA_FILES_DIR}" ]; then

    if [ "${DIST_NAME}" = "darwin" ]; then
        if [ "${DIST_VER}" != "15" ] && [ "${DIST_VER}" != "16" ] && [ "${DIST_VER}" != "17" ]; then
            DIST_VER=""
        fi
    else
        DIST_NAME="generic"
        DIST_VER=""
    fi

    CONF_ASSESMENT_DIR="${SCA_FILES_DIR}/${DIST_NAME}/${DIST_VER}"
    mkdir -p ${DIR}/ruleset/sca

    # Install the configuration files needed for this hosts
    if [ -r ${CONF_ASSESMENT_DIR}/sca.files ]; then

        for sca_file in $(cat ${CONF_ASSESMENT_DIR}/sca.files); do
            mv ${SCA_FILES_DIR}/${sca_file} ${DIR}/ruleset/sca
        done
        # Set correct permissions, owner and group
        find ${DIR}/ruleset/sca/ -type f -exec chmod 640 {} \;
        chown -R root:${GROUP} ${DIR}/ruleset/sca
        # Delete the temporary directory
        rm -rf ${SCA_FILES_DIR}
    fi
fi

# Register and configure agent if Wazuh environment variables are defined
${INSTALLATION_SCRIPTS_DIR}/src/init/register_configure_agent.sh > /dev/null || :

# Install the service
${INSTALLATION_SCRIPTS_DIR}/src/init/darwin-init.sh

# Remove temporary directory
rm -rf ${DIR}/packages_files

if [ -n "$(cat ${DIR}/etc/client.keys)" ]; then
    ${DIR}/bin/ossec-control restart
fi
