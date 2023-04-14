
#Set time zone to Moscow
sudo ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime

# Colors
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

echo -e "${green}"
echo "–––––––––––––––––––––"
echo "Cloning dependencies:"
echo "–––––––––––––––––––––"
echo -e "${restore}"
git clone https://github.com/kdrag0n/proton-clang --depth=1 ~/toolchain/proton-clang
git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 --depth=1 ~/toolchain/gcc
git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9  --depth=1 ~/toolchain/gcc32
git clone https://github.com/kastentop2005/AnyKernel3
echo -e "${green}"
echo "––––"
echo "Done"
echo "––––"
echo -e "${restore}"

IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz
START=$(date +"%s")
KERNEL_DIR=$(pwd)
PATH="${HOME}/toolchain/proton-clang/bin:${HOME}/toolchain/gcc/bin:${HOME}/toolchain/gcc32/bin:${PATH}"
VERSION="$(cat arch/arm64/configs/camellia_defconfig | grep "CONFIG_LOCALVERSION\=" | sed -r 's/.*"(.+)".*/\1/' | sed 's/^.//')"
export KBUILD_BUILD_HOST=Instance
export KBUILD_BUILD_USER="Konnlori"
ZIPNAME="$VERSION-camellia-$(date +%Y%m%d-%H%M).zip"

# Compile plox
function compile() {
    make O=out ARCH=arm64 camellia_defconfig
    make -j$(nproc --all) O=out \
                    ARCH=arm64 \
                    CC=clang \
                    CLANG_TRIPLE=aarch64-linux-gnu- \
                    CROSS_COMPILE=aarch64-linux-android- \
                    CROSS_COMPILE_ARM32=arm-linux-androideabi-

    if ! [ -a "$IMAGE" ]; then
        exit 1
    fi
    cp out/arch/arm64/boot/Image.gz AnyKernel
}
# Zipping
function zipping() {
    cd AnyKernel3 || exit 1
    rm -rf *.zip
    zip -r9 $ZIPNAME *
    cd ..
}

compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
echo -e "${green}"
echo "----------------------------------------------"
echo "Build Completed in: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo "----------------------------------------------"
echo -e "${restore}"
