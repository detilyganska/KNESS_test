# KNESS Test – Dockerized App Bootstrap

Цей репозиторій запускається на чистому сервері **одним bash-скриптом**, який автоматично:
- встановлює Docker + Docker Compose
- клонить репозиторій
- піднімає docker-compose стек
- налаштовує UFW
- створює Docker secrets для PostgreSQL
- перевіряє health через `curl`

Підтримується **тільки Ubuntu**.

---

## 📦 Що робить скрипт

1. Перевіряє, що ОС — Ubuntu
2. Оновлює `apt` та ставить базові пакети
3. Встановлює Docker Engine та Docker Compose Plugin
4. Запускає та вмикає Docker
5. Створює або перевіряє користувача для роботи з Docker
6. Клонує репозиторій у `/opt/app`
7. Створює secrets для PostgreSQL:
   - `postgres_user.txt`
   - `postgres_password.txt`
8. Запускає:
   ```bash
   docker compose up -d --build
   ```
9. Відкриває порти 80/tcp і 22/tcp, якщо активний UFW.
10. Робить локальний health-check

⚙️ Вимоги
Ubuntu 20.04 / 22.04 / 24.04
Root-доступ (sudo або root)
Інтернет

🚀 Як запустити
1. Скопіюй скрипт на сервер
  ```bash
   nano default.sh
```
Встав скрипт, збережи файл.

2. Зроби його виконуваним
```bash
chmod +x default.sh
```
3. Запусти від root
```bash
sudo ./default.sh
```
⚠️ Обовʼязково запускати від root, інакше:
Docker не встановиться
користувач не додасться до групи docker
UFW не налаштується

👤 Користувач Docker

За замовчуванням використовується користувач:
```bash
syshmaks
```

Якщо потрібно інше імʼя:
```bash
export DOCKER_USER=myuser
sudo ./default.sh
```


```mermaid
%%{init: {
  "theme": "dark",
  "themeVariables": {
    "background": "#0d1117",
    "primaryColor": "#161b22",
    "primaryTextColor": "#e6edf3",
    "primaryBorderColor": "#30363d",
    "lineColor": "#8b949e",
    "secondaryColor": "#21262d",
    "tertiaryColor": "#161b22",
    "fontFamily": "Inter, system-ui, sans-serif"
  }
}}%%

graph TB
    subgraph External["External Network"]
        Client["Client Browser"]
    end

    subgraph Host["Docker Host"]
        subgraph Front["Frontend Network"]
            Nginx["Nginx Container<br/>nginx:1.25-alpine<br/>Port: 80"]
            Web["Web Container<br/>Python Flask + Gunicorn<br/>Port: 8000"]
        end

        subgraph Back["Backend Network"]
            Web
            DB["PostgreSQL 15<br/>Database<br/>Port: 5432"]
        end

        subgraph Vols["Volumes"]
            DBData["db-data volume"]
            Static["static files"]
        end

        subgraph Sec["Secrets"]
            PGUser["postgres_user.txt"]
            PGPass["postgres_password.txt"]
        end
    end

    Client -->|HTTP :80| Nginx
    Nginx -->|proxy_pass :8000| Web
    Web -->|SQL :5432| DB

    DB -.->|persist| DBData
    Nginx -.->|read| Static
    Web -.->|read| PGUser
    Web -.->|read| PGPass
    DB -.->|read| PGUser
    DB -.->|read| PGPass

    %% Node styling (dark-theme friendly)
    style Client fill:#21262d,stroke:#30363d,color:#e6edf3
    style Nginx fill:#1f6feb,stroke:#388bfd,color:#ffffff
    style Web fill:#238636,stroke:#2ea043,color:#ffffff
    style DB fill:#8957e5,stroke:#a371f7,color:#ffffff
    style DBData fill:#9e6a03,stroke:#d29922,color:#ffffff
    style Static fill:#30363d,stroke:#484f58,color:#e6edf3
    style PGUser fill:#30363d,stroke:#484f58,color:#e6edf3
    style PGPass fill:#30363d,stroke:#484f58,color:#e6edf3
```
