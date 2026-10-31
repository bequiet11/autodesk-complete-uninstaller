using System.ComponentModel;
using System.Diagnostics;
using System.Security.Principal;

namespace AutodeskCleaner.Services;

public static class AdminHelper
{
    public static bool IsAdministrator
    {
        get
        {
            try
            {
                using var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }
    }

    /// <summary>
    /// Relaunches the current executable elevated. Returns true when the elevated
    /// copy was started, false when the user declined UAC or the launch failed.
    /// </summary>
    public static bool TryRelaunchElevated(IEnumerable<string> args)
    {
        try
        {
            var exe = Environment.ProcessPath;
            if (string.IsNullOrWhiteSpace(exe))
            {
                return false;
            }

            var psi = new ProcessStartInfo
            {
                FileName = exe,
                UseShellExecute = true,
                Verb = "runas",
                WorkingDirectory = AppContext.BaseDirectory,
            };

            foreach (var arg in args)
            {
                // Do not propagate the development-only escape hatch.
                if (string.Equals(arg, "--allow-nonadmin", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                psi.ArgumentList.Add(arg);
            }

            Process.Start(psi);
            return true;
        }
        catch (Win32Exception ex) when (ex.NativeErrorCode == 1223)
        {
            // ERROR_CANCELLED - user pressed No on the UAC prompt.
            return false;
        }
        catch
        {
            return false;
        }
    }
}
