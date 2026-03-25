# Contributing to Autodesk Complete Uninstaller

Thank you for your interest in contributing! Here's how you can help.

## Reporting Bugs

1. Check [existing issues](https://github.com/bequiet11/autodesk-complete-uninstaller/issues) first
2. Use the **Bug report** template when creating a new issue
3. Include your log files from `Desktop\Autodesk_Uninstaller\`
4. Mention your Windows version (run `winver`) and which Autodesk products were installed

## Suggesting Features

Use the **Feature request** template to suggest improvements. Please describe:
- The problem you're trying to solve
- Which Autodesk products are involved
- Any workarounds you currently use

## Testing

The most valuable contribution is testing on different configurations:
- Different Windows versions (10/11, various builds)
- Different Autodesk product combinations
- Domain-joined vs. standalone PCs
- Systems with multiple Autodesk year versions installed

Please share your results by opening an issue, even if everything works perfectly.

## Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-improvement`)
3. Test thoroughly on a Windows machine with Autodesk products
4. Commit your changes with a clear message
5. Open a Pull Request describing what you changed and why

### Guidelines

- This is a single-file batch script by design — keep it that way
- Test with `Run as administrator` (the tool requires elevation)
- Preserve backward compatibility with Windows 10
- Add comments for any non-obvious logic
- Do not remove safety checks or confirmation prompts

## Questions?

Open a [Discussion](https://github.com/bequiet11/autodesk-complete-uninstaller/issues) or issue if you have questions.
