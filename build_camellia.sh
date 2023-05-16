#!/bin/bash
#
# Kernel compilation script for Camellia (Redmi Note 10 5G/Redmi Note 10T/POCO M3 Pro)
# Copyright (C) 2023 Konstantin Lipinskiy

###### Initial configuration begin ######
# Colors
Red=$'\e[1;31m'
Green=$'\e[1;32m'
Blue=$'\e[1;34m'
# Variables
SECONDS=0 # Built-in bash timer
zipname="OSS-Camellia-$(date '+%Y%m%d-%H%M').zip" # How to name the zip (Name + date)
tc="$HOME/tc/proton-clang" # Toolchain path
defconfig="camellia_defconfig" # Which defconfig to use
export PATH="$tc/bin:$PATH" # Expose toolchain path to system
# Extra
anykernel=1 # 0 - do not use AnyKernel; 1 - use AnyKernel
###### Initial configuration end ######

###### Toolchain setup begin ######
toolchain_setup () {
if ! [ -d "$tc" ]; then
echo "$Green Toolchain was not found. Cloning..."
if ! git clone --depth=1 --single-branch https://github.com/kdrag0n/proton-clang $tc; then
echo "$Red Cloning toolchain has failed! Aborting..."
exit 1
fi
fi
}
###### Toolchain setup end ######

# make clean
if [[ $1 = "-c" || $1 = "--clean" ]]; then
rm -rf out
fi

###### Build begin ######
build () {
mkdir -p out
make O=out ARCH=arm64 $defconfig
echo -e "$Blue\nStarting compilation...\n"
make -j$(nproc --all)
                    O=out \
                    ARCH=arm64 \
                    CC=clang \
                    LD=ld.lld \
                    AR=llvm-ar \
                    NM=llvm-nm \
                    OBJCOPY=llvm-objcopy \
                    OBJDUMP=llvm-objdump \
                    STRIP=llvm-strip \
                    CROSS_COMPILE=aarch64-linux-gnu- Image.gz

# Compilation info
if [ -f "out/arch/arm64/boot/Image.gz" ]; then
    echo -e "$Green\nBuild has been succesfully completed in $((SECONDS / 60)):$((SECONDS % 60))"
else
    echo -e "$Red\nCompilation failed!"
fi
}
###### Build end ######

###### AnyKernel begin ######
anykernel () {
if ! git clone https://github.com/kastentop2005/AnyKernel3; then
echo -e "$Red\nCloning AnyKernel3 repo has failed! Aborting..."
exit 1
fi
cp out/arch/arm64/boot/Image.gz AnyKernel3
rm -f *zip
cd AnyKernel3
rm -rf out/arch/arm64/boot
zip -r9 "../$zipname" * -x '*.git*' README.md *placeholder
cd ..
rm -rf AnyKernel3
echo "$Green Zip was saved as: $zipname"
}
###### Anykernel end ######

###### Run begin ######
toolchain_setup
build
# Check if anykernel needs to be used
if [ "$ANYKERNEL" -eq "1" ]; then
    anykernel;
fi
###### Run end ######

