# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Environment

This project uses Docker-based development containers to provide a consistent development environment. The setup includes:

- Dev Container configuration with VS Code/Cursor integration
- Aqua package manager for CLI tool version management
- SSH and Git configuration shared from host system
- Docker-in-Docker support for container development

## Commands

### Container Management
- `docker compose up -d devcontainer` - Start the development container
- `docker compose down` - Stop the development container
- `docker compose build devcontainer` - Rebuild the development container

### Data Transfer Application (apps/data_transfer)

#### Environment Setup
```bash
cd apps/data_transfer
uv venv                    # Create virtual environment
source .venv/bin/activate  # Activate virtual environment
uv sync                    # Install dependencies
```

#### Development Commands
```bash
# Code quality
uv run ruff format         # Format code
uv run ruff check          # Lint code
uv run ruff check --fix    # Auto-fix lint issues
uv run mypy src           # Type checking

# Testing
uv run pytest            # Run all tests
uv run pytest tests/test_parameters.py  # Run specific test file
uv run pytest tests/test_parameters.py::TestParameterFactory::test_create_DB転送の正常なパラメータ生成  # Run specific test
uv run pytest -v         # Verbose test output
uv run pytest --cov=src  # Run with coverage report

# Package management
uv add <package-name>     # Add production dependency
uv add --dev <package-name>  # Add development dependency
```

### Development Tools
- Aqua is installed for CLI version management - check `aqua.yaml` for configured tools
- Path includes `$HOME/.local/share/aquaproj-aqua/bin` for Aqua-managed binaries

## Architecture

### Project Structure
This is a monorepo with applications under `apps/`. Currently contains:
- `apps/data_transfer/` - Python data transfer application for MySQL, S3 CSV, and BigQuery

### Data Transfer Application Architecture

The data transfer application follows a layered architecture with dependency injection:

#### Core Design Principles
- **Single Responsibility**: One class per file with clear responsibilities
- **Dependency Injection**: Uses `injector` library for testable design
- **External System Abstraction**: DAO pattern for AWS Secrets Manager, database connections
- **Structured Logging**: JSON-formatted logs for operational observability
- **Error Handling**: Automatic retry with exponential backoff using `tenacity`

#### Key Components
- **Parameters/ParameterFactory**: Unified parameter generation from CLI args and environment variables
- **Secrets/SecretsManager**: AWS Secrets Manager integration with DI pattern
- **Engines**: Data transfer engines for DB-to-DB, S3-CSV-to-DB, BigQuery-to-DB patterns
- **Transfer Classes**: Business logic for specific transfer operations
- **Logger**: Structured JSON logging for transfer events and errors

#### Technology Stack
- **Polars**: High-performance data processing with streaming and parallel processing
- **injector**: Dependency injection framework for testable design
- **tenacity**: Automatic retry with exponential backoff for connection stability
- **boto3**: AWS Secrets Manager and S3 integration
- **google-cloud-bigquery**: BigQuery data source support

#### Testing Strategy
- **Unit Tests** (`tests/`): Class-level testing with mocks for external dependencies
- **Integration Tests** (`tests-it/`): End-to-end transfer scenario testing
- **pytest configuration**: Source path mapping via `pythonpath = ["src"]` in pyproject.toml
- **Coverage**: Uses pytest-cov with src/ directory coverage reporting

#### Development Environment
- `.devcontainer/` - VS Code/Cursor development container configuration
- `compose.yaml` - Docker Compose service definition for the dev container
- `aqua.yaml` - Package manager configuration for CLI tools
- `.editorconfig` - Code formatting standards (UTF-8, LF line endings, 2-space indentation, 4-space for Python)

The dev container mounts the project directory to `/workspace` and shares SSH/Git configuration from the host system for seamless development workflow.

## Implementation Guidelines

### Dependency Injection Rules
- Apply `@inject` and `@dataclass` only to classes that have dependencies injected
- Utility classes without dependencies (Logger, ParameterFactory, SecretsManager) don't need `@inject`
- Classes without fields don't need `@dataclass` (pure logic classes)

### Code Style Requirements
- All methods must have type hints
- Japanese comments for method descriptions: `"""メソッドの処理内容を説明する"""`
- Complex logic must include purpose/background comments
- File-level docstring explaining class responsibility
- Follow ruff formatting and linting standards

### Testing Conventions
- Test naming: `test_<method>_<condition>_<expected_result>` in Japanese
- Given-When-Then structure in test methods
- One assertion per test method
- Japanese docstrings explaining test intent