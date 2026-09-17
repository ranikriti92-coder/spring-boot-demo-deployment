# Demo App: Git → PR → CI/CD → OpenShift (local → staging → production)

A tiny Spring Boot app used purely as a teaching example. It has one working
endpoint (`GET /`) and everything needed to deploy it to OpenShift: a
Dockerfile, environment-specific config, and Kubernetes/OpenShift manifests
for staging and production.

Read this top to bottom once — it's written for someone who has never
deployed to OpenShift before.

---

## 0. The big picture, in one paragraph

You write code → commit it to a branch → open a Pull Request (PR) →
a teammate reviews it → it gets merged into `main` → a pipeline (CI/CD)
automatically builds your code into a **container image** → that image
gets pushed to a **registry** → OpenShift pulls that image and runs it as
a **Pod** in the **staging** environment → you test it there → once it's
confirmed good, the *same* image gets promoted (deployed) to
**production**. Nothing is ever rebuilt for production — you deploy the
exact image you already tested in staging.

---

## 1. Project layout

```
demo/
├── pom.xml                          # Maven build file (dependencies, plugins)
├── Dockerfile                       # how to package the app into a container image
├── src/main/java/...                # your actual application code
├── src/main/resources/
│   ├── application.yml              # base config
│   ├── application-staging.yml      # overrides when SPRING_PROFILES_ACTIVE=staging
│   └── application-production.yml   # overrides when SPRING_PROFILES_ACTIVE=production
├── openshift/
│   ├── staging/                     # Deployment + Service + Route for staging
│   └── production/                  # Deployment + Service + Route for production
└── .github/workflows/ci-cd.yml      # example pipeline (build/test/deploy)
```

---

## 2. Run it locally first

You need Java 17+ and Maven installed (or use an IDE like IntelliJ which
bundles both).

```bash
mvn spring-boot:run
```

Visit `http://localhost:8080/` — you should see:

```
Hello! This Spring Boot app is running in the 'local' environment.
```

That confirms the app works *before* you involve Git, Docker, or
OpenShift at all. Always prove it locally first — it's the cheapest place
to catch bugs.

---

## 3. Git workflow: from your local commit to a merged PR

You said you're comfortable up to `git push -u origin main` — here's
what comes *after* that, done properly with a Pull Request instead of
pushing straight to `main`.

1. **Create a feature branch** (never commit straight to `main`):
   ```bash
   git checkout -b feature/add-hello-endpoint
   ```

2. **Make your change, then commit it:**
   ```bash
   git add .
   git commit -m "Add hello endpoint and OpenShift manifests"
   ```

3. **Push the branch (not main) to GitHub/GitLab:**
   ```bash
   git push -u origin feature/add-hello-endpoint
   ```

4. **Open a Pull Request (PR):**
   - Go to your repo in the browser.
   - You'll see a banner "Compare & pull request" for the branch you just
     pushed — click it.
   - Fill in a title and description of *what* changed and *why*.
   - Set the base branch to `main` and the compare branch to your
     feature branch.
   - Click **Create pull request**.

5. **What happens next:**
   - Your CI pipeline usually runs automatically on the PR (build + run
     tests) — you'll see green ✅ or red ❌ checks appear on the PR page.
   - A teammate reviews your code and leaves comments or approves it.
   - Once approved and checks pass, click **Merge pull request** (or your
     teammate/lead does).

6. **After merge:** `main` now contains your change. This merge is
   usually the trigger that kicks off the deployment pipeline (see next
   section).

7. **Clean up:**
   ```bash
   git checkout main
   git pull
   git branch -d feature/add-hello-endpoint
   ```

---

## 4. Containerizing the app (Docker)

OpenShift doesn't run your `.jar` file directly — it runs a **container
image** built from your `Dockerfile`. Think of a container image as a
"frozen box" containing your app + the exact Java runtime it needs, so it
runs identically everywhere.

Build and test the image locally (optional but recommended once, so you
understand what CI is doing for you):

```bash
docker build -t demo-app:local .
docker run -p 8080:8080 demo-app:local
```

Visit `http://localhost:8080/` again — same result, but now it's running
inside a container, exactly like it will on OpenShift.

---

## 5. What is OpenShift, really?

OpenShift is Red Hat's platform built on top of **Kubernetes**. Kubernetes'
job is: "given a container image, keep N copies of it running, restart
them if they crash, and give them a stable network address." OpenShift
adds a web console, easier developer tooling, and its own concept called
a **Route** (its version of a public URL).

Key building blocks used in this project:

| Concept | What it means |
|---|---|
| **Project / Namespace** | A walled-off area in the cluster for your app (e.g. `demo-staging`, `demo-production`). Like a folder that also enforces access control and resource limits. |
| **Pod** | One running instance of your container. |
| **Deployment** | A rule saying "always keep N Pods of this image running." If a Pod dies, the Deployment replaces it automatically. |
| **Service** | A stable internal address that always points at the healthy Pods behind it, even as Pods come and go. |
| **Route** | Exposes a Service to the *outside world* with a real URL, e.g. `https://demo-app-staging.apps.yourcompany.com`. |
| **Image Registry** | Where built container images are stored. OpenShift has a built-in one; many companies also use Quay, Docker Hub, or an internal registry. |

### Where do you actually go to use it?

- **Web Console**: your platform team gives you a URL like
  `https://console-openshift-console.apps.<your-cluster-domain>`. Log in
  with your company SSO/credentials. This is where you can *see* Pods,
  logs, and Routes visually, and click into your project.
- **CLI (`oc`)**: install the `oc` command-line tool
  (Red Hat's docs: search "Download OpenShift CLI"), then:
  ```bash
  oc login --token=<your-token> --server=<your-cluster-api-url>
  ```
  You get the exact token + server URL from the web console: click your
  username (top right) → **Copy login command**.

### Applying the manifests manually (what CI does for you automatically)

Once logged in and you have access to the right project:

```bash
# Switch to the staging project
oc project demo-staging

# Apply everything in the staging folder
oc apply -f openshift/staging/

# Watch it come up
oc rollout status deployment/demo-app -n demo-staging
oc get pods -n demo-staging
oc get route demo-app -n demo-staging   # shows you the public URL
```

Same idea for production, just point at `openshift/production/` and the
`demo-production` project — **but in a healthy setup, production
deploys should never be a manual `oc apply` from your laptop.** They
should go through the same pipeline, usually with a manual
approval/click step, so there's a record of who deployed what and when.

---

## 6. About "Lightspeed"

Since you weren't sure exactly what your team's "Lightspeed" is, here's
the honest situation:

- It is **not** a universally known deployment tool — it's almost
  certainly a name your company gave to its own internal CI/CD or
  GitOps automation (a common pattern: wrap Jenkins, Tekton, GitHub
  Actions, or GitLab CI behind a friendlier internal name).
- Under the hood, it is doing *exactly* the same things described above:
  build → test → build image → push image → `oc apply`/rollout.
- The `.github/workflows/ci-cd.yml` file included here shows that exact
  sequence spelled out, so you can recognize the same steps whatever
  Lightspeed's UI looks like.

**Ask your platform/DevOps team these three questions** — with the
answers, you can map every step above directly onto Lightspeed's UI:

1. "Where do I log in to Lightspeed, and how does it know which GitHub
   repo/PR to watch?" (usually: a web URL + connecting your repo once)
2. "Does merging my PR auto-deploy to staging, or do I have to trigger
   it manually in Lightspeed?"
3. "How do I promote a build from staging to production in Lightspeed —
   is it a button, another approval, or a separate PR?"

---

## 7. Full walkthrough: local → staging → production

1. `mvn spring-boot:run` locally, confirm it works. **(Section 2)**
2. Create a feature branch, commit, push it. **(Section 3, steps 1–3)**
3. Open a PR into `main`. **(Section 3, step 4)**
4. CI/Lightspeed runs build + tests on the PR automatically — fix
   anything red until it's green.
5. Teammate reviews and approves → you (or they) merge the PR.
6. Merge to `main` triggers the pipeline: it builds the Docker image,
   pushes it to the registry, and deploys it to the **staging**
   OpenShift project using `openshift/staging/*.yaml`.
7. Get the staging URL (`oc get route demo-app -n demo-staging`, or find
   it in the OpenShift web console under your staging project → Routes)
   and manually test the app there.
8. If staging looks good, **promote** — either click "Promote to
   production" in Lightspeed, or re-run the production job in your CI
   pipeline. This deploys the *same tested image* using
   `openshift/production/*.yaml`, not a fresh rebuild.
9. Verify production the same way: check the Route URL, check
   `oc get pods -n demo-production`, check logs if anything looks off.

---

## 8. If something goes wrong (rollback)

```bash
oc rollout undo deployment/demo-app -n demo-staging
# or for production:
oc rollout undo deployment/demo-app -n demo-production
```

This instantly reverts to the previous working image/version.

---

## 9. Quick glossary

- **PR (Pull Request)**: a request to merge your branch into `main`, with
  a review step in between.
- **CI (Continuous Integration)**: automatically building/testing every
  change.
- **CD (Continuous Deployment/Delivery)**: automatically deploying a
  build that passed CI.
- **Image**: a packaged, runnable snapshot of your app (built from the
  Dockerfile).
- **Registry**: storage for images.
- **Namespace/Project**: an isolated area in OpenShift for your app.
- **Pod**: one running copy of your container.
- **Rollout**: the process of updating running Pods to a new image
  version.
