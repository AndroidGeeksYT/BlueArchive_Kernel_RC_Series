#!/bin/env bash

echo "##### Setting #####"

set -e

# Global Variables
echo "##### Setting Global Variables #####"

kernel_dir="${PWD}"
objdir="${kernel_dir}/out"
anykernel="${HOME}/anykernel"
kernel_name="ブルーアーカイブ-Kernel-RC5"
KERVER=$(make kernelversion)
zip_name="${kernel_name}-$(date +"%d%m%Y-%H%M")-signed.zip"

# Export Path and Variables
echo "##### Export Path and Environment Variables #####"

export CONFIG_FILE="vendor/violet-perf_defconfig"
export ARCH="arm64"
export SUBARCH="arm64"
export CC="clang"
export LLVM="1"
export LLVM_IAS="1"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
export LD="aarch64-linux-gnu-ld.bfd"
export KBUILD_BUILD_HOST=ubuntu
export KBUILD_BUILD_USER=AndroidGeeks

# Determine Parallel Jobs
echo "##### Setting Parallel Jobs #####"

NPROC=4

echo "##### ${NPROC} Parallel Jobs #####"

# Generate Defconfig
echo "##### Generating Defconfig ######"

make ARCH="${ARCH}" O="${objdir}" "${CONFIG_FILE}" -j"${NPROC}"

if [[ $? == 0 ]] then
  echo "##### Defconfig Generated Successfully #####"
else
  echo "##### Defconfig Generation Failed #####"
fi

# Compiling the Kernel
echo "##### Starting Kernel Build #####"

make -j"$(nproc)" \
    O="${objdir}" \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    2>&1 | tee error.log

if [[ $? == 0 ]] then
  echo "##### Kernel Build Successfully #####"
else
  echo "##### Kernel Build Failed! #####"
fi

# Changing Directory
echo "##### Changing Directory #####"
cd ${objdir}

# Packaging the Kernel
echo "##### Packaging the Kernel #####"

COMPILED_IMAGE="${objdir}/arch/arm64/boot/Image.gz-dtb"
COMPILED_DTBO="${objdir}/arch/arm64/boot/dtbo.img"

if [[ ! -f "${COMPILED_IMAGE}" ]]; then
    echo "##### Error: Compiled Image.gz-dtb not found at ${COMPILED_IMAGE} #####"
    exit 1
else
	echo "##### Image.gz-dtb Found #####"
fi

if [[ ! -f "${COMPILED_DTBO}" ]]; then
    echo "##### Error: Compiled dtbo.img not found at ${COMPILED_DTBO} #####"
    exit 1
else
	echo "##### Image dtbo.img Found #####"
fi

# Clone Anykernel3
echo "##### Cloning Anykernel3 #####"

git clone -q https://github.com/AndroidGeeksYT/AnyKernel3.git "${anykernel}"

if [[ $? == 0 ]] then
  echo "##### Anykernel Cloned ######"
else
  echo "##### Failed to Clone Anykernel3 #####"
fi

# Move the compiled image and dtbo to the AnyKernel directory
echo "##### Moving Image dtbo.img and Image.gz-dtb #####"

mv -f "${COMPILED_IMAGE}" "${COMPILED_DTBO}" "${anykernel}/"

# Changing Directory
echo "##### Changing Directory #####"

cd "${anykernel}"

# Delete any existing zip files from a previous run within AnyKernel directory
echo "##### Removing Existing Zip Files in AnyKernel Directory #####"

find . -maxdepth 1 -name "*.zip" -type f -delete

# Create the AnyKernel zip
echo "##### Creating AnyKernel.zip #####"

zip -r AnyKernel.zip ./*

# Download zipsigner
echo "##### Downloading Zipsigner #####"

curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar

# Sign the ZIP file
echo "##### Signing Zip File #####"

java -jar zipsigner-3.0.jar AnyKernel.zip AnyKernel-signed.zip

if [[ $? == 0 ]] then
  echo "##### Zip Signed Sucessfully #####"
else
  echo "##### Signing Failed #####"
fi

# Rename and move the final signed zip
echo "########### Renaming and Moving Final Signed Zip ###########"

mv AnyKernel-signed.zip "${zip_name}"
mv "${zip_name}" "${HOME}/${zip_name}"

echo "Kernel packaged and signed successfully! Final ZIP: ${HOME}/${zip_name}"

# Clean up the AnyKernel repository
echo "##### Cleaning Up AnyKernel Repository #####"

rm -rf "${anykernel}"

echo "##### All Done! #####"
