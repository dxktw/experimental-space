cat <<EOL > openrc.sh
#!/usr/bin/env bash

# Clear out any previously sourced OpenStack ENV
for key in \$( set | awk '{FS="="}  /^OS_/ {print $1}' ); do unset \$key ; done

export OS_AUTH_TYPE=v3applicationcredential
export OS_AUTH_URL=https://keystone.rumble.cloud
export OS_APPLICATION_CREDENTIAL_ID=1e7cebea32a0411bbb47e3b08e291f5f
export OS_APPLICATION_CREDENTIAL_SECRET=YObyM_BY4jPS2V7Eu3iwpq50FH_MbRI2197J_bMaJh79373wP2sjJYPpCcKo41snIMlGMWyWsvsPNNNeBgzIuA
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
export OS_REGION_NAME=us-east-1
EOL
