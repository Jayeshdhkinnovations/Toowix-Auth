# Toowix Keycloak UI

This project adds a separate `toowix` login theme and the Toowix Email OTP
authenticator provider to the official Keycloak **26.7.4** image. It does not
compile, modify, or replace Keycloak source, services, database logic, users,
clients, roles, or realm configuration.

The reference checkout lives at `../vendor/keycloak`; use it only to inspect
official theme templates. Do not make changes in that directory.

## Theme layout

```text
toowix-keycloak-ui/
├── themes/toowix/login/
│   ├── resources/css/toowix.css
│   ├── messages/messages_en.properties
│   └── theme.properties
├── Dockerfile
└── README.md
```

The theme inherits `keycloak.v2`, so the stock Keycloak 26.7.4 templates and
all authentication flows remain in use. The custom CSS and messages add only
the Toowix presentation layer.

## Clone the Keycloak reference repository

From the workspace root:

```powershell
git clone --branch 26.7.4 --depth 1 https://github.com/keycloak/keycloak.git vendor/keycloak
```

## Build the image

```powershell
Set-Location .\toowix-keycloak-ui
docker build -t toowix-keycloak:dev .
docker images
```

The Dockerfile copies the theme to `/opt/keycloak/themes/toowix` in the
official `quay.io/keycloak/keycloak:26.7.4` image.

## Configure the optional two-factor step

The image also installs the `Toowix Email OTP` authenticator. It provides one
post-password choice screen with **Authenticator app** and **Email verification
code** options. Keycloak still owns the TOTP secret, QR code, and TOTP
verification; the provider creates and verifies the six-digit email code.

After starting an image built from this project, configure it in the Keycloak
Admin Console for the `toowix-dev` realm:

1. Go to **Authentication → Flows → browser**, add an execution after the
   password/forms step, choose **Toowix Email OTP**, and set it to **Required**.
2. To enable MFA for a user, open **Users → user → Attributes**, add
   `toowix_2fa_enabled` with value `true`, and save. A user who has already
   enrolled a Keycloak authenticator app is also treated as enabled.
3. Configure realm SMTP under **Realm settings → Email** before testing the
   email-code method. The code expires after five minutes; the provider stores
   only a salted hash in the authentication session.

With this arrangement the execution is present for every browser login but
silently succeeds for users who have not enabled MFA. Enabled users see the
method chooser after a successful password login. If an enabled user selects
the authenticator app before enrollment, Keycloak opens the Toowix-branded QR
setup page and then verifies the six-digit app code.

## Safely stop the old container and start Toowix

First check port 8080 and existing containers:

```powershell
docker ps
```

If the container named `keycloak` is running, stop it safely (this does **not**
delete the container, its volumes, or its realm data):

```powershell
docker stop keycloak
```

If another container uses `127.0.0.1:8080`, do not change the port silently.
Stop/reconfigure that container only after confirming it is safe to do so.

If a container named `keycloak-toowix` already exists, do **not** delete it.
Inspect it and either stop it before a new run, or reuse it as appropriate:

```powershell
docker inspect keycloak-toowix
docker stop keycloak-toowix
```

Start a new container only when the name and port are available:

```powershell
docker run --name keycloak-toowix `
  -p 127.0.0.1:8080:8080 `
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin `
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin `
  toowix-keycloak:dev `
  start-dev
```

Keycloak is then available at http://localhost:8080 and the Admin Console at
http://localhost:8080/admin.

## Preserve and import the realm

Do not remove the old `keycloak` container or its volumes. If its realm data is
stored in its database volume, a separate fresh `start-dev` container will not
automatically contain it. Preserve the existing storage and export the realm
before migration. An example export from a running old container is:

```powershell
docker exec keycloak /opt/keycloak/bin/kc.sh export --realm toowix-dev --file /tmp/toowix-dev-realm.json
docker cp keycloak:/tmp/toowix-dev-realm.json .\toowix-dev-realm.json
```

To import an available export, mount its containing directory and add the
import flag when starting the new container:

```powershell
docker run --name keycloak-toowix `
  -p 127.0.0.1:8080:8080 `
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin `
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin `
  -v "${PWD}\realm-import:/opt/keycloak/data/import:ro" `
  toowix-keycloak:dev `
  start-dev --import-realm
```

Place the export in `realm-import` first. Confirm the imported realm is
`toowix-dev` and preserves clients `toowix-sign`, `toowix-meet`, and roles
`sign_access`, `meet_access` before retiring any old runtime.

## Select and verify the theme

1. Open http://localhost:8080/admin and sign in as the bootstrap admin.
2. Select realm **toowix-dev**.
3. Open **Realm settings → Themes**.
4. Set **Login theme** to **toowix**, then save.
5. Start a login flow from OpenSign or Meet. Its Keycloak authentication URL
   should render the Toowix-styled sign-in page.

Use these checks:

```powershell
docker ps
docker logs keycloak-toowix
docker images
docker inspect keycloak-toowix
```

In the Admin Console, `toowix` appearing in the Login theme selector confirms
the image has discovered `/opt/keycloak/themes/toowix`. A successful browser
login redirect from OpenSign or Meet confirms the theme is used for the
application authentication flow.

## Logs, stop, and restart

```powershell
docker logs -f keycloak-toowix
docker stop keycloak-toowix
docker start keycloak-toowix
docker logs keycloak-toowix
```

`docker stop` is safe: it stops the container without deleting it. Do not run
`docker rm` or remove volumes unless you have separately confirmed that realm
data has been exported or is otherwise preserved.

### Mountless `start-dev` migration

The default `start-dev` container in this environment has no database mount;
its complete H2 database lives at `/opt/keycloak/data/h2` in the container's
writable layer. A partial realm export may not include every user/session
record. When preserving the complete existing development state is required,
use this same-Keycloak-version migration after stopping both containers. It
does not delete either container:

```powershell
# Stop the new container and the old source container before copying H2 files.
docker stop keycloak-toowix
docker stop keycloak

# Copy a recoverable workspace backup from the old container.
New-Item -ItemType Directory -Path .\legacy-keycloak-h2 -Force
docker cp keycloak:/opt/keycloak/data/h2/keycloakdb.mv.db .\legacy-keycloak-h2\keycloakdb.mv.db
docker cp keycloak:/opt/keycloak/data/h2/keycloakdb.trace.db .\legacy-keycloak-h2\keycloakdb.trace.db

# Copy the original database into the already-created theme container.
docker cp .\legacy-keycloak-h2\keycloakdb.mv.db keycloak-toowix:/opt/keycloak/data/h2/keycloakdb.mv.db
docker cp .\legacy-keycloak-h2\keycloakdb.trace.db keycloak-toowix:/opt/keycloak/data/h2/keycloakdb.trace.db

# docker cp makes these files root-owned; correct them before the restart.
docker start keycloak-toowix
docker exec --user root keycloak-toowix sh -c "chown keycloak:root /opt/keycloak/data/h2/keycloakdb.* && chmod 644 /opt/keycloak/data/h2/keycloakdb.*"
docker restart keycloak-toowix
```

Use this only between identical Keycloak versions (this project uses 26.7.4
for both). Keep the stopped `keycloak` container and the workspace backup until
the new runtime has been fully verified.
