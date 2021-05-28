#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: Vaisakh Murali

echo "******************************"
echo "* Building Bleeding Edge GCC *"
echo "******************************"

# TODO: Add more dynamic option handling
while getopts a: flag; do
  case "${flag}" in
    a) arch=${OPTARG} ;;
  esac
done

# TODO: Better target handling
case "${arch}" in
  "arm") TARGET="arm-eabi" ;;
  "arm64") TARGET="aarch64-elf" ;;
  "x86") TARGET="x86_64-elf" ;;
esac

export WORK_DIR="$PWD"
export PREFIX="$PWD/../gcc-${arch}"
export PATH="$PREFIX/bin:$PATH"

echo "Building Bare Metal Toolchain for ${arch} with ${TARGET} as target"

download_resources() {
  echo "Downloading Pre-requisites"
  git clone git://sourceware.org/git/binutils-gdb.git -b master binutils --depth=1
  git clone https://git.linaro.org/toolchain/gcc.git -b master gcc --depth=1
  cd ${WORK_DIR}
}

build_binutils() {
  cd ${WORK_DIR}
  echo "Building Binutils"
  mkdir build-binutils
  cd build-binutils
  ../binutils/configure --target=$TARGET \
    --prefix="$PREFIX" \
    --with-sysroot \
    --disable-nls \
    --disable-docs \
    --disable-werror \
    --disable-gdb \
    --enable-gold \
    --with-pkgversion="Ngentod BinUtils"
  make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" -j$(($(nproc --all) + 2))
  make install -j$(($(nproc --all) + 2))
  cd ../
}

build_gcc() {
  cd ${WORK_DIR}
  echo "Building GCC"
  cd gcc
  ./contrib/download_prerequisites
  cd ../
  mkdir build-gcc
  cd build-gcc
  ../gcc/configure --target=$TARGET \
    --prefix="$PREFIX" \
    --disable-decimal-float \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libstdcxx-pch \
    --disable-nls \
    --disable-shared \
    --disable-docs \
    --enable-default-ssp \
    --enable-languages=c,c++ \
    --with-pkgversion="Ngentod GCC" \
    --with-newlib \
    --with-gnu-as \
    --with-gnu-ld \
    --with-sysroot
  make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" all-gcc -j$(($(nproc --all) + 2))
  make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" all-target-libgcc -j$(($(nproc --all) + 2))
  make install-gcc -j$(($(nproc --all) + 2))
  make install-target-libgcc -j$(($(nproc --all) + 2))

}

push_gcc() {
    if [ $TARGET = "aarch64-elf" ]
	git clone https://github.com/silont-project/aarch64-elf-gcc /drone/src/gcc_push -b arm64/10
	rm -rf /drone/src/gcc_push/*
	cp /drone/src/aarch64-elf/* /drone/src/gcc_push -rf
	cd /drone/src/gcc_push && git add .
	git commit -s -m ""[DroneCI]: NGenToD GCC $(date +%d%m%y)""
	git push -q https://$GH_TOKEN@github.com/silont-project/aarch64-elf-gcc.git arm64/10
    else
        git clone https://github.com/silont-project/arm-eabi-gcc /drone/src/gcc_push -b arm/10
        rm -rf /drone/src/gcc_push/*
        cp /drone/src/arm-eabi/* /drone/src/gcc_push -rf
        cd /drone/src/gcc_push && git add .
        git commit -s -m ""[DroneCI]: NGenToD GCC $(date +%d%m%y)""
        git push -q https://$GH_TOKEN@github.com/silont-project/arm-eabi-gcc.git arm/10
}

download_resources
build_binutils
build_gcc

push_gcc
