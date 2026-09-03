# Задание 4. Защита доступа к кластеру Kubernetes

Таблица ролей и разрешений находится в [соответствующем файле](https://github.com/THE-KONDRAT/architecture-pro-propdevelopment/blob/Exercises/Task4/%D0%9E%D0%BF%D0%B8%D1%81%D0%B0%D0%BD%D0%B8%D0%B5%20%D1%80%D0%BE%D0%BB%D0%B5%D0%B9%20Kubernetes.md).

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