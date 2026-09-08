#!/usr/bin/env python3
"""
Usage:

python audit-filter.py audit.log > audit-extract.json
"""

import json
import sys


def get(obj, *keys, default=None):
    cur = obj
    for k in keys:
        if not isinstance(cur, dict):
            return default
        cur = cur.get(k)
    return cur if cur is not None else default


def has_privileged_container(e):
    req = e.get("requestObject")
    if not isinstance(req, dict):
        return False
    containers = req.get("spec", {}).get("containers", [])
    init_conts = req.get("spec", {}).get("initContainers", [])
    for c in list(containers) + list(init_conts):
        if get(c, "securityContext", "privileged") is True:
            return True
    return False


def is_cluster_admin_binding(e):
    if e.get("verb") not in ("create", "update", "patch"):
        return False
    kind = get(e, "objectRef", "resource")
    if kind not in ("rolebindings", "clusterrolebindings"):
        return False
    req = e.get("requestObject") or {}
    role_ref = req.get("roleRef", {})
    return role_ref.get("name") == "cluster-admin"


def classify(e):
    """Возвращает список категорий, к которым относится событие."""
    tags = []
    verb = e.get("verb", "")
    res = get(e, "objectRef", "resource", default="")
    sub = get(e, "objectRef", "subresource", default="")

    if res == "secrets" and verb in ("get", "list", "watch"):
        tags.append("secrets-access")
    if sub in ("exec", "attach") and verb in ("create", "get"):
            tags.append("pod-exec")
    if res == "pods" and verb == "create" and has_privileged_container(e):
        tags.append("privileged-pod")
    if "audit-policy" in json.dumps(e, ensure_ascii=False):
        tags.append("audit-policy-tampering")
    if is_cluster_admin_binding(e):
        tags.append("cluster-admin-binding")
    if res in ("selfsubjectaccessreviews", "selfsubjectrulesreviews"):
        tags.append("rbac-recon")
    if res in ("rolebindings", "clusterrolebindings") and verb == "create" \
            and "cluster-admin-binding" not in tags:
        tags.append("rbac-change")
    return tags


def compact(e, tags):
    return {
        "timestamp": e.get("stageTimestamp") or e.get("requestReceivedTimestamp"),
        "categories": tags,
        "level": e.get("level"),
        "verb": e.get("verb"),
        "resource": get(e, "objectRef", "resource"),
        "subresource": get(e, "objectRef", "subresource"),
        "namespace": get(e, "objectRef", "namespace"),
        "name": get(e, "objectRef", "name"),
        "user": {
            "username": get(e, "user", "username"),
            "groups": get(e, "user", "groups", default=[]),
        },
        "impersonatedUser": get(e, "impersonatedUser", "username"),
        "sourceIPs": e.get("sourceIPs"),
        "userAgent": e.get("userAgent"),
        "requestURI": e.get("requestURI"),
        "responseStatus": get(e, "responseStatus", "code"),
        "annotations": e.get("annotations"),
    }


def main():
    if len(sys.argv) > 1:
        fh = open(sys.argv[1], encoding="utf-8")
    else:
        fh = sys.stdin

    found = []
    total = 0
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue  # пропускаем не-JSON строки (заголовки лога)
        total += 1
        tags = classify(e)
        if tags:
            found.append(compact(e, tags))

    fh.close()
    json.dump(found, sys.stdout, ensure_ascii=False, indent=2)
    sys.stderr.write(f"Всего событий: {total}; подозрительных: {len(found)}\n")


if __name__ == "__main__":
    main()
