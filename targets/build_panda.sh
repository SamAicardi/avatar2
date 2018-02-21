#!/bin/bash
#==========================================================================
# Usage: ./build_panda.sh [build-llvm | build-get-llvm [enable-llvm-debug]] 
#==========================================================================

distr=`cat /etc/issue`
ci_distr="Ubuntu 16.04.3 LTS \n \l"

#============================================
#           Install dependencies
#============================================
echo -e "\e[1m[$(basename $0)] Installing dependencies ...\e[0m"
if [[ "$distr" == "$ci_distr" ]]
then
  sudo sh -c 'echo "deb-src http://archive.ubuntu.com/ubuntu/ xenial-security main restricted" >> /etc/apt/sources.list'
  sudo apt-get update
  sudo apt-get build-dep -y qemu

  # panda-specific deps below, taken from panda/scripts/install_ubuntu.sh
  sudo apt-get -y install python-pip git protobuf-compiler protobuf-c-compiler \
      libprotobuf-c0-dev libprotoc-dev libelf-dev libc++-dev pkg-config
  sudo apt-get -y install software-properties-common
  sudo add-apt-repository -y ppa:phulin/panda

  sudo apt-get -y install subversion
  sudo apt-get -y install libcapstone-dev libdwarf-dev python-pycparser
  
  # TODO: check if required
  sudo apt-get -y install libglib2.0-dev zlib1g-dev
fi


#============================================
#           Install submodules
#============================================
echo -e "\e[1m[$(basename $0)] Installing submodules ...\e[0m"
cd `dirname "$BASH_SOURCE"`/src/
git submodule update --init avatar-panda

cd avatar-panda
git submodule update --init dtc


#============================================
#                    Misc
#============================================
mkdir -p ../../build/panda/panda

# TODO: check if it is required
sudo chown -R vagrant:vagrant ../../ # i.e. /home/vagrant/avatar2/targets


#============================================
#         Download or prepare LLVM
#============================================
# here I am in src/avatar-panda
pushd .
build_llvm=0
if [[ $1 == "build-get-llvm" ]] ; then 
    echo -e "\e[1m[$(basename $0)] Downloading LLVM ...\e[0m"
    build_llvm=1
    cd panda
    svn checkout http://llvm.org/svn/llvm-project/llvm/tags/RELEASE_33/final/ llvm
    cd llvm/tools
    svn checkout http://llvm.org/svn/llvm-project/cfe/tags/RELEASE_33/final/ clang
    cd -
    cd llvm/tools/clang/tools
    svn checkout http://llvm.org/svn/llvm-project/clang-tools-extra/tags/RELEASE_33/final/ extra

else
    if [[ $1 == "build-llvm" ]] ; then 
        echo -e "\e[1m[$(basename $0)] LLVM sub-tree already downloaded. Cleaning ... \e[0m"
        build_llvm=1
        cd panda/llvm
        make clean
    fi
fi
popd # src/avatar-panda


#============================================
#               Install LLVM
#============================================
if [[ $build_llvm -eq 1 ]] ; then
    pushd .
    cd panda/llvm
    if [[ $2 == "enable-llvm-debug" ]] ; then 
        echo -e "\e[1m[$(basename $0)] Configuring and making LLVM in debug mode ...\e[0m"
        ./configure --disable-optimized --enable-debug-runtime --enable-targets=host,arm && REQUIRES_RTTI=1 make -j $(nproc)
    else
        echo -e "\e[1m[$(basename $0)] Configuring and making LLVM in release mode ...\e[0m"
        ./configure --enable-optimized --disable-assertions --enable-targets=host,arm && REQUIRES_RTTI=1 make -j $(nproc)
    fi
    # install llvm3.3 under /usr/local/
    echo -e "\e[1m[$(basename $0)] Installing LLVM in /usr/local/ ...\e[0m"
    sudo make install
    popd
fi


#============================================
#             Install PANDA
#============================================
cd ../../build/panda/panda
if [[ $build_llvm -eq 1 ]] ; then  
    echo -e "\e[1m[$(basename $0)] Installing PANDA with LLVM support ...\e[0m"
    ../../../src/avatar-panda/configure --disable-sdl --target-list=arm-softmmu --enable-llvm --with-llvm=/usr/local
else
    echo -e "\e[1m[$(basename $0)] Installing PANDA (no LLVM support) ...\e[0m"
    ../../../src/avatar-panda/configure --disable-sdl --target-list=arm-softmmu
fi
make -j4

