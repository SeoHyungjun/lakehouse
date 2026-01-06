# ArgoCD SealedSecrets

The `argocd-secret` sealed secret is created in this directory.

## Usage

The secret will be automatically applied by ArgoCD when the argocd-secrets application is synced.

## Note

ArgoCD admin password is set via sealed secret. To change the admin password after deployment:

```bash
argocd account update-password --account admin --new-password <new-password>
```
