---
description: 'Guidelines for generating modern Terraform code for Azure'
applyTo: '**/*.tf'
---

## 1. Use Latest Terraform and Providers
Always target the latest stable Terraform version and Azure providers. In code, specify the required Terraform and provider versions to enforce this. Keep provider versions updated to get new features and fixes.

## 2. Organize Code Cleanly
Structure Terraform configurations with logical file separation:

- Use `main.tf` for all resources, organized with commented headers for logical groupings (e.g., `# Network Resources`, `# Data Resources`, `# AI Resources`)
- Use `variables.tf` for input variables with validation
- Use `outputs.tf` for output values
- Use `providers.tf` for provider configurations and version constraints
- Use `terraform.tfvars.example` for example variable values
- Follow consistent naming conventions and formatting (`terraform fmt`)

This makes the code easy to navigate and maintain while keeping all resources in a single file.

## 3. Encapsulate in Modules

Use Terraform modules to group reusable infrastructure components. For any resource set that will be used in multiple contexts:

- Create a module with its own variables/outputs
- Reference it rather than duplicating code
- This promotes reuse and consistency

## 4. Leverage Variables and Outputs

- **Parameterize** all configurable values using variables with types and descriptions
- **Provide default values** where appropriate for optional variables
- **Use outputs** to expose key resource attributes for other modules or user reference
- **Mark sensitive values** accordingly to protect secrets

## 5. Provider Selection (AzureRM vs AzAPI)

- **Use `azurerm` provider** for most scenarios – it offers high stability and covers the majority of Azure services. Please ensure you are using features that are coming from version 4 or greater of the azurerm provider.
- **Use `azapi` provider** only for cases where you need:
  - The very latest Azure features
  - A resource not yet supported in `azurerm`
- **Document the choice** in code comments
- Both providers can be used together if needed, but prefer `azurerm` when in doubt

## 6. Minimal Dependencies

- **Do not introduce** additional providers or modules beyond the project's scope without confirmation
- If a special provider (e.g., `random`, `tls`) or external module is needed:
  - Add a comment to explain
  - Ensure the user approves it
- Keep the infrastructure stack lean and avoid unnecessary complexity

## 7. Ensure Idempotency

- Write configurations that can be applied repeatedly with the same outcome
- **Avoid non-idempotent actions**:
  - Scripts that run on every apply
  - Resources that might conflict if created twice
- **Test by doing multiple `terraform apply` runs** and ensure the second run results in zero changes
- Use resource lifecycle settings or conditional expressions to handle drift or external changes gracefully

## 8. State Management

- **Use a remote backend** (like Azure Storage with state locking) to store Terraform state securely
- Enable team collaboration
- **Never commit state files** to source control
- This prevents conflicts and keeps the infrastructure state consistent

## 9. Document and Diagram

- **Maintain up-to-date documentation**
- **Update README.md** with any new variables, outputs, or usage instructions whenever the code changes
- Consider using tools like `terraform-docs` for automation
- **Update architecture diagrams** to reflect infrastructure changes after each significant update
- Well-documented code and diagrams ensure the whole team understands the infrastructure

## 10. Validate and Test Changes

- **Run `terraform validate`** and review the `terraform plan` output before applying changes
- Catch errors or unintended modifications early
- **Consider implementing automated checks**:
  - CI pipeline
  - Pre-commit hooks
  - Enforce formatting, linting, and basic validation

## 11. Escape Values Injected into XML/JSON Templates

When using `templatefile()` to inject Terraform values into XML policy files (e.g., Azure APIM policies), JSON config files, or other structured formats:

- **JSON inside XML attributes**: `jsonencode()` produces raw double quotes which break XML `value="..."` attributes. Always escape with `replace(jsonencode(...), "\"", "&quot;")` before injection.
- **General rule**: Any value containing characters meaningful to the target format (`"`, `<`, `>`, `&` for XML; `"`, `\` for JSON) must be escaped for that format. `terraform validate` does NOT catch these — it only validates HCL syntax, not the rendered template content.
- **C# generics in APIM policy attributes**: Expressions like `Body.As<string>()` contain `<` which breaks XML attribute values. Use `As&lt;string&gt;()` in attributes. This is only needed in `value="@(...)"` attributes — element content like `<set-body>@{...}</set-body>` handles `<` correctly.
- **Test rendered output**: When a `templatefile()` call targets a format with strict parsing (XML, JSON, YAML), verify the rendered content is valid in that format, not just valid HCL.