#!/usr/bin/env bash
# To use an OpenStack cloud you need to authenticate against the Identity
# service named keystone, which returns a **Token** and **Service Catalog**.
# The catalog contains the endpoints for all services the user/tenant has
# access to - such as Compute, Image Service, Identity, Object Storage, Block
# Storage, and Networking (code-named nova, glance, keystone, swift,
# cinder, and neutron).
#
# *NOTE*: Using the 3 *Identity API* does not necessarily mean any other
# OpenStack API is version 3. For example, your cloud provider may implement
# Image API v1.1, Block Storage API v2, and Compute API v2.0. OS_AUTH_URL is
# only for the Identity API served through keystone.

# Clear out any previously sourced OpenStack ENV
for key in $( set | awk '{FS="="}  /^OS_/ {print $1}' ); do unset $key ; done

export OS_AUTH_TYPE=v3applicationcredential
export OS_AUTH_URL=https://keystone.rumble.cloud

# With Keystone you pass the keystone password.
export OS_APPLICATION_CREDENTIAL_ID=1e7cebea32a0411bbb47e3b08e291f5f
export OS_APPLICATION_CREDENTIAL_SECRET=YObyM_BY4jPS2V7Eu3iwpq50FH_MbRI2197J_bMaJh79373wP2sjJYPpCcKo41snIMlGMWyWsvsPNNNeBgzIuA
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3

# If your configuration has multiple regions, we set that information here.
# OS_REGION_NAME is optional and only valid in certain environments.
export OS_REGION_NAME=us-east-1

# If OS_AUTH_URL use private SSL, Please add CACERT file path 
# export OS_CACERT={crtPath}
