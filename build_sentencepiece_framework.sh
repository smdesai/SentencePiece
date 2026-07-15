#!/bin/bash
# Build SentencePiece as an XCFramework for Swift integration
# Targets: iOS arm64, iOS Simulator (arm64 + x86_64), macOS (arm64 + x86_64)

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
mkdir -p build-ios-arm64 build-ios-sim-arm64 build-ios-sim-x86_64 build-macos-arm64 build-macos-x86_64

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

# Build for macOS x86_64
echo "Building for macOS x86_64..."
cd build-macos-x86_64
cmake .. $COMMON_FLAGS \
         -DCMAKE_OSX_ARCHITECTURES="x86_64" \
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

# Build for iOS Simulator x86_64
echo "Building for iOS Simulator x86_64..."
cd build-ios-sim-x86_64
cmake .. $COMMON_FLAGS \
         -DCMAKE_TOOLCHAIN_FILE=../cmake/ios.toolchain.cmake \
         -DPLATFORM=SIMULATOR64 \
         -DDEPLOYMENT_TARGET=14.0
make -j8
cd ..

# Create self-contained framework binaries by linking the C bridge, SentencePiece,
# and Abseil into one object per architecture, then wrapping that object in a
# static archive. Linking with -r pulls in only the archive members needed by the
# bridge instead of embedding every object from every libabsl_*.a archive.
echo "Creating self-contained SentencePiece framework binaries..."
mkdir -p build-universal

make_framework_archive() {
    local build_dir=$1
    local arch=$2
    local sdk=$3
    local min_version_flag=$4
    local output=$5
    local bridge_object="build-universal/SentencePieceBridge-${arch}-${sdk}.o"
    local linked_object="build-universal/SentencePieceLinked-${arch}-${sdk}.o"
    local sdk_root
    sdk_root=$(xcrun --sdk "$sdk" --show-sdk-path)

    local include_flags=(
        -I ../SentencePieceWrapper
        -I src
        -I "$build_dir/src"
        -I "$build_dir"
        -I .
        -I third_party
        -I src/builtin_pb
    )

    local graph_file
    graph_file="$(pwd)/build-universal/targets-${arch}-${sdk}.dot"
    (
        cd "$build_dir"
        cmake --graphviz="$graph_file" . >/dev/null
    )

    local absl_libs=()
    while IFS= read -r target; do
        local absl_lib
        absl_lib=$(find "$build_dir/third_party/abseil-cpp" -name "lib${target}.a" -print -quit)
        if [ -n "$absl_lib" ]; then
            absl_libs+=("$absl_lib")
        fi
    done < <(perl -ne '
if (/^\s+"([^"]+)" \[ label = "([^"\\]+)(?:\\n\([^"]+\))?"/) {
    $label{$1} = $2;
    $root = $1 if $2 eq "sentencepiece-static";
}
if (/^\s+"([^"]+)" -> "([^"]+)"/) {
    push @{$edge{$1}}, $2;
}
END {
    die "Unable to find sentencepiece-static in CMake graph\n" unless $root;
    @queue = ($root);
    while (@queue) {
        $node = shift @queue;
        next if $seen{$node}++;
        $target = $label{$node} || "";
        print "$target\n" if $target =~ /^absl_/;
        push @queue, @{$edge{$node} || []};
    }
}
' "$graph_file")

    echo "  Linking $(basename "$output") from libsentencepiece.a and ${#absl_libs[@]} Abseil archives..."
    xcrun --sdk "$sdk" clang++ -c ../SentencePieceWrapper/SentencePieceBridge.cpp \
        -std=c++17 \
        -arch "$arch" \
        -isysroot "$sdk_root" \
        "$min_version_flag" \
        "${include_flags[@]}" \
        -o "$bridge_object"

    xcrun --sdk "$sdk" clang++ -r -nostdlib \
        -arch "$arch" \
        -isysroot "$sdk_root" \
        -o "$linked_object" \
        "$bridge_object" \
        "$build_dir/src/libsentencepiece.a" \
        "${absl_libs[@]}"

    xcrun --sdk "$sdk" libtool -no_warning_for_no_symbols -static -o "$output" "$linked_object"
}

make_framework_archive build-macos-arm64      arm64  macosx          -mmacosx-version-min=14.0          build-universal/complete-macos-arm64.a
make_framework_archive build-macos-x86_64     x86_64 macosx          -mmacosx-version-min=14.0          build-universal/complete-macos-x86_64.a
make_framework_archive build-ios-arm64        arm64  iphoneos        -miphoneos-version-min=14.0        build-universal/libsentencepiece-ios.a
make_framework_archive build-ios-sim-arm64    arm64  iphonesimulator -mios-simulator-version-min=14.0   build-universal/complete-ios-sim-arm64.a
make_framework_archive build-ios-sim-x86_64   x86_64 iphonesimulator -mios-simulator-version-min=14.0   build-universal/complete-ios-sim-x86_64.a

# Universal macOS binary (arm64 + x86_64)
echo "  Creating universal macOS binary..."
lipo -create \
    build-universal/complete-macos-arm64.a \
    build-universal/complete-macos-x86_64.a \
    -output build-universal/libsentencepiece-macos.a

# Universal iOS Simulator binary (arm64 + x86_64)
echo "  Creating universal iOS Simulator binary..."
lipo -create \
    build-universal/complete-ios-sim-arm64.a \
    build-universal/complete-ios-sim-x86_64.a \
    -output build-universal/libsentencepiece-ios-sim.a

# Create framework structure
FRAMEWORK_NAME="SentencePiece"
FRAMEWORK_DIR="${FRAMEWORK_NAME}.framework"

rm -rf "${FRAMEWORK_DIR}"
mkdir -p "${FRAMEWORK_DIR}/Headers"
mkdir -p "${FRAMEWORK_DIR}/Modules"

# Copy the C bridge header. The framework intentionally exposes this stable C
# API, not SentencePiece's C++ headers, so consumers do not need Abseil headers.
echo "Copying headers..."
cp ../SentencePieceWrapper/SentencePieceBridge.h "${FRAMEWORK_DIR}/Headers/"

# Create module map
echo "Creating module map..."
cat > "${FRAMEWORK_DIR}/Modules/module.modulemap" << EOF
framework module SentencePiece {
    umbrella header "SentencePiece.h"
    
    export *
    module * { export * }
    
    link "c++"
    link framework "CoreFoundation"
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

#include <SentencePieceBridge.h>

#endif /* SENTENCEPIECE_H */
EOF

# Create XCFramework
echo "Creating XCFramework..."

# Library paths for each platform (using universal binaries where applicable)
MACOS_LIB_PATH="build-universal/libsentencepiece-macos.a"
IOS_LIB_PATH="build-universal/libsentencepiece-ios.a"
IOS_SIM_LIB_PATH="build-universal/libsentencepiece-ios-sim.a"

# Verify all libraries exist
for lib in "$MACOS_LIB_PATH" "$IOS_LIB_PATH" "$IOS_SIM_LIB_PATH"; do
    if [ ! -f "$lib" ]; then
        echo "Error: Library not found at $lib"
        exit 1
    fi
done

echo "Found all libraries:"
echo "  macOS (arm64 + x86_64): $MACOS_LIB_PATH"
echo "  iOS (arm64): $IOS_LIB_PATH"
echo "  iOS Simulator (arm64 + x86_64): $IOS_SIM_LIB_PATH"

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

# macOS frameworks must use the versioned bundle layout (Versions/A + symlinks),
# NOT the shallow iOS-style layout. Otherwise embedding into a macOS .app fails with
# "expected Versions/Current/Resources/Info.plist since the platform does not use
# shallow bundles". iOS/simulator stay shallow (correct for those platforms).
versionize_macos_framework() {
    local fw=$1
    [ -e "$fw/Versions" ] && return 0
    ( cd "$fw" || exit 1
      mkdir -p Versions/A/Resources
      mv Headers Modules SentencePiece Versions/A/
      mv Info.plist Versions/A/Resources/Info.plist
      ln -s A Versions/Current
      ln -s Versions/Current/Headers Headers
      ln -s Versions/Current/Modules Modules
      ln -s Versions/Current/Resources Resources
      ln -s Versions/Current/SentencePiece SentencePiece )
}

# Create platform-specific frameworks
echo "Creating platform-specific frameworks..."
create_platform_framework "$MACOS_LIB_PATH" "$MAC_FRAMEWORK"
versionize_macos_framework "$MAC_FRAMEWORK"
create_platform_framework "$IOS_LIB_PATH" "$IOS_FRAMEWORK"
create_platform_framework "$IOS_SIM_LIB_PATH" "$IOS_SIM_FRAMEWORK"

# Create XCFramework with all three platforms
echo "Creating XCFramework with macOS (arm64 + x86_64), iOS arm64, and iOS Simulator (arm64 + x86_64)..."
xcodebuild -create-xcframework \
    -framework "$MAC_FRAMEWORK" \
    -framework "$IOS_FRAMEWORK" \
    -framework "$IOS_SIM_FRAMEWORK" \
    -output "../SentencePiece.xcframework"

# Clean up temporary frameworks and universal binaries
rm -rf temp-frameworks
rm -rf build-universal

echo "SentencePiece.xcframework created successfully!"
