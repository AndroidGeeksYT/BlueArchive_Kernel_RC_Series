#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
echo "########### Setting set -e ###########"
set -e

# --- Global Variables ---
echo "########### Setting Variables ###########"
kernel_dir="${PWD}"
objdir="${kernel_dir}/out"
anykernel="${HOME}/anykernel"
kernel_name="AndroidGeeks-Kernel-RC3.1"
KERVER=$(make kernelversion) # Assuming make can be run to get version early
zip_name="${kernel_name}-$(date +"%d%m%Y-%H%M")-signed.zip"
TC="${HOME}/toolchains/LLVM-20.1.6-Linux-ARM64" # Toolchain path

echo "########### Exporting Paths and Environment Variables ###########"

export PATH="${TC}/bin:${PATH}"
export CONFIG_FILE="vendor/violet-perf_defconfig"
export ARCH="arm64"
export SUBARCH="arm64"

# Check for ccache and set CC accordingly
if command -v ccache &>/dev/null; then
    export CC="ccache clang"
    echo "########### ccache found, using ccache clang ###########"
else
    export CC="clang"
    echo "########### ccache not found, proceeding with clang only ###########"
fi

export LLVM="1"
export LLVM_IAS="1"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
export LD="aarch64-linux-gnu-ld.bfd"
export KBUILD_BUILD_HOST=ubuntu
export KBUILD_BUILD_USER=AndroidGeeks

# Determine the number of parallel jobs for make
echo "########### Setting Parallel Jobs ###########"
NPROC=4 # Get number of available CPU cores
echo "########### Using ${NPROC} Parallel Jobs for Compilation ###########"

echo "########### Generating Defconfig ###########"
make ARCH="${ARCH}" O="${objdir}" "${CONFIG_FILE}" -j"${NPROC}"

echo "########### Defconfig Generated Successfully ###########"

# Compiling the kernel
echo "########### Compiling the Kernel ###########"
make -j"${NPROC}" \
    O="${objdir}" \
    ARCH="${ARCH}" \
    CC="ccache clang" \
    CLANG_TRIPLE="aarch64-linux-gnu-" \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
    LLVM=1 \
    LLVM_IAS=1 \
    2>&1 | tee error.log

echo "########### Kernel Compilation Complete ###########"

echo "########### Packaging kernel ###########"
COMPILED_IMAGE="${objdir}/arch/arm64/boot/Image.gz-dtb"
COMPILED_DTBO="${objdir}/arch/arm64/boot/dtbo.img"

if [[ ! -f "${COMPILED_IMAGE}" ]]; then
    echo "########### Error: Compiled Image.gz-dtb not found at ${COMPILED_IMAGE} ###########"
    exit 1
fi
if [[ ! -f "${COMPILED_DTBO}" ]]; then
    echo "########### Error: Compiled dtbo.img not found at ${COMPILED_DTBO} ###########"
    exit 1
fi

echo "########### Compiled Image and DTBO Found ###########"
echo "########### Cloning Anykernel3 ###########"
git clone -q https://github.com/AndroidGeeksYT/AnyKernel3.git "${anykernel}"
echo "########### AnyKernel3 Cloned ###########"

# Ensure the AnyKernel directory exists
echo "########### Ensuring AnyKernel Directory Exists ###########"
mkdir -p "${anykernel}"
echo "########### AnyKernel Directory Ensured ###########"

# Move the compiled image and dtbo to the AnyKernel directory
echo "########### Moving Compiled Files to AnyKernel ###########"
mv -f "${COMPILED_IMAGE}" "${COMPILED_DTBO}" "${anykernel}/"
echo "########### Files Moved Successfully ###########"

echo "########### Changing Directory to AnyKernel ###########"
cd "${anykernel}"

# Delete any existing zip files from a previous run within AnyKernel directory
echo "########### Removing Existing Zip Files in AnyKernel Directory ###########"
find . -maxdepth 1 -name "*.zip" -type f -delete

# Create the AnyKernel zip
echo "########### Creating AnyKernel.zip ###########"
zip -r AnyKernel.zip ./*

# Download zipsigner
echo "########### Downloading Zipsigner ###########"
curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar

# Sign the ZIP file
echo "########### Signing Zip File ###########"
java -jar zipsigner-3.0.jar AnyKernel.zip AnyKernel-signed.zip

echo "########### Zip Signed Successfully ###########"

# Rename and move the final signed zip
echo "########### Renaming and Moving Final Signed Zip ###########"
mv AnyKernel-signed.zip "${zip_name}"
mv "${zip_name}" "${HOME}/${zip_name}"

echo "########### Kernel packaged and signed successfully! Final ZIP: ${HOME}/${zip_name} ###########"

# Clean up the AnyKernel repository
echo "########### Cleaning Up AnyKernel Repository ###########"
rm -rf "${anykernel}"
echo "########### All Done! ###########"
