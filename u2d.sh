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

# Read highest supported versions from Revanced 
get_supported_versions() {
    package_name=$1
    java -jar revanced-cli*.jar list-versions -f "$package_name" patch*.rvp | tail -n +3 | sed 's/ (.*)//' | grep -v -w "Any" | sort -Vr
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

supported_versions=($(get_supported_versions "com.google.android.youtube"))

if [ ${#supported_versions[@]} -eq 0 ]; then
    echo "❌ Không tìm thấy phiên bản nào được Revanced hỗ trợ."
    exit 1
fi

echo "🔍 Danh sách phiên bản được hỗ trợ: ${supported_versions[*]}"


url="https://youtube.en.uptodown.com/android/versions"
data_code=$(req - "$url" | grep 'detail-app-name' | grep -oP '(?<=data-code=")[^"]+')
page=1
while :; do
    json=$(req - "https://youtube.en.uptodown.com/android/apps/$data_code/versions/$page" | jq -r '.data')
        
    # Exit if no valid JSON or no more pages
    [ -z "$json" ] && break
        
    # Search for version URL
    # Tìm phiên bản phù hợp trên Uptodown
for supported_version in "${supported_versions[@]}"; do
    version_url=$(echo "$json" | jq -r --arg v "$supported_version" '[.[] | select(.version == $v and .kindFile == "apk")][0].versionURL // empty')
    if [ -n "$version_url" ]; then
        download_url=$(req - "${version_url}-x" | grep -oP '(?<=data-url=")[^"]+')
        if [ -n "$download_url" ]; then
            echo "📥 Đang tải về YouTube phiên bản: $supported_version"
            req "youtube-v$supported_version.apk" "https://dw.uptodown.com/dwn/$download_url"
            exit 0
        fi
    fi
done
    if [ -n "$version_url" ]; then
        download_url=$(req - "${version_url}-x" | grep -oP '(?<=data-url=")[^"]+')
        [ -n "$download_url" ] && req "youtube-v$version.apk" "https://dw.uptodown.com/dwn/$download_url" && break
    fi
        
    # Check if all versions are less than target version
    all_lower=$(echo "$json" | jq -r --arg version "$version" '.[] | select(.kindFile == "apk") | .version | select(. < $version)' | wc -l)
    total_versions=$(echo "$json" | jq -r '.[] | select(.kindFile == "apk") | .version' | wc -l)
    [ "$all_lower" -eq "$total_versions" ] && break

    page=$((page + 1))
done
