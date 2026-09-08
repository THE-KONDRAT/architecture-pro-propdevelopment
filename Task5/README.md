# Задание 5. Управление трафиком внутри кластера Kubernetes

## Создать сервисы
```bash
kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80 -n dev
```
```bash
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80 -n dev
```
```bash
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80 -n dev
```
```bash
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80 -n dev
```
Проверка:
```bash
kubectl get pods,svc -n dev -L role
```

## Применить сетевые политики
Файл содержит 4 сетевые политики в namespace `dev`.
Политики перекрывают друг друга, так, например, `front-end-policy` разрешает доступ к `back-end-api`, а `back-end-api-policy` - обратно к `front-end`.

```bash
kubectl apply -f non-admin-api-allow.yaml
```

## Проверка
Запустить эти команды:
```bash
kubectl run test-f1 --rm --attach --image=alpine -n dev --labels role=front-end -- sh -c 'wget -qO- --timeout=2 http://back-end-api-app >/dev/null 2>&1 && echo "front-end -> back-end-api: PASS (OK)" || echo "front-end -> back-end-api: UNEXPECTED"' 2>/dev/null | grep -E "PASS|UNEXPECTED" | head -n 1
```
```bash
kubectl run test-f2 --rm --attach --image=alpine -n dev --labels role=front-end -- sh -c 'wget -qO- --timeout=2 http://admin-back-end-api-app >/dev/null 2>&1 && echo "front-end -> admin-back-end: UNEXPECTED" || echo "front-end -> admin-back-end: PASS (FAIL)"' 2>/dev/null | grep -E "PASS|UNEXPECTED" | head -n 1
```
```bash
kubectl run test-f3 --rm --attach --image=alpine -n dev --labels role=front-end -- sh -c 'wget -qO- --timeout=2 http://admin-front-end-app >/dev/null 2>&1 && echo "front-end -> admin-front-end: UNEXPECTED" || echo "front-end -> admin-front-end: PASS (FAIL)"' 2>/dev/null | grep -E "PASS|UNEXPECTED" | head -n 1
```

```bash
kubectl run test-a1 --rm --attach --image=alpine -n dev --labels role=admin-front-end -- sh -c 'wget -qO- --timeout=2 http://admin-back-end-api-app >/dev/null 2>&1 && echo "admin-front-end -> admin-back-end-api: PASS (OK)" || echo "admin-front-end -> admin-back-end-api: UNEXPECTED"' 2>/dev/null | grep -E "PASS|UNEXPECTED" | head -n 1
```
```bash
kubectl run test-a2 --rm --attach --image=alpine -n dev --labels role=admin-front-end -- sh -c 'wget -qO- --timeout=2 http://back-end-api-app >/dev/null 2>&1 && echo "admin-front-end -> back-end-api: UNEXPECTED" || echo "admin-front-end -> back-end-api: PASS (FAIL)"' 2>/dev/null | grep -E "PASS|UNEXPECTED" | head -n 1
```
```bash
kubectl run test-a3 --rm --attach --image=alpine -n dev --labels role=admin-front-end -- sh -c 'wget -qO- --timeout=2 http://front-end-app >/dev/null 2>&1 && echo "admin-front-end -> front-end: UNEXPECTED" || echo "admin-front-end -> front-end: PASS (FAIL)"' 2>/dev/null | grep -E "PASS|UNEXPECTED" | head -n 1
```

### Ожидаемый результат

| Источник          | Назначение           | Ожидание      | Команда                  |
|-------------------|----------------------|---------------|--------------------------|
| `front-end`       | `back-end-api`       | `PASS (OK)`   | `kubectl run test-f1...` |
| `front-end`       | `admin-back-end-api` | `PASS (FAIL)` | `kubectl run test-f2...` |
| `front-end`       | `admin-front-end`    | `PASS (FAIL)` | `kubectl run test-f3...` |
| `admin-front-end` | `admin-back-end-api` | `PASS (OK)`   | `kubectl run test-a1...` |
| `admin-front-end` | `back-end-api`       | `PASS (FAIL)` | `kubectl run test-a2...` |
| `admin-front-end` | `front-end`          | `PASS (FAIL)` | `kubectl run test-a3...` |