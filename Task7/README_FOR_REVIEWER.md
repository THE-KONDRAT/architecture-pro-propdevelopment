# Task 7 — Аудит и соответствие политике безопасности контейнеров

## Порядок воспроизведения

1. Поднять кластер
   ```bash
   minikube start
   ```

2. Создать namespace с PodSecurity restricted:
   ```bash
   kubectl apply -f 01-create-namespace.yaml
   ```

3. Проверить, что небезопасные манифесты отклоняются:
   Для каждой команды ожидается ошибка Forbidden
   ```bash
   kubectl apply -f insecure-manifests/01-privileged-pod.yaml
   ```
   Ожидание: `Error from server (Forbidden): pods "pod-privileged" is forbidden: violates PodSecurity "restricted:latest": ... privileged (container "nginx" must not set securityContext.privileged=true) ...`

   ```bash
   kubectl apply -f insecure-manifests/02-hostpath-pod.yaml
   ```
   Ожидание: `Error from server (Forbidden): pods "pod-hostpath" is forbidden: violates PodSecurity "restricted:latest": ... restricted volume types (volume "host-vol" uses restricted volume type "hostPath") ...`
   ```bash
   kubectl apply -f insecure-manifests/03-root-user-pod.yaml
   ```
   Ожидание: `Error from server (Forbidden): pods "pod-root-user" is forbidden: violates PodSecurity "restricted:latest": ... runAsUser=0 (container "nginx" must not set runAsUser=0) ...`

4. Установить OPA Gatekeeper:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
   ```
   ```bash
   kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=120s
   ```

5. Применить шаблоны и ограничения:
   ```bash
   kubectl apply -f gatekeeper/constraint-templates/
   ```
   Выполнить `sleep 15` или подождать

6. ```bash
   kubectl apply -f gatekeeper/constraints/
   ```

6. Применить безопасные манифесты:
   ```bash
   kubectl apply -f secure-manifests/
   ```
   ```bash
   kubectl get pods -n audit-zone
   ```
   Ожидание: поды создались
   ```bash
   NAME                    READY   STATUS    RESTARTS   AGE
   pod-hostpath-secure     1/1     Running   0          13s
   pod-privileged-secure   1/1     Running   0          13s
   pod-root-user-secure    1/1     Running   0          13s
   ```

7. Запустить скрипты проверки:
   ```bash
   ./verify/verify-admission.sh
   ```
   ```bash
   ./verify/validate-security.sh
   ```
   Ожидание: Оба скрипта завершаются с сообщением `••• All checks passed •••`


## Ожидаемый результат

1. Три небезопасных пода отклоняются.
   ```bash
   OK (rejected): insecure-manifests/01-privileged-pod.yaml
       Error from server (Forbidden): error when creating "insecure-manifests/01-privileged-pod.yaml": pods "pod-privileged" is forbidden: violates PodSecurity "restricted:latest": privileged (container "nginx" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
   OK (rejected): insecure-manifests/02-hostpath-pod.yaml
       Error from server (Forbidden): error when creating "insecure-manifests/02-hostpath-pod.yaml": pods "pod-hostpath" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]), restricted volume types (volume "host-vol" uses restricted volume type "hostPath"), runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
   OK (rejected): insecure-manifests/03-root-user-pod.yaml
       Error from server (Forbidden): error when creating "insecure-manifests/03-root-user-pod.yaml": pods "pod-root-user" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (container "nginx" must not set securityContext.runAsNonRoot=false), runAsUser=0 (container "nginx" must not set runAsUser=0), seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
   ```
2. Три безопасных пода переходят в Running.
   ```bash
   pod/pod-privileged-secure configured
   OK (accepted): secure-manifests/01-secure.yaml
   pod/pod-hostpath-secure configured
   OK (accepted): secure-manifests/02-secure.yaml
   pod/pod-root-user-secure configured
   OK (accepted): secure-manifests/03-secure.yaml
   ```
3. `kubectl get constraints` показывает четыре ограничения, а повторная попытка создать привилегированный под отклоняется с violation message из Rego.
   ```bash
   k8spsphostfilesystem.constraints.gatekeeper.sh/no-hostpath-volumes   deny                 0
   k8spspprivilegedcontainer.constraints.gatekeeper.sh/no-privileged-containers   deny                 0
   k8spspreadonlyrootfilesystem.constraints.gatekeeper.sh/require-readonly-rootfs   deny                 0
   k8spsprunasnonroot.constraints.gatekeeper.sh/require-runasnonroot   deny                 0
   ```
   ```bash
   OK: Gatekeeper rejected the privileged pod
   ```