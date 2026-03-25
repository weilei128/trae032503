#!/bin/bash

cd /opt/apps/memo-app

# 配置
IMAGE_NAME="market-app"
IMAGE_TAG="1.0.0"
CONTAINER_NAME="market-app-container"
PORT="10011"
JAVA_OPTS="-Xms256m -Xmx512m"

echo "=== 开始远程部署 ==="

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker未安装"
    exit 1
fi

# 检查端口是否被占用
echo "1. 检查端口 ${PORT} 是否被占用..."
if lsof -Pi :${PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "端口 ${PORT} 被占用，查找相关容器..."
    CONTAINER_ID=$(docker ps --filter "publish=${PORT}" -q)
    if [ -n "${CONTAINER_ID}" ]; then
        echo "停止并删除容器: ${CONTAINER_ID}"
        docker stop ${CONTAINER_ID}
        docker rm ${CONTAINER_ID}
    fi
fi

# 检查是否有同名容器
echo "2. 检查是否有同名容器..."
if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
    echo "停止并删除已存在的容器: ${CONTAINER_NAME}"
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
fi

# 检查是否有同名镜像
echo "3. 检查是否有同名镜像..."
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -Eq "^${IMAGE_NAME}:${IMAGE_TAG}$"; then
    echo "删除已存在的镜像: ${IMAGE_NAME}:${IMAGE_TAG}"
    docker rmi ${IMAGE_NAME}:${IMAGE_TAG} 2>/dev/null || true
fi

# 构建镜像
echo "4. 构建Docker镜像: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -f dogFooding_Dockerfile -t ${IMAGE_NAME}:${IMAGE_TAG} .
if [ $? -ne 0 ]; then
    echo "镜像构建失败!"
    exit 1
fi

# 运行容器
echo "5. 启动容器: ${CONTAINER_NAME}"
docker run -d \
    --name ${CONTAINER_NAME} \
    --restart=always \
    -p ${PORT}:${PORT} \
    -e JAVA_OPTS="${JAVA_OPTS}" \
    ${IMAGE_NAME}:${IMAGE_TAG}

if [ $? -ne 0 ]; then
    echo "容器启动失败!"
    exit 1
fi

# 检查容器状态
echo "6. 检查容器状态..."
sleep 5
if docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
    echo "容器启动成功!"
    docker ps --filter "name=${CONTAINER_NAME}"
    
    # 等待应用完全启动
    echo "7. 等待应用就绪..."
    for i in {1..30}; do
        if curl -s http://localhost:${PORT} >/dev/null 2>&1; then
            echo ""
            echo "========================================"
            echo "     应用服务正常运行!"
            echo "========================================"
            echo ""
            break
        fi
        echo "等待应用就绪... ${i}/30"
        sleep 2
    done
else
    echo "容器启动失败!"
    docker logs ${CONTAINER_NAME}
    exit 1
fi

echo ""
echo "=== 部署完成 ==="
exit 0
