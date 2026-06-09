# TODO — Vincent Team

## Next Steps for Production Readiness

- [ ] **Restrict OIDC trust policy** — Replace `sub: "*"` with the exact kikoai-app repo UUID in `infra/oidc.tf` for tighter security

- [ ] **Adapt buildspec for real build** — Replace the demo buildspec with one that builds the actual kikoai Dockerfile (`apps/chatbot-api/Dockerfile`) and pushes to the project's Docker registry

- [ ] **Add `AWS_ARM64_ROLE_ARN` variable in Bitbucket** — Repository Settings → Pipelines → Repository variables → value: `arn:aws:iam::<ACCOUNT_ID>:role/bitbucket-arm64-codebuild-role` (requires admin access)

- [ ] **Terraform state backend** — Migrate from local state to S3 + DynamoDB lock for team collaboration
