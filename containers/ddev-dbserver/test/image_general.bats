#!/usr/bin/env bats

# Run these tests from the repo root directory

load functions.sh

function setup {
  basic_setup

  echo "# Starting container using: docker run --rm -u "$MOUNTUID:$MOUNTGID" --rm -v $VOLUME:/var/lib/mysql --mount "type=bind,src=$PWD/test/testdata,target=/mnt/ddev_config" --name=$CONTAINER_NAME -p $HOSTPORT:3306 -d $IMAGE" >&3
  docker run --rm -u "$MOUNTUID:$MOUNTGID" --rm -v $VOLUME:/var/lib/mysql --mount "type=bind,src=$PWD/test/testdata,target=/mnt/ddev_config" --name=$CONTAINER_NAME -p $HOSTPORT:3306 -d $IMAGE
  containercheck
}

@test "verify apt keys are not expiring within ${DDEV_MAX_DAYS_BEFORE_CERT_EXPIRATION:-90} days" {
  if [ "${DDEV_IGNORE_EXPIRING_KEYS:-}" = "true" ]; then
    skip "Skipping because DDEV_IGNORE_EXPIRING_KEYS is set"
  fi
  if [ "${DB_TYPE:-}" = "mysql" ] && [[ ${DB_VERSION} =~ ^5.[56]$ ]]; then
    skip "Skipping mysql:${DB_VERSION} as its keys are long since expired"
  fi

  docker cp ${TEST_SCRIPT_DIR}/check_key_expirations.sh ${CONTAINER_NAME}:/tmp
  docker exec -u root -e "DDEV_MAX_DAYS_BEFORE_CERT_EXPIRATION=$DDEV_MAX_DAYS_BEFORE_CERT_EXPIRATION" ${CONTAINER_NAME} /tmp/check_key_expirations.sh >&3

}

@test "verify xtrabackup version equal to mysql-server version" {
  if [ "${DB_TYPE:-}" != "mysql" ] && [ ${DB_VERSION} != "8.0" ]; then
    skip "Skipping because not mysql 8.0, so need for the test"
  fi
  mysql_version=$(docker exec ${CONTAINER_NAME} bash -c "mysqld --version | awk {'print $3'}")
  xtrabackup_version=$(docker exec ${CONTAINER_NAME} bash -c "xtrabackup --version 2>&1 | awk '/xtrabackup version/ {print $3}'")
  [ "${mysql_version}" != "" ]
  [ "${xtrabackup_version}" \> "${mysql_version}" ]
}