# Week 6 - Docker Compose (multi-container)
# Run:  powershell -ExecutionPolicy Bypass -File .\week6-docker-compose.ps1

function Run([scriptblock]$sb) {
    Write-Host ("PS> " + $ExecutionContext.InvokeCommand.ExpandString($sb.ToString().Trim())) -ForegroundColor Cyan
    $global:LASTEXITCODE = 0
    & $sb
    if ($LASTEXITCODE -ne 0) {
        if ((Read-Host "Error above. Continue? (y/n)") -ne 'y') { exit 1 }
    }
}
function Next { Read-Host "`nPress Enter" | Out-Null }
function Wait-Db {
    for ($i = 0; $i -lt 30; $i++) {
        docker compose exec -T db pg_isready -U demo -d demo_db *> $null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep 2
    }
}

# start Docker Desktop if the engine is not running
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    do { Start-Sleep 5; docker info *> $null } until ($LASTEXITCODE -eq 0)
}
# Jenkins also uses port 8080 - stop it during this lab
$jenkins = docker ps -q --filter "name=^jenkins$"
if ($jenkins) { docker stop jenkins | Out-Null }

$dir = Join-Path $HOME 'compose-lab'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Location $dir
docker compose down --remove-orphans *> $null

# ---- Task 1: nginx + postgres ----
@'
version: "3.9"
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: demo
      POSTGRES_PASSWORD: demo
      POSTGRES_DB: demo_db
'@ | Set-Content -Encoding ascii docker-compose.yml
Run { Get-Content docker-compose.yml }
Run { docker compose up -d }
Run { docker compose ps }
Start-Process 'http://localhost:8080'
Next

# ---- Task 2: add redis + depends_on ----
@'
version: "3.9"
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    depends_on:
      - redis
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: demo
      POSTGRES_PASSWORD: demo
      POSTGRES_DB: demo_db
  redis:
    image: redis:alpine
'@ | Set-Content -Encoding ascii docker-compose.yml
Run { Get-Content docker-compose.yml }
Run { docker compose up -d }
Run { docker compose ps }
Next

# ---- Task 3: zip for another machine ----
Run { Compress-Archive -Path "$dir\*" -DestinationPath "$HOME\compose-lab.zip" -Force }
Next

# ---- Task 4: network + volume ----
Run { docker compose down --remove-orphans }
@'
version: "3.9"
networks:
  app-net:
volumes:
  db-data:
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    networks:
      - app-net
    depends_on:
      - db
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: demo
      POSTGRES_PASSWORD: demo
      POSTGRES_DB: demo_db
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-net
'@ | Set-Content -Encoding ascii docker-compose.yml
Run { Get-Content docker-compose.yml }
Run { docker compose up -d }
Wait-Db
Run { docker compose exec -T db psql -U demo -d demo_db -c "CREATE TABLE IF NOT EXISTS t(id int);" }
Run { docker compose exec -T db psql -U demo -d demo_db -c "INSERT INTO t VALUES (1);" }
Run { docker compose exec -T db psql -U demo -d demo_db -c "SELECT * FROM t;" }
Next
Run { docker compose down }
Run { docker compose up -d }
Wait-Db
Run { docker compose exec -T db psql -U demo -d demo_db -c "SELECT * FROM t;" }
Next

# ---- Task 5: Flask app ----
Run { docker compose down --remove-orphans }
@'
from flask import Flask
app = Flask(__name__)

@app.route("/")
def home():
    return "Hello from Flask + Docker!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
'@ | Set-Content -Encoding ascii app.py
@'
FROM python:3.10-slim
WORKDIR /app
COPY app.py /app/
RUN pip install flask
CMD ["python", "app.py"]
'@ | Set-Content -Encoding ascii Dockerfile
@'
version: "3.9"
services:
  web:
    build: .
    ports:
      - "5000:5000"
    depends_on:
      - db
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: demo
      POSTGRES_PASSWORD: demo
      POSTGRES_DB: demo_db
'@ | Set-Content -Encoding ascii docker-compose.yml
Run { Get-Content app.py }
Run { Get-Content Dockerfile }
Run { Get-Content docker-compose.yml }
Run { docker compose up --build -d }
Start-Sleep 5
Start-Process 'http://localhost:5000'
Next
(Get-Content app.py) -replace 'Hello from Flask \+ Docker!', 'Hello Docker Compose!' | Set-Content -Encoding ascii app.py
Run { Get-Content app.py }
Run { docker compose up --build -d }
Start-Sleep 5
Start-Process 'http://localhost:5000'
Next

Run { docker compose down }
if ($jenkins) { docker start jenkins | Out-Null }