# Copilot Instructions for tjs-scripts Repository

## Repository Overview
This repository contains a collection of scripts, Infrastructure as Code (IaC) templates, and solution examples primarily focused on Azure cloud development. It serves as a centralized location for reusable code patterns, automation scripts, and reference implementations.

## General Guidelines

### 1. Repository Philosophy
- **Practical Examples**: All code should be production-ready or serve as high-quality reference implementations
- **Reusability**: Write code that can be easily adapted and reused across different scenarios
- **Documentation**: Every script, template, or solution should be well-documented
- **Best Practices**: Follow industry standards and cloud provider recommendations

### 2. Code Organization
- Keep related files together in logical directories
- Use clear, descriptive naming conventions
- Include README.md files for complex solutions
- Maintain consistent file structure across similar projects

### 3. Technology Stack Focus
This repository primarily works with:
- **Azure Cloud Services** (API Management, App Service, AKS, etc.)
- **Infrastructure as Code**: Terraform, Bicep, ARM templates
- **Scripting**: PowerShell, Bash, Python
- **Containerization**: Docker, Kubernetes
- **CI/CD**: GitHub Actions, Azure DevOps

## File-Specific Instructions

### Infrastructure as Code
- **Terraform** (`**/*.tf`): Follow the detailed guidelines in `.github/instructions/terraform.instructions.md`
- **Bicep** (`**/*.bicep`): Use latest Bicep syntax, parameterize values, include comprehensive outputs
- **ARM Templates** (`**/*.json`): Prefer Bicep over ARM templates for new development

### Scripts
- **PowerShell** (`**/*.ps1`): 
  - Use approved verbs and proper error handling
  - Include comment-based help
  - Support parameter validation
  - Follow PowerShell best practices
- **Bash** (`**/*.sh`):
  - Include proper error handling (`set -e`)
  - Use clear variable names
  - Add usage documentation
- **Python** (`**/*.py`):
  - Follow PEP 8 style guidelines
  - Include type hints where appropriate
  - Use virtual environments for dependencies
  - Add docstrings for functions and classes

### Docker
- **Dockerfiles**: Use multi-stage builds, minimize layers, use specific base image tags
- Include .dockerignore files
- Document exposed ports and environment variables

## Solution Development Guidelines

### 1. Solution Structure
Each solution in the `/solutions` directory should include:
```
solution-name/
├── README.md                 # Clear documentation
├── main.tf|.bicep           # Primary infrastructure
├── variables.tf|.parameters.json  # Input parameters
├── outputs.tf               # Key outputs
├── providers.tf             # Provider configurations
└── examples/                # Usage examples (if applicable)
```

### 2. Documentation Requirements
Every solution must include:
- **Purpose**: What problem does this solve?
- **Prerequisites**: Required permissions, tools, or setup
- **Usage**: Step-by-step deployment instructions
- **Architecture**: High-level component overview
- **Cleanup**: How to remove deployed resources
- **Cost Considerations**: Estimate of Azure costs

### 3. Security Considerations
- Never commit secrets, keys, or sensitive data
- Use Azure Key Vault for secret management
- Follow principle of least privilege
- Include security best practices in documentation
- Use managed identities where possible

### 4. Testing and Validation
- Include validation steps in documentation
- Test deployments in multiple environments when possible
- Provide troubleshooting guidance
- Include rollback procedures

## Azure-Specific Guidelines

### 1. Resource Naming
- Use consistent naming conventions across resources
- Include environment indicators (dev, test, prod)
- Consider Azure naming conventions and limitations
- Use descriptive names that indicate purpose

### 2. Resource Management
- Use resource groups to organize related resources
- Apply appropriate tags for cost management and organization
- Consider resource lifecycle and dependencies
- Plan for disaster recovery and backup strategies

### 3. Common Patterns
Focus on these frequently used Azure patterns:
- **API Management**: Gateway patterns, product management, developer portals
- **App Services**: Web apps, function apps, deployment slots
- **Networking**: Hub-spoke topologies, private endpoints, load balancing
- **Security**: Key Vault integration, managed identities, RBAC
- **Monitoring**: Application Insights, Log Analytics, alerting

## Development Workflow

### 1. Before Creating New Content
- Check if similar solutions already exist
- Review existing patterns and conventions
- Consider if the solution should be modular/reusable

### 2. Code Quality
- Run appropriate linters and formatters
- Test deployments before committing
- Follow the repository's existing patterns
- Include error handling and logging

### 3. Documentation
- Update main README.md if adding new categories
- Include inline comments for complex logic
- Provide examples of usage
- Document any manual steps required

## Dependencies and Tools
Common tools used in this repository:
- **Azure CLI**: For Azure resource management
- **Terraform**: Infrastructure provisioning
- **Bicep CLI**: Azure-native IaC
- **PowerShell**: Cross-platform scripting
- **Python 3.x**: Automation and utilities
- **Docker**: Containerization
- **Git**: Version control

## Support and Maintenance
- Keep dependencies updated
- Review and update documentation regularly
- Test solutions with latest Azure features
- Archive or update deprecated patterns
- Respond to issues and improvement suggestions

---

*This repository serves as a personal collection of scripts and solutions. While efforts are made to follow best practices, always review and test code before using in production environments.*