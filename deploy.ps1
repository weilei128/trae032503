# 部署配置
$serverIp = "49.235.161.106"
$sshPort = "22"
$username = "root"
$remoteDir = "/opt/apps/memo-app"
$jarFile = "target/dogFooding.jar"
$dockerFile = "dogFooding_Dockerfile"
$dataDir = "data"
$imageName = "market-app"
$containerName = "market-app-container"
$port = "10011"

Write-Host "=== 开始部署 ===" -ForegroundColor Cyan

# 检查本地文件是否存在
if (-not (Test-Path $jarFile)) {
    Write-Host "错误: JAR文件不存在 - $jarFile" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $dockerFile)) {
    Write-Host "错误: Dockerfile不存在 - $dockerFile" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $dataDir)) {
    Write-Host "警告: data目录不存在 - $dataDir" -ForegroundColor Yellow
}

Write-Host "1. 上传文件到服务器..." -ForegroundColor Cyan

# 创建远程目录
ssh -p $sshPort ${username}@${serverIp} "mkdir -p ${remoteDir}"

# 上传文件
scp -P $sshPort $jarFile ${username}@${serverIp}:${remoteDir}/
scp -P $sshPort $dockerFile ${username}@${serverIp}:${remoteDir}/
scp -P $sshPort -r $dataDir ${username}@${serverIp}:${remoteDir}/

Write-Host "2. 远程执行部署命令..." -ForegroundColor Cyan

$remoteCommand = @"
cd ${remoteDir}

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker未安装"
    exit 1
fi

# 检查端口是否被占用
echo "检查端口 ${port} 是否被占用..."
if lsof -Pi :${port} -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "端口 ${port} 被占用，查找并停止相关容器..."
    CONTAINER_ID=\$(docker ps --filter "publish=${port}" -q)
    if [ -n "\$CONTAINER_ID" ]; then
        echo "停止容器: \$CONTAINER_ID"
        docker stop \$CONTAINER_ID
        docker rm \$CONTAINER_ID
    fi
fi

# 检查是否有同名容器在运行
if docker ps -a --format '{{.Names}}' | grep -Eq "^${containerName}\$"; then
    echo "停止并删除已存在的容器: ${containerName}"
    docker stop ${containerName} 2>/dev/null || true
    docker rm ${containerName} 2>/dev/null || true
fi

# 检查是否有同名镜像
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -Eq "^${imageName}:1.0.0\$"; then
    echo "删除已存在的镜像: ${imageName}:1.0.0"
    docker rmi ${imageName}:1.0.0 2>/dev/null || true
fi

# 构建镜像
echo "构建Docker镜像: ${imageName}:1.0.0"
docker build -f dogFooding_Dockerfile -t ${imageName}:1.0.0 .

# 运行容器
echo "启动容器: ${containerName}"
docker run -d \
    --name ${containerName} \
    --restart=always \
    -p ${port}:${port} \
    -e JAVA_OPTS="-Xms256m -Xmx512m" \
    ${imageName}:1.0.0

# 等待容器启动
echo "等待容器启动..."
sleep 10

# 检查容器状态
if docker ps --format '{{.Names}}' | grep -Eq "^${containerName}\$"; then
    echo "容器启动成功!"
    docker ps --filter "name=${containerName}"
    
    # 检查应用是否响应
    echo "检查应用健康状态..."
    for i in {1..30}; do
        if curl -s http://localhost:${port} >/dev/null 2>&1; then
            echo "应用服务正常运行!"
            break
        fi
        echo "等待应用就绪... (\$i/30)"
        sleep 2
    done
else
    echo "容器启动失败!"
    docker logs ${containerName}
    exit 1
fi
"@

ssh -p $sshPort ${username}@${serverIp} $remoteCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== 部署成功 ===" -ForegroundColor Green
    Write-Host "应用访问地址: http://${serverIp}:${port}" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "=== 部署失败 ===" -ForegroundColor Red
    exit 1
}
