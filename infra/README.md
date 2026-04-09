# infra

Infrastructure provisioning for data_lab is TBD pending guidance from the EDF team.

**Questions to resolve:**
- For a sandbox Lambda + S3 bucket in a dev account, should we use CDK directly
  or go through the EDF deployment pipeline?
- Does the EDF team have a standard CDK construct library or template to start from?

## In the meantime

For local sandbox setup, use the `aws cli` recipes in the root `justfile`:

```bash
just aws-bucket-create   # create the S3 bucket
just aws-lambda-deploy   # package and deploy the example Lambda
just aws-lambda-invoke   # invoke it manually to test
```

These require `AWS_PROFILE` and `DATA_LAB_S3_BUCKET` to be set in your `.env`.
