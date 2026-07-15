ARG=$1
API=$(<../../scripts/.current_android_api)
RESOLUTION=$(<../../plugin-tests-support/.android-resolution)
DEVICES_COUNT=2
PROPERTIES_FILE=local.properties
current_directory=$PWD

write_property () {
    if [ ! -f "$PROPERTIES_FILE" ]; then
        touch "$PROPERTIES_FILE"
    fi
    sed -i '' "/$1/d" "$PROPERTIES_FILE"
    echo "$1=$2" >> "$PROPERTIES_FILE"
}

prepare_android_env () {
    export FORCE_API=$API
    . android/emulator/prepare_android_env.sh --run-test-local True --copy-from-resource False
}

if [[ $ARG == "switch-sdk-internal" || $ARG == "bootstrap-ios" ]]; then
    cd ../
    ./scripts/switch_sdk_spi.sh internal
    cd $current_directory
fi

if [[ $ARG == "recreate-android-emulators" || $ARG == "bootstrap-android" ]]; then
    cd ../../scripts
    prepare_android_env
    . android/emulator/create_emulator_from_params.sh "$API" "$DEVICES_COUNT" no
    cd $current_directory
fi

if [[ $ARG == "start-android-emulators" || $ARG == "bootstrap-android" ]]; then
    cd ../../scripts
    prepare_android_env
    for id in $(seq 1 $DEVICES_COUNT)
    do
        . android/emulator/exec_emulator.sh "google-$API-$id" yes no $RESOLUTION
    done
    . android/emulator/await_all_devices_boot.sh "$DEVICES_COUNT"
    cd $current_directory
fi

if [[ $ARG == "build-apk" || $ARG == "bootstrap-android" ]]; then
    cd ..
    ../plugin-tests-support/switch_sdk_spi.sh android/build.gradle internal
    ../plugin-tests-support/switch_sdk_spi.sh internal_test_app/android/app/build.gradle internal
    cd internal_test_app
    flutter build apk --no-obfuscate -v
    cd ..
    ../plugin-tests-support/switch_sdk_spi.sh android/build.gradle public
    ../plugin-tests-support/switch_sdk_spi.sh internal_test_app/android/app/build.gradle public
    cd test
fi

if [[ $ARG == "run-all-tests-android" || $ARG == "bootstrap-android" ]]; then
    export APP_PATH=$PWD/../internal_test_app/build/app/outputs/flutter-apk/app-release.apk
    write_property platform android
    npm install
    ./gradlew test
fi

if [[ $ARG == "recreate-simulators" || $ARG == "bootstrap-ios" ]]; then
    for id in 1 2
    do
        xcrun simctl create "Test Device $id" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-18-5
    done
fi

if [[ $ARG == "build-ios" || $ARG == "bootstrap-ios" ]]; then
    cd ../internal_test_app
    INTERNAL_BUILD=true flutter build ios --no-codesign --simulator --flavor RunnerInternal
    cd ../test
fi

if [[ $ARG == "run-all-tests-ios" || $ARG == "bootstrap-ios" ]]; then
    source ../../scripts/build_web_driver_agent.sh
    export APP_PATH=$PWD/../internal_test_app/build/ios/iphonesimulator/Runner.app
    write_property platform ios
    npm install
    ./gradlew test
fi

if [[ $ARG == "switch-sdk-public" ]]; then
    cd ../
    ./scripts/switch_sdk_spi.sh public
    cd $current_directory
fi
