#!/usr/bin/env python3
"""Idempotently create roles, clients, users and role mappings in a Keycloak realm.

Usage:  python provision.py environments/dev.json [--dry-run]
Re-running is safe: existing items are updated/skipped, never duplicated.
Secrets come from environment variables named in the config (never stored in git).
"""
import json, os, sys, urllib.request, urllib.parse, urllib.error

def http(method, url, token=None, body=None, form=None):
    data, headers = None, {}
    if form is not None:
        data = urllib.parse.urlencode(form).encode()
    elif body is not None:
        data = json.dumps(body).encode(); headers["Content-Type"] = "application/json"
    if token: headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else None), r.headers
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace"), e.headers

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    if not args: sys.exit(__doc__)
    cfg = json.load(open(args[0], encoding="utf8"))
    base, realm = cfg["keycloak_url"].rstrip("/"), cfg["realm"]

    admin_user = os.environ.get(cfg["admin_user_env"], cfg.get("admin_user_default"))
    admin_pass = os.environ.get(cfg["admin_password_env"], cfg.get("admin_password_default"))
    if not admin_user or not admin_pass:
        sys.exit("Set %s and %s" % (cfg["admin_user_env"], cfg["admin_password_env"]))
    def login():
        st, tok, _ = http("POST", f"{base}/realms/master/protocol/openid-connect/token",
                          form={"client_id": "admin-cli", "grant_type": "password",
                                "username": admin_user, "password": admin_pass})
        if st != 200: sys.exit(f"Admin login failed ({st}): {tok}")
        return tok["access_token"]
    T = login()
    A = f"{base}/admin/realms/{realm}"

    def call(method, path, body=None):
        if dry and method != "GET":
            print(f"   [dry-run] {method} {path}"); return 204, None, {}
        nonlocal T
        st, res, h = http(method, A + path, T, body)
        if st == 401:  # admin token lifespan is short; refresh and retry once
            T = login(); st, res, h = http(method, A + path, T, body)
        if st >= 400: sys.exit(f"{method} {path} -> {st}: {res}")
        return st, res, h

    # roles
    print("Roles")
    existing = {r["name"] for r in call("GET", "/roles?max=500")[1]}
    for r in cfg["roles"]:
        if r in existing: print("  =", r)
        else: call("POST", "/roles", {"name": r}); print("  +", r)

    # clients
    print("Clients")
    for c in cfg["clients"]:
        rep = {
            "clientId": c["clientId"], "name": c.get("name", c["clientId"]), "protocol": "openid-connect",
            "enabled": True, "publicClient": c.get("public", True),
            "standardFlowEnabled": True, "directAccessGrantsEnabled": False,
            "implicitFlowEnabled": False, "serviceAccountsEnabled": False,
            "redirectUris": c["redirectUris"], "webOrigins": c["webOrigins"],
            "attributes": {"pkce.code.challenge.method": "S256",
                           "post.logout.redirect.uris": c.get("postLogoutRedirectUris", "+")},
        }
        found = call("GET", "/clients?clientId=" + urllib.parse.quote(c["clientId"]))[1]
        if found:
            call("PUT", "/clients/" + found[0]["id"], {**found[0], **rep,
                 "attributes": {**found[0].get("attributes", {}), **rep["attributes"]}})
            print("  ~", c["clientId"], "(updated)")
        else:
            call("POST", "/clients", rep); print("  +", c["clientId"])

    # users
    print("Users")
    for u in cfg["users"]:
        pw = os.environ.get(u["password_env"], u.get("password_default"))
        if not pw: sys.exit(f"Set {u['password_env']} for user {u['username']}")
        found = call("GET", "/users?exact=true&username=" + urllib.parse.quote(u["username"]))[1]
        attrs = {k: [v] for k, v in u.get("attributes", {}).items()}
        rep = {"username": u["username"], "email": u["email"], "firstName": u.get("firstName", ""),
               "lastName": u.get("lastName", ""), "enabled": True, "emailVerified": True, "attributes": attrs}
        if found:
            uid = found[0]["id"]; call("PUT", f"/users/{uid}", {**found[0], **rep}); print("  ~", u["username"])
        else:
            _, _, h = call("POST", "/users", rep)
            uid = (h.get("Location") or "").rsplit("/", 1)[-1] if not dry else "dry"
            call("PUT", f"/users/{uid}/reset-password",
                 {"type": "password", "value": pw, "temporary": False}); print("  +", u["username"])
        # role mappings (add missing only)
        if dry: continue
        have = {r["name"] for r in call("GET", f"/users/{uid}/role-mappings/realm")[1]}
        want = [r for r in u["roles"] if r not in have]
        if want:
            reps = [call("GET", "/roles/" + urllib.parse.quote(r))[1] for r in want]
            call("POST", f"/users/{uid}/role-mappings/realm", reps)
        print("     roles:", ", ".join(u["roles"]))
    print("Done.")

if __name__ == "__main__":
    main()
