#!/bin/bash
# Script make by Mạnh Dương

# Make requests like send from Firefox Android 
req() {
    wget --header="User-Agent: Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0" \
         --header="Content-Type: application/octet-stream" \
         --header="Accept-Language: en-US,en;q=0.9" \
         --header="Connection: keep-alive" \
         --header="Upgrade-Insecure-Requests: 1" \
         --header="Cache-Control: max-age=0" \
         --header="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" \
         --keep-session-cookies --timeout=30 -nv -O "$@"
}

# Find max version
max() {
    local max=0
    while read -r v || [ -n "$v" ]; do
        if [[ ${v//[!0-9]/} -gt ${max//[!0-9]/} ]]; then max=$v; fi
    done
    if [[ $max = 0 ]]; then echo ""; else echo "$max"; fi
}

# Read highest supported versions from Revanced 
get_supported_versions() {
    package_name=$1
    output=$(java -jar revanced-cli*.jar list-versions -f "$package_name" patch*.rvp)
    echo "$output" | tail -n +3 | sed 's/ (.*)//' | grep -v -w "Any" | sort -V -r
}

# Download necessary resources to patch from Github latest release 
download_resources() {
    for repo in revanced-patches revanced-cli; do
        githubApiUrl="https://api.github.com/repos/inotia00/$repo/releases/latest"
        page=$(req - 2>/dev/null $githubApiUrl)
        assetUrls=$(echo $page | jq -r '.assets[] | select(.name | endswith(".asc") | not) | "\(.browser_download_url) \(.name)"')
        while read -r downloadUrl assetName; do
            req "$assetName" "$downloadUrl" 
        done <<< "$assetUrls"
    done
}

download_resources

# Get all supported versions in descending order
supported_versions=$(get_supported_versions "com.google.android.youtube")

# Find the version URL for the highest supported version
url="https://youtube.en.uptodown.com/android/versions"
data_code=$(req - "$url" | grep 'detail-app-name' | grep -oP '(?<=data-code=")[^"]+')
page=1
found_version=""
while :; do
    json=$(req - "https://youtube.en.uptodown.com/android/apps/$data_code/versions/$page" | jq -r '.data')
        
    # Exit if no valid JSON or no more pages
    [ -z "$json" ] && break
        
    # Loop through supported versions to find the first available version_url
    for version in $supported_versions; do
        version_url=$(echo "$json" | jq -r --arg version "$version" '[.[] | select(.version == $version and .kindFile == "apk")][0].versionURL // empty')
        if [ -n "$version_url" ]; then
            found_version=$version
            break
        fi
    done
        
    # If a version_url is found, download the APK and exit
    if [ -n "$found_version" ]; then
        download_url=$(req - "${version_url}-x" | grep -oP '(?<=data-url=")[^"]+')
        [ -n "$download_url" ] && req "youtube-v$found_version.apk" "https://dw.uptodown.com/dwn/$download_url"
        break
    fi
        
    # Check if all versions are less than the lowest supported version
    lowest_supported_version=$(echo "$supported_versions" | tail -n 1)
    all_lower=$(echo "$json" | jq -r --arg version "$lowest_supported_version" '.[] | select(.kindFile == "apk") | .version | select(. < $version)' | wc -l)
    total_versions=$(echo "$json" | jq -r '.[] | select(.kindFile == "apk") | .version' | wc -l)
    [ "$all_lower" -eq "$total_versions" ] && break

    page=$((page + 1))
done