#!/bin/bash

[ -z "$DB_HOST" ] && echo "\$DB_HOST is empty" && exit 1
[ -z "$DB_USERNAME" ] && echo "\$DB_USERNAME is empty" && exit 1
[ -z "$DB_PASSWORD" ] && echo "\$DB_PASSWORD is empty" && exit 1
[ -z "$DB_NAME" ] && echo "\$DB_NAME is empty" && exit 1
[ -z "$AZ_STORAGE_ACCOUNT_KEY" ] && echo "\$AZ_STORAGE_ACCOUNT_KEY is empty" && exit 1
[ -z "$AZ_STORAGE_ACCOUNT_NAME" ] && echo "\$AZ_STORAGE_ACCOUNT_NAME is empty" && exit 1
[ -z "$AZ_STORAGE_CONTAINER_NAME" ] && AZ_STORAGE_CONTAINER_NAME=${DB_NAME,,}-backups
[ -z "$SCHEDULE_NAME" ] && SCHEDULE_NAME="default"

BACKUP_NAME="`date +%Y-%m-%d-%H-%M-%S`"

createBackup () {
    sqlpackage /a:Export /ssn:tcp:$DB_HOST /sdn:$DB_NAME /su:$DB_USERNAME /sp:$DB_PASSWORD /tf:./$BACKUP_NAME.bacpac
}

ensureContainer () {
    az storage container create \
        -n $AZ_STORAGE_CONTAINER_NAME \
        --account-key $AZ_STORAGE_ACCOUNT_KEY \
        --account-name $AZ_STORAGE_ACCOUNT_NAME
}

uploadBackup () {
    az storage blob upload \
    --account-key $AZ_STORAGE_ACCOUNT_KEY \
    --account-name $AZ_STORAGE_ACCOUNT_NAME \
    -f $BACKUP_NAME.bacpac \
    -c $AZ_STORAGE_CONTAINER_NAME \
    -n $SCHEDULE_NAME/$BACKUP_NAME.bacpac
}

rotateBackup () {
    if [[ -z "${BACKUP_RETENTION_COUNT}" ]]; then
        echo "retention not set, skipping backup rotation"
    else
        # tail -n +X starts from Xth line, so add 1
        BACKUP_RETENTION_COUNT=$((BACKUP_RETENTION_COUNT+1))
        rotateBlobs=($( az storage blob list -c $AZ_STORAGE_CONTAINER_NAME --account-key $AZ_STORAGE_ACCOUNT_KEY --account-name $AZ_STORAGE_ACCOUNT_NAME --prefix $SCHEDULE_NAME/ | jq -r 'sort_by(.name) | reverse | .[].name' | tail -n +${BACKUP_RETENTION_COUNT}))
        for k in "${rotateBlobs[@]}"
        do
            echo "deleting $k ..."
            az storage blob delete \
                --account-key $AZ_STORAGE_ACCOUNT_KEY \
                --account-name $AZ_STORAGE_ACCOUNT_NAME \
                -c $AZ_STORAGE_CONTAINER_NAME \
                -n $k
        done
    fi
}

createBackup
ensureContainer
uploadBackup
rotateBackup