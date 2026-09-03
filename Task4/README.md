# Задание 4. Защита доступа к кластеру Kubernetes

Таблица ролей и разрешений находится в соответствующем файле.

Всего в директории задания есть 4 файла кроме этого, интересующих для запуска Minikube – 3:
`users.sh`      – Генерация X.509 сертификатов и kubeconfig'ей для пользователей.
`roles.yaml`    – Конфигурация ролей.
`bindings.yaml` – Конфигурация связей пользователей и ролей.

## Запуск Minikube


1. Убедиться, что Minikube запущен
```bash
minikube status
```

2. Создать неймспейсы
```bash
kubectl create namespace dev
```
```bash
kubectl create namespace staging
```
```bash
kubectl create namespace prod
```

3. Создать пользователей
```bash
chmod +x create_users.sh
```
```bash
./create_users.sh
```

4. Создать роли
```bash
kubectl apply -f roles.yaml
```

5. Связать пользователей с ролями
```bash
kubectl apply -f rolebinding.yaml
```

6. Проверки доступа
```bash
kubectl auth can-i create secrets --as=ivan
```
Ожидается: `yes`

```bash
kubectl auth can-i delete secrets --as=mike
```
Ожидается: `no`

```bash
kubectl auth can-i create namespaces --as=mike --all-namespaces
```
Ожидается: `yes`

```bash
kubectl auth can-i list secrets --as=phillip
```
Ожидается: `no`

```bash
kubectl auth can-i create deployments --as=david -n dev
```
Ожидается: `yes`

```bash
kubectl auth can-i create deployments --as=david -n prod
```
Ожидается: `no`

```bash
kubectl auth can-i create pods/exec --as=olga -n prod
```
Ожидается: `yes`

```bash
kubectl auth can-i delete deployments --as=olga -n prod
```
Ожидается: `no`