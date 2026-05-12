#!/bin/bash

set -euo pipefail

case "${CONFIGURATION:-}" in
	Debug*) ;;
	*) exit 0 ;;
esac

ARTIFACT_URL="https://github.com/LookInsideApp/LookInside-Release/releases/download/0.2.2/LookInsideServer.xcframework.zip"
ARTIFACT_CHECKSUM="7a54f2a6292dcd127be26d181878f809cae90cdbcd65f47e1b9eb59e6776f860"
ARTIFACT_NAME="LookInsideServer.xcframework"

cache_base="${TARGET_TEMP_DIR:-${PROJECT_TEMP_DIR:-${TMPDIR:-/tmp}}}/LookInsideServerArtifact"
cache_root="${cache_base}/${ARTIFACT_CHECKSUM}"
zip_path="${cache_root}/${ARTIFACT_NAME}.zip"
xcframework_path="${cache_root}/${ARTIFACT_NAME}"

download_artifact_if_needed() {
	if [ -d "${xcframework_path}" ]; then
		return
	fi

	mkdir -p "${cache_base}" "${cache_root}"

	local staging_dir
	staging_dir="$(mktemp -d "${cache_base}/staging.XXXXXX")"
	trap 'rm -rf "${staging_dir}"' RETURN

	local staging_zip="${staging_dir}/${ARTIFACT_NAME}.zip"
	echo "Downloading ${ARTIFACT_NAME}"
	curl --fail --location --retry 3 --retry-delay 1 --output "${staging_zip}" "${ARTIFACT_URL}"
	echo "${ARTIFACT_CHECKSUM}  ${staging_zip}" | shasum -a 256 -c -

	ditto -x -k "${staging_zip}" "${staging_dir}"
	if [ ! -d "${staging_dir}/${ARTIFACT_NAME}" ]; then
		echo "Downloaded archive did not contain ${ARTIFACT_NAME}" >&2
		exit 1
	fi

	rm -rf "${xcframework_path}" "${zip_path}"
	mv "${staging_dir}/${ARTIFACT_NAME}" "${xcframework_path}"
	cp "${staging_zip}" "${zip_path}"
}

slice_identifier() {
	if [ "${EFFECTIVE_PLATFORM_NAME:-}" = "-maccatalyst" ] || [ "${PLATFORM_NAME:-}" = "maccatalyst" ]; then
		echo "ios-arm64_x86_64-maccatalyst"
		return
	fi

	case "${PLATFORM_NAME:-}" in
		iphoneos)
			echo "ios-arm64"
			;;
		iphonesimulator)
			echo "ios-arm64_x86_64-simulator"
			;;
		macosx)
			echo "macos-arm64_x86_64"
			;;
		*)
			echo "Unsupported platform: ${PLATFORM_NAME:-unknown}" >&2
			exit 1
			;;
	esac
}

download_artifact_if_needed

slice="$(slice_identifier)"
source_framework="${xcframework_path}/${slice}/LookInsideServer.framework"
destination_framework="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"

if [ ! -d "${source_framework}" ]; then
	echo "Missing LookInsideServer framework slice: ${source_framework}" >&2
	exit 1
fi

echo "Materializing ${FULL_PRODUCT_NAME} from ${slice}"
rm -rf "${destination_framework}"
ditto "${source_framework}" "${destination_framework}"

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ]; then
	sign_identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
	if [ -z "${sign_identity}" ]; then
		sign_identity="-"
	fi

	/usr/bin/codesign \
		--force \
		--sign "${sign_identity}" \
		--preserve-metadata=identifier,entitlements,flags \
		"${destination_framework}"
fi
