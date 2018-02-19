#!/bin/bash
distr=`cat /etc/issue`
ci_distr="Ubuntu 16.04.3 LTS \n \l"


# Usage: ./build_panda.sh [build-llvm | build-get-llvm [enable-llvm-debug]] 

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

  sudo apt-get -y install libcapstone-dev libdwarf-dev python-pycparser
fi

cd `dirname "$BASH_SOURCE"`/src/
git submodule update --init avatar-panda

cd avatar-panda
git submodule update --init dtc

mkdir -p ../../build/panda/panda

sudo chown -R vagrant:vagrant ../../ # i.e. /home/vagrant/avatar2/targets

# here I am in src/avatar-panda
llvm=0
if [[ $1 == "build-get-llvm" ]] ; then 
    llvm=1
    #cd ../../build/panda/panda
    cd panda
    svn checkout http://llvm.org/svn/llvm-project/llvm/tags/RELEASE_33/final/ llvm
    cd llvm/tools
    svn checkout http://llvm.org/svn/llvm-project/cfe/tags/RELEASE_33/final/ clang
    cd -
    cd llvm/tools/clang/tools
    svn checkout http://llvm.org/svn/llvm-project/clang-tools-extra/tags/RELEASE_33/final/ extra
    cd -
    cd llvm
    if [[ $2 == "enable-llvm-debug" ]] ; then 
        ./configure --disable-optimized --enable-debug-runtime --enable-targets=host,arm && REQUIRES_RTTI=1 make -j $(nproc)
    else
        ./configure --enable-optimized --disable-assertions --enable-targets=host,arm && REQUIRES_RTTI=1 make -j $(nproc)
    fi
    # install llvm3.3 under /usr/local/
    sudo make install
    cd ../../../src/avatar-panda

else
    if [[ $1 == "build-llvm" ]] ; then 
        llvm=1
        # configure LLVM
        #cd ../../build/panda/panda/llvm
        cd panda/llvm
        make clean
        if [[ $2 == "enable-llvm-debug" ]] ; then 
            ./configure --disable-optimized --enable-debug-runtime --enable-targets=host,arm && REQUIRES_RTTI=1 make -j $(nproc)
        else
            ./configure --enable-optimized --disable-assertions --enable-targets=host,arm && REQUIRES_RTTI=1 make -j $(nproc)
        fi
        # install llvm3.3 under /usr/local/
        sudo make install
        cd -
    fi
fi

# it seems the flows does not reach this part
cd ../../build/panda/panda
if [[ $llvm -eq 1 ]] ; then  
    ../../../src/avatar-panda/configure --disable-sdl --target-list=arm-softmmu --enable-llvm --with-llvm=/usr/local
else
    ../../../src/avatar-panda/configure --disable-sdl --target-list=arm-softmmu
fi
make -j4

