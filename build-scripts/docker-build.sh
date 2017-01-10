export DOCKER_ENV=test
export PIPELINE_BUILD=1

echo PIPELINE BUILD: $PIPELINE_BUILD

rm -rf keys || echo "keys not present"
mkdir keys || echo "keys already exist"
#cp /var/jenkins_home/keys/id_rsa* keys/
#cp ${GIT_DEPLOY_KEY} keys/id_rsa
#cp ${EYAML_PRIVATE_KEY} keys/
#cp ${EYAML_PUBLIC_KEY} keys/

echo $PIPELINE_BUILD > version

docker build --build-arg DOCKER_ENV=${DOCKER_ENV} -t dtr.cucloud.net/cs/petshop-${DOCKER_ENV} .
docker push dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:latest
docker tag dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:latest dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:v_${PIPELINE_BUILD}
docker push dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:v_${PIPELINE_BUILD}
docker rmi dtr.cucloud.net/cs/petshop-${DOCKER_ENV}:v_${PIPELINE_BUILD}
docker images | grep petshop
rm -rf keys || echo "keys have been deleted"