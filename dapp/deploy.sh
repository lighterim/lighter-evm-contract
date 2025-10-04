#!/bin/bash

echo "🚀 部署 MainnetUserTxn DApp"
echo "=========================="

# 检查是否在正确的目录
if [ ! -f "package.json" ]; then
    echo "❌ 错误: 请在 dapp 目录下运行此脚本"
    exit 1
fi

# 安装依赖
echo "📦 安装依赖..."
npm install

# 构建项目
echo "🔨 构建项目..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    echo ""
    echo "📋 部署选项:"
    echo "1. 本地测试: npm run serve"
    echo "2. 开发模式: npm start"
    echo "3. 静态文件位置: ./build/"
    echo ""
    echo "🌐 要启动本地服务器，请运行:"
    echo "   npm run serve"
    echo ""
    echo "📁 构建文件已生成在 ./build/ 目录中"
else
    echo "❌ 构建失败！"
    exit 1
fi

