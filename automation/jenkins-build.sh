#!/bin/bash
VERSION=$(<VERSION)

docker build -t docker-test:$VERSION .

docker run --rm --privileged -e BUILDFLAGS -e DOCKER_CLIENTONLY -e DOCKER_EXECDRIVER -e DOCKER_GRAPHDRIVER -e TESTDIRS -e TESTFLAGS -e TIMEOUT -v "`pwd`:/go/src/github.com/docker/docker" "docker-test:$VERSION" hack/make.sh binary cross

## ARM Build

mkdir -p docker-arm-$VERSION
rm -rf docker-arm-$VERSION.tar
rm -rf docker-arm*.tar.xz

cp bundles/$VERSION/cross/linux/arm/docker-$VERSION docker-arm-$VERSION/docker
tar -cf docker-arm-$VERSION.tar docker-arm-$VERSION && xz docker-arm-$VERSION.tar

## i386 Build
#mkdir -p bundles/docker-386-$VERSION
#rm -rf bundles/docker-386-$VERSION.tar

#cp bundles/$VERSION/cross/linux/386/docker-$VERSION bundles/docker-386-$VERSION/docker
#cd bundles && tar -cf docker-386-$VERSION.tar docker-386-$VERSION && xz docker-386-$VERSION.tar && cd -

#rm -rf docker-386*.tar.xz
#cp bundles/docker-386-$VERSION.tar.xz .
