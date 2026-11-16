# Week 5 - Docker single container
# Run:  powershell -ExecutionPolicy Bypass -File .\week5-docker-single.ps1 <dockerhub-username>
param([string]$HubUser)

function Run([scriptblock]$sb) {
    Write-Host ("PS> " + $ExecutionContext.InvokeCommand.ExpandString($sb.ToString().Trim())) -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    & $sb
    if ($LASTEXITCODE -ne 0) {
        if ((Read-Host "Error above. Continue? (y/n)") -ne 'y') { exit 1 }
    }
}
function Next { Read-Host "`nPress Enter" | Out-Null }

# start Docker Desktop if the engine is not running
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    do { Start-Sleep 5; docker info *> $null } until ($LASTEXITCODE -eq 0)
}
if (-not $HubUser) { $HubUser = Read-Host 'Docker Hub username (Enter to skip push)' }
docker rm -f my-redis myredisnew myredis *> $null

# ---- Part A ----
Run { docker pull redis }
Run { docker run --name my-redis -d redis }
Run { docker ps }
Next
Start-Sleep 2
Run { docker exec my-redis redis-cli SET name "Alice" }
Run { docker exec my-redis redis-cli GET name }
Next
Run { docker stop my-redis }
Run { docker start my-redis }
Run { docker ps }
Next
Run { docker stop my-redis }
Run { docker rm my-redis }
Run { docker rmi redis }
Next

# ---- Part B ----
$dir = Join-Path $HOME 'DockerProjects\Redis'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Location $dir
"FROM redis:latest`r`nCMD [`"redis-server`"]" | Set-Content -Encoding ascii Dockerfile
Run { Get-Content Dockerfile }
Run { docker build -t redisnew . }
Run { docker run --name myredisnew -d redisnew }
Run { docker ps }
Next
Run { docker stop myredisnew }

if (-not $HubUser) { Run { docker rm myredisnew }; exit 0 }

Run { docker login }
Run { docker ps -a }
$id = docker ps -aq --filter "name=^myredisnew$"
Run { docker commit $id "$HubUser/redis1" }
Run { docker images }
Run { docker push "$HubUser/redis1" }
Next
Run { docker rm $id }
Run { docker rmi "$HubUser/redis1" }
Run { docker logout }
Run { docker pull "$HubUser/redis1" }
Run { docker run --name myredis -d "$HubUser/redis1" }
Start-Sleep 2
Run { docker exec myredis redis-cli SET name "Abcdef" }
Run { docker exec myredis redis-cli GET name }
Next
Run { docker stop myredis }
Run { docker rm myredis }
Run { docker rmi "$HubUser/redis1" }