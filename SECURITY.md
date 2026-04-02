# Security Policy

## About This Tool

The Autodesk Complete Uninstaller is a Windows batch script (.bat) that runs with administrator privileges. It modifies the Windows registry, removes files, and uninstalls software. Because of this, transparency and trust are important.

## What the Script Does

The script is a single, human-readable `.bat` file. You can open it in any text editor to review exactly what it does before running it. It will:

- Uninstall Autodesk products via standard Windows mechanisms (ODIS, MSI, BitRock)
- Remove Autodesk-related registry keys
- Delete Autodesk-related folders and files
- Remove Autodesk services and scheduled tasks

The script does **not**:

- Connect to the internet
- Send any data anywhere
- Install any software
- Modify non-Autodesk files or registry keys

## Reporting a Vulnerability

If you discover a security issue with this tool, please report it responsibly:

1. **Do not** open a public issue
2. Email the maintainer directly at the address listed on the GitHub profile
3. Include a description of the issue, steps to reproduce, and potential impact

## Supported Versions

| Version | Supported |
| ------- | --------- |
| v5.8    | ✅ Yes    |
| < v5.8  | ❌ No     |

We recommend always using the [latest release](https://github.com/bequiet11/autodesk-complete-uninstaller/releases/latest).
