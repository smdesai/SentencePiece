#!/bin/bash
# Build SentencePiece as an XCFramework for Swift integration
# Targets: iOS arm64, iOS Simulator arm64, macOS arm64

set -e

# Clone SentencePiece if not present
if [ ! -d "sentencepiece" ]; then
    git clone https://github.com/google/sentencepiece.git
fi

cd sentencepiece

# Patch CMakeLists.txt to define set_xcode_property if not using Xcode generator
# This is needed because the macro is only defined in the ios.toolchain.cmake but
# only available when using the Xcode generator
if ! grep -q "macro(set_xcode_property" src/CMakeLists.txt; then
    sed -i.bak '1i\
# Define set_xcode_property macro if not defined (for non-Xcode generators)\
if(NOT COMMAND set_xcode_property)\
  macro(set_xcode_property TARGET XCODE_PROPERTY XCODE_VALUE XCODE_RELVERSION)\
    # No-op when not using Xcode\
  endmacro()\
endif()\
' src/CMakeLists.txt
fi

# Create build directories
mkdir -p build-ios-arm64 build-ios-sim-arm64 build-macos-arm64

# Common CMake flags
COMMON_FLAGS="-DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_CXX_STANDARD=17 \
              -DSPM_ENABLE_SHARED=OFF \
              -DSPM_ENABLE_TCMALLOC=OFF"

# Build for macOS arm64
echo "Building for macOS arm64..."
cd build-macos-arm64
cmake .. $COMMON_FLAGS \
         -DCMAKE_OSX_ARCHITECTURES="arm64" \
         -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
make -j8
cd ..

# Build for iOS arm64 (device)
echo "Building for iOS arm64..."
cd build-ios-arm64
cmake .. $COMMON_FLAGS \
         -DCMAKE_TOOLCHAIN_FILE=../cmake/ios.toolchain.cmake \
         -DPLATFORM=OS64 \
         -DDEPLOYMENT_TARGET=14.0
make -j8
cd ..

# Build for iOS Simulator arm64
echo "Building for iOS Simulator arm64..."
cd build-ios-sim-arm64
cmake .. $COMMON_FLAGS \
         -DCMAKE_TOOLCHAIN_FILE=../cmake/ios.toolchain.cmake \
         -DPLATFORM=SIMULATORARM64 \
         -DDEPLOYMENT_TARGET=14.0
make -j8
cd ..

# Create framework structure
FRAMEWORK_NAME="SentencePiece"
FRAMEWORK_DIR="${FRAMEWORK_NAME}.framework"

rm -rf "${FRAMEWORK_DIR}"
mkdir -p "${FRAMEWORK_DIR}/Headers"
mkdir -p "${FRAMEWORK_DIR}/Modules"

# Copy headers - include all necessary headers for the bridge
echo "Copying headers..."
cp src/sentencepiece_processor.h "${FRAMEWORK_DIR}/Headers/"
cp src/sentencepiece_trainer.h "${FRAMEWORK_DIR}/Headers/"

# Also copy any other headers that might be needed
for header in src/*.h; do
    if [ -f "$header" ]; then
        basename=$(basename "$header")
        # Skip internal/private headers
        if [[ ! "$basename" =~ ^_ ]] && [[ "$basename" != *"internal"* ]]; then
            cp "$header" "${FRAMEWORK_DIR}/Headers/"
        fi
    fi
done

# Copy the protobuf headers that SentencePiece includes
if [ -d "src/builtin_pb" ]; then
    mkdir -p "${FRAMEWORK_DIR}/Headers/builtin_pb"
    cp src/builtin_pb/*.h "${FRAMEWORK_DIR}/Headers/builtin_pb/" 2>/dev/null || true
fi

# Create module map
echo "Creating module map..."
cat > "${FRAMEWORK_DIR}/Modules/module.modulemap" << EOF
framework module SentencePiece {
    umbrella header "SentencePiece.h"
    
    export *
    module * { export * }
    
    link "sentencepiece"
    link "c++"
}
EOF

# Create umbrella header that includes all public headers
cat > "${FRAMEWORK_DIR}/Headers/SentencePiece.h" << EOF
//
//  SentencePiece.h
//  Umbrella header for SentencePiece framework
//

#ifndef SENTENCEPIECE_H
#define SENTENCEPIECE_H

#include <sentencepiece_processor.h>
#include <sentencepiece_trainer.h>

#endif /* SENTENCEPIECE_H */
EOF

# Create XCFramework
echo "Creating XCFramework..."

# Library paths for each platform
MACOS_LIB_PATH="build-macos-arm64/src/libsentencepiece.a"
IOS_LIB_PATH="build-ios-arm64/src/libsentencepiece.a"
IOS_SIM_LIB_PATH="build-ios-sim-arm64/src/libsentencepiece.a"

# Verify all libraries exist
for lib in "$MACOS_LIB_PATH" "$IOS_LIB_PATH" "$IOS_SIM_LIB_PATH"; do
    if [ ! -f "$lib" ]; then
        echo "Error: Library not found at $lib"
        exit 1
    fi
done

echo "Found all libraries:"
echo "  macOS: $MACOS_LIB_PATH"
echo "  iOS: $IOS_LIB_PATH"
echo "  iOS Simulator: $IOS_SIM_LIB_PATH"

# First, remove any existing XCFramework
rm -rf "../SentencePiece.xcframework"

# Create temporary directories for each platform's framework
mkdir -p temp-frameworks/macos
mkdir -p temp-frameworks/ios
mkdir -p temp-frameworks/ios-sim

MAC_FRAMEWORK="temp-frameworks/macos/${FRAMEWORK_NAME}.framework"
IOS_FRAMEWORK="temp-frameworks/ios/${FRAMEWORK_NAME}.framework"
IOS_SIM_FRAMEWORK="temp-frameworks/ios-sim/${FRAMEWORK_NAME}.framework"

# Function to create a framework for a specific platform
create_platform_framework() {
    local lib_path=$1
    local framework_dir=$2
    local framework_name=$(basename "$framework_dir" .framework)
    
    rm -rf "$framework_dir"
    mkdir -p "$framework_dir/Headers"
    mkdir -p "$framework_dir/Modules"
    
    # Copy library with standard framework executable name
    cp "$lib_path" "$framework_dir/SentencePiece"
    
    # Copy headers and module map
    cp -r "${FRAMEWORK_DIR}/Headers/"* "$framework_dir/Headers/"
    cp -r "${FRAMEWORK_DIR}/Modules/"* "$framework_dir/Modules/"
    
    # Create Info.plist for the framework
    cat > "$framework_dir/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SentencePiece</string>
    <key>CFBundleIdentifier</key>
    <string>com.sentencepiece.$framework_name</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SentencePiece</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
PLIST
}

# Create platform-specific frameworks
echo "Creating platform-specific frameworks..."
create_platform_framework "$MACOS_LIB_PATH" "$MAC_FRAMEWORK"
create_platform_framework "$IOS_LIB_PATH" "$IOS_FRAMEWORK"
create_platform_framework "$IOS_SIM_LIB_PATH" "$IOS_SIM_FRAMEWORK"

# Create XCFramework with all three platforms
echo "Creating XCFramework with macOS arm64, iOS arm64, and iOS Simulator arm64..."
xcodebuild -create-xcframework \
    -framework "$MAC_FRAMEWORK" \
    -framework "$IOS_FRAMEWORK" \
    -framework "$IOS_SIM_FRAMEWORK" \
    -output "../SentencePiece.xcframework"

# Clean up temporary frameworks
rm -rf temp-frameworks

echo "SentencePiece.xcframework created successfully!"
