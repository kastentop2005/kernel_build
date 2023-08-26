#!/bin/bash
#
# Kernel compilation script for Camellia (Redmi Note 10 5G/Redmi Note 10T/POCO M3 Pro)
# Copyright (C) 2023 Konstantin Lipinskiy

###### Initial configuration begin ######
# Colors
normal='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
orange='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
lightred='\033[1;31m'
lightgreen='\033[1;32m'
lightblue='\033[1;34m'
lightpurple='\033[1;35m'
lightcyan='\033[1;36m'
white='\033[1;37m'

# Variables
SECONDS=0 # Built-in bash timer
zipname="OSS-Camellia-$(date '+%Y%m%d-%H%M').zip" # Zip name (Name + date)
tc="$HOME/tc/proton-clang" # Toolchain path
defconfig="camellia_defconfig" # Defconfig to use
logfile="$HOME/build.log"

# Exports
export PATH="$tc/bin:$PATH" # Expose toolchain path to system
###### Initial configuration end ######

# make clean
if [[ $1 = "-c" || $1 = "--clean" ]]; then
    make clean
fi

###### Toolchain setup begin ######
toolchain_setup () {
if ! [ -d "$tc" ]; then
printf "${lightblue} Toolchain was not found. Cloning...${normal}\n"
    if ! git clone --depth=1 --single-branch https://github.com/kdrag0n/proton-clang $tc; then
    printf "${lightred} Cloning toolchain has failed! Aborting...${normal}\n"
    exit 1
    fi
fi

# Check for dependencies
for dep in lld bc
do
    if ! command -v $dep; then
    printf "Installing $dep...\n"
        sudo apt install -y $dep;
    fi
done
}

###### Toolchain setup end ######

###### Build begin ######
build () {
mkdir -p out
make O=out ARCH=arm64 $defconfig
printf "${lightblue}Starting compilation...{$normal}\n"
make -j$(nproc --all) \
                    O=out \
                    ARCH=arm64 \
                    CC=clang \
                    LD=ld.lld \
                    AR=llvm-ar \
                    NM=llvm-nm \
                    OBJCOPY=llvm-objcopy \
                    OBJDUMP=llvm-objdump \
                    STRIP=llvm-strip \
                    CROSS_COMPILE=aarch64-linux-gnu- Image.gz-dtb \

# Compilation info
if [ -f "out/arch/arm64/boot/Image.gz" ]; then
    printf "${lightgreen}Build has been succesfully completed in $((SECONDS / 60)):$((SECONDS % 60))${normal}"
else
    printf "${ightred}Compilation has failed!${normal}"
    exit 1
fi
}
###### Build end ######

###### AnyKernel begin ######
anykernel () {
if ! [ -f "out/arch/arm64/boot/Image.gz" ]; then
printf "${lightred}No image to work with, aborting...${normal}"
rm -rf AnyKernel3
exit 1
fi

if ! git clone https://github.com/kastentop2005/AnyKernel3; then
printf "${lightred}Cloning AnyKernel3 repo has failed! Aborting...${normal}"
exit 1
fi

cp out/arch/arm64/boot/Image.gz AnyKernel3
rm -f *zip
cd AnyKernel3
rm -rf out/arch/arm64/boot
zip -r9 "../$zipname" * -x '*.git*' README.md *placeholder
cd ..
rm -rf AnyKernel3
printf "${lightgreen}Zip has been saved as: $zipname${normal}"
}
###### Anykernel end ######

###### Run begin ######
toolchain_setup
build

# Check if anykernel needs to be used
if [[ $2 = "-ak" || $2 = "--anykernel" ]]; then
    anykernel
fi
###### Run end ######
