#!/usr/bin/env bash

echo "******************************"
echo "* Building Bleeding Edge GCC *"
echo "******************************"

while getopts a: flag
do
    case "${flag}" in
        a) arch=${OPTARG};;
    esac
done

case "${arch}" in
    "arm") TARGET="arm-eabi" ;;
    "arm64") TARGET="aarch64-elf" ;;
esac

export WORK_DIR="$PWD"
export PREFIX="$PWD/../gcc-${arch}"
export PATH="$PREFIX/bin:$PATH"

echo "Building Bare Metal Toolchain for ${arch} with ${TARGET} as target"

download_resources () {
    echo "Downloading Pre-requisites"
    git clone git://sourceware.org/git/binutils-gdb.git -b master binutils --depth=1
    git clone https://git.linaro.org/toolchain/gcc.git -b master gcc --depth=1
    git clone git://repo.or.cz/isl.git --depth=1 gcc/isl
    hg clone https://gmplib.org/repo/gmp/ gcc/gmp
    git clone https://gitlab.inria.fr/mpc/mpc.git -b master --depth=1 gcc/mpc
    svn checkout https://scm.gforge.inria.fr/anonscm/svn/mpfr/trunk gcc/mpfr
    cd ${WORK_DIR}
}

build_binutils () {
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
                          --disable-gdb
    make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" -j8
    make install -j8
    cd ../
}

build_gcc () {
    cd ${WORK_DIR}
    echo "Building GCC"
    mkdir build-gcc
    cd build-gcc
    ../gcc/configure --target=$TARGET \
                     --prefix="$PREFIX" \
                     --disable-decimal-float \
                     --disable-libffi \
                     --disable-libgomp \
                     --disable-libmudflap \
                     --disable-libquadmath \
                     --disable-libssp \
                     --disable-libstdcxx-pch \
                     --disable-nls \
                     --disable-shared \
                     --disable-docs \
                     --enable-languages=c,c++ \
                     --with-newlib \
                     --with-gnu-as \
                     --with-gnu-ld \
                     --with-sysroot
    make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" all-gcc -j8
    make CFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" CXXFLAGS="-flto -O3 -pipe -ffunction-sections -fdata-sections" all-target-libgcc -j8
    make install-gcc -j8
    make install-target-libgcc -j8
}

download_resources
build_binutils
build_gcc
