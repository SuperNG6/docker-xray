#!/bin/bash

set -e

git config --local user.email "action@github.com"
git config --local user.name "GitHub Action"

# 只查询稳定版 (Repo 已改为 XTLS/Xray-core)
RELEASE_TAG=$(curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/XTLS/Xray-core/releases | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 1)

SHOULD_BUILD=false
HAS_CHANGES=false

# 确保文件存在
touch ReleaseTag

# 读取本地
LocalReleaseTag=$(cat ReleaseTag | head -n1)

echo "--- 版本检测 ---"
echo "本地: ${LocalReleaseTag}"
echo "远程: ${RELEASE_TAG}"
echo "----------------"

if [ -n "${RELEASE_TAG}" ] && [ "${LocalReleaseTag}" != "${RELEASE_TAG}" ]; then
    echo "发现新版本: ${RELEASE_TAG}"
    echo "${RELEASE_TAG}" > ReleaseTag
    SHOULD_BUILD=true
    HAS_CHANGES=true
    
    echo "提交更改..."
    git add ReleaseTag
    git commit -m "Update Xray to ${RELEASE_TAG}"
    
    for i in {1..3}; do
        if git pull --rebase && git push; then
            echo "推送成功"
            break
        else
            echo "推送失败，重试 ($i/3)..."
            sleep 2
        fi
    done
else
    echo "无需更新。"
fi

# 输出变量 (简化为 should_build 和 version)
echo "version=${RELEASE_TAG}" >> $GITHUB_OUTPUT
echo "should_build=${SHOULD_BUILD}" >> $GITHUB_OUTPUT