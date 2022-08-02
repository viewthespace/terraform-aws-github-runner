# Action runners deployment with ARM64 architecture

This module shows how to create GitHub action runners using AWS Graviton instances which have ARM64 architecture. Lambda release will be downloaded from GitHub.

## Usages

Steps for the full setup, such as creating a GitHub app can be found in the root module's [README](https://github.com/philips-labs/terraform-aws-github-runner). First download the Lambda releases from GitHub. Alternatively you can build the lambdas locally with Node or Docker, there is a simple build script in `<root>/.ci/build.sh`. In the `main.tf` you can simply remove the location of the lambda zip files, the default location will work in this case.

> Ensure you have set the version in `lambdas-download/main.tf` for running the example. The version needs to be set to a GitHub release version, see https://github.com/philips-labs/terraform-aws-github-runner/releases

```bash
cd lambdas-download
terraform init
terraform apply
cd ..
```

Before running Terraform, ensure the GitHub app is configured. See the [configuration details](https://github.com/philips-labs/terraform-aws-github-runner#usages) for more details.

```bash
terraform init
terraform apply
```

You can receive the webhook details by running:

```bash
terraform output -raw webhook_secret
```

Be-aware some shells will print some end of line character `%`. 
