# 🛠️ Fork Maintenance Guide

This file documents how this fork (`my-master`) of the upstream repository is managed, including workflow, branch strategy, and important considerations.

---

## 📦 Branch Structure

| Branch             | Purpose                                                 |
| ------------------ | ------------------------------------------------------- |
| `master`           | Clean mirror of `upstream/master` (no personal changes) |
| `my-master`        | Production-ready fork with custom features              |
| `integration-test` | Sandbox to test upstream updates before applying them   |
| `feature/*`        | Feature branches for modular development and PRs        |
| `contrib/*`        | Feature branches for contributions to upstream          |

```
 upstream/master
       │
       ▼
     origin/master (clean mirror of upstream)
       │
       └───▶ my-master (our custom build)
                   ├──▶ feature/x
                   ├──▶ feature/y
     contrib/z ───▶ (from master, for upstream PR)
```

---

## 🔁 Update from upstream Workflow Summary

1. **Sync with upstream:**

```bash
git checkout master
git fetch upstream
git reset --hard upstream/master
```

2. **Test updates safely**

```
git checkout -B integration-test my-master
git merge master
# OR: git rebase master
```

3. **Remove unwanted upstream files (CI/CD, etc)**

```
rm -rf .github/
git add -u
git commit -m "chore: remove upstream CI/CD files"
```

4. **Test everything (locally of via CI)**

```
bundle exec rake
```

5. **If tests pass, update our production branch**

```
git checkout my-master
git merge integration-test
git push origin my-master
```

## 📌 Tips

- Do not commit any local changes to `master`.
- Always test upstream updates in `integration-test` before merging to `my-master`.
- Use `feature/` branches for anything we may want to PR back to upstream.

## Development

### Features

Create `feature/` branches from `my-master`.

### Execute

```
docker-compose -f docker-compose-dev-postgres-my.yml up --build
```

Open `localhost:9292`

`docker-compose-dev-postgres-my.yml` is a copy of `docker-compose-dev-postgres.yml` mounting extra `public` and `vendor/hal-browser`

## 🎁 Contributing Features Back to Upstream

🔨 1. **Create a Contribution Branch from master**

```
git checkout master
git pull upstream master
git checkout -b contrib/our-feature-name
```

🧑‍💻 2. **Develop the Feature**

Make changes as needed. Ensure they align with the upstream project's standards (coding style, testing, etc.).

Optionally cherry-pick commits from our features.

✅ 3. **Test and Clean Up**

Before pushing:

- Ensure the feature works with upstream, not just our fork.
- Remove any fork-specific logic or dependencies, if applicable.
- Run tests

⬆️ 4. **Push to Our Fork and Open a PR**

```
git push origin contrib/our-feature-name
```

Then go to the upstream repo on GitHub and click "Compare & pull request".
