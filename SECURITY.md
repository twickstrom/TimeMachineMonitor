# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 12.2.x  | :white_check_mark: |
| < 12.2  | :x:                |

## Reporting a Vulnerability

We take the security of TimeMachineMonitor seriously. If you have discovered a security vulnerability, please follow these steps:

1. **Do NOT** create a public GitHub issue for the vulnerability
2. Email the details to the maintainer (create an issue asking for contact details if needed)
3. Include as much information as possible:
   - Type of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Considerations

TimeMachineMonitor is designed with security in mind:

- **No eval usage** - All configuration parsing is done safely without eval
- **Input validation** - All user inputs are validated
- **Safe path handling** - Proper quoting and escaping throughout
- **Process isolation** - Helper process runs separately
- **No network access** - Purely local monitoring tool
- **Read-only operations** - Only reads Time Machine status, never modifies

## Best Practices for Users

1. Always download from the official GitHub repository
2. Verify the integrity of downloads when possible
3. Keep your macOS system updated
4. Run with minimal privileges (no sudo required)
5. Review configuration files before using them

## Response Timeline

- Security vulnerabilities will be acknowledged within 48 hours
- A fix will be developed and tested as quickly as possible
- A new release will be created once the fix is verified

Thank you for helping keep TimeMachineMonitor secure!
