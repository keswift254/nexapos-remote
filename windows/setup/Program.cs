using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Principal;
using System.Windows.Forms;
using Microsoft.Win32;
using System.IO.Compression;

namespace NexaPosSetup
{

internal static class Program
{
    private const string ProductName = "NexaPOS";
    private const string ExecutableName = "nexapos_mobile.exe";
    private const string SetupName = "NexaPOS-Setup.exe";

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            if (args.Any(arg => string.Equals(arg, "/verify-payload", StringComparison.OrdinalIgnoreCase)))
            {
                return VerifyRuntimePayload();
            }
            if (!IsAdministrator())
            {
                return RelaunchElevated(args);
            }

            var installDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                ProductName);
            if (args.Any(arg => string.Equals(arg, "/uninstall", StringComparison.OrdinalIgnoreCase)))
            {
                return Uninstall(installDir);
            }

            Install(installDir);
            MessageBox.Show(
                ProductName + " was installed in:\n" + installDir,
                ProductName,
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            return 0;
        }
        catch (Exception error)
        {
            MessageBox.Show(
                ProductName + " could not be installed.\n\n" + error.Message,
                ProductName,
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
    }

    private static bool IsAdministrator()
    {
        using (var identity = WindowsIdentity.GetCurrent())
        {
            var principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }

    private static int RelaunchElevated(string[] args)
    {
        var executable = Process.GetCurrentProcess().MainModule.FileName;
        if (string.IsNullOrWhiteSpace(executable))
        {
            throw new InvalidOperationException("The setup executable path could not be determined.");
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = executable,
                Arguments = string.Join(" ", args.Select(QuoteArgument)),
                UseShellExecute = true,
                Verb = "runas",
            });
            return 0;
        }
        catch (Win32Exception error)
        {
            if (error.NativeErrorCode != 1223)
            {
                throw;
            }
            MessageBox.Show(
                "NexaPOS was not updated because administrator approval was cancelled.",
                ProductName,
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            return 1;
        }
    }

    private static string QuoteArgument(string argument)
    {
        return "\"" + argument.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
    }

    private static void Install(string installDir)
    {
        Directory.CreateDirectory(installDir);
        using (var payload = OpenRuntimePayload())
        {
            using (var archive = new ZipArchive(payload, ZipArchiveMode.Read))
            {
                foreach (var entry in archive.Entries)
                {
                    var destination = Path.GetFullPath(Path.Combine(installDir, entry.FullName));
                    if (!destination.StartsWith(Path.GetFullPath(installDir) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidDataException("The runtime archive contains an unsafe path.");
                    }
                    if (string.IsNullOrEmpty(entry.Name))
                    {
                        Directory.CreateDirectory(destination);
                        continue;
                    }
                    Directory.CreateDirectory(Path.GetDirectoryName(destination));
                    using (var source = entry.Open())
                    using (var target = File.Create(destination))
                    {
                        source.CopyTo(target);
                    }
                }
            }
        }

        var executable = Path.Combine(installDir, ExecutableName);
        if (!File.Exists(executable)) throw new FileNotFoundException("The runtime executable is missing.", executable);
        CopySetupIntoInstall(installDir);
        var desktopShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), ProductName + ".lnk");
        var startMenuShortcut = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),
            "Programs", ProductName, ProductName + ".lnk");
        CreateShortcut(desktopShortcut, executable, installDir);
        CreateShortcut(startMenuShortcut, executable, installDir);
        TryPinToTaskbar(desktopShortcut);
        RegisterUninstaller(installDir);
        RegisterCheckoutProtocol(executable);
    }

    private static Stream OpenRuntimePayload()
    {
        var assembly = typeof(Program).Assembly;
        var resourceName = assembly.GetManifestResourceNames().FirstOrDefault(name =>
            string.Equals(name, "NexaPOS.WindowsRuntime.zip", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(name, "NexaPOS-Windows-runtime.zip", StringComparison.OrdinalIgnoreCase) ||
            name.EndsWith("WindowsRuntime.zip", StringComparison.OrdinalIgnoreCase) ||
            name.EndsWith("Windows-runtime.zip", StringComparison.OrdinalIgnoreCase));
        if (resourceName == null)
        {
            throw new InvalidOperationException(
                "The Windows runtime payload is missing from this setup file. Embedded resources: " +
                string.Join(", ", assembly.GetManifestResourceNames()));
        }
        var payload = assembly.GetManifestResourceStream(resourceName);
        if (payload == null)
        {
            throw new InvalidOperationException("The embedded Windows runtime payload could not be opened.");
        }
        return payload;
    }

    private static int VerifyRuntimePayload()
    {
        using (var payload = OpenRuntimePayload())
        using (var archive = new ZipArchive(payload, ZipArchiveMode.Read))
        {
            if (!archive.Entries.Any(entry =>
                string.Equals(
                    entry.FullName.Replace('/', '\\'),
                    ExecutableName,
                    StringComparison.OrdinalIgnoreCase)))
            {
                throw new InvalidDataException(
                    "The Windows runtime payload does not contain " + ExecutableName + ".");
            }
        }
        return 0;
    }

    private static void RegisterCheckoutProtocol(string executable)
    {
        using (var key = Registry.LocalMachine.CreateSubKey(@"Software\Classes\nexapos"))
        {
            if (key == null) throw new InvalidOperationException("Could not register the checkout return link.");
            key.SetValue("", "URL:NexaPOS");
            key.SetValue("URL Protocol", "");
            using (var command = key.CreateSubKey(@"shell\open\command"))
            {
                command.SetValue("", "\"" + executable + "\" \"%1\"");
            }
        }
    }

    private static void CopySetupIntoInstall(string installDir)
    {
        var source = Process.GetCurrentProcess().MainModule.FileName;
        if (string.IsNullOrWhiteSpace(source)) return;
        var target = Path.Combine(installDir, SetupName);
        if (!string.Equals(Path.GetFullPath(source), Path.GetFullPath(target), StringComparison.OrdinalIgnoreCase))
        {
            File.Copy(source, target, true);
        }
    }

    private static void CreateShortcut(string shortcutPath, string targetPath, string workingDirectory)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(shortcutPath));
        var shellType = Type.GetTypeFromProgID("WScript.Shell");
        if (shellType == null) throw new InvalidOperationException("Windows shortcut support is unavailable.");
        dynamic shell = Activator.CreateInstance(shellType);
        dynamic shortcut = shell.CreateShortcut(shortcutPath);
        shortcut.TargetPath = targetPath;
        shortcut.WorkingDirectory = workingDirectory;
        shortcut.Description = ProductName;
        shortcut.IconLocation = targetPath + ",0";
        shortcut.Save();
    }

    private static void TryPinToTaskbar(string shortcutPath)
    {
        try
        {
            var shellType = Type.GetTypeFromProgID("Shell.Application");
            if (shellType == null) return;
            dynamic shell = Activator.CreateInstance(shellType);
            dynamic folder = shell.Namespace(Path.GetDirectoryName(shortcutPath));
            dynamic item = folder.ParseName(Path.GetFileName(shortcutPath));
            foreach (var verb in item.Verbs())
            {
                var name = ((dynamic)verb).Name as string ?? string.Empty;
                if (name.IndexOf("Pin to taskbar", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    ((dynamic)verb).DoIt();
                    break;
                }
            }
        }
        catch
        {
            // Windows may hide or deny the taskbar verb. Desktop and Start Menu shortcuts remain reliable.
        }
    }

    private static void RegisterUninstaller(string installDir)
    {
        using (var key = Registry.LocalMachine.CreateSubKey(
            @"Software\Microsoft\Windows\CurrentVersion\Uninstall\NexaPOS"))
        {
            if (key == null) return;
            key.SetValue("DisplayName", ProductName);
            key.SetValue("DisplayVersion", GetVersion());
            key.SetValue("Publisher", "NexaPOS");
            key.SetValue("InstallLocation", installDir);
            key.SetValue("DisplayIcon", Path.Combine(installDir, ExecutableName));
            key.SetValue("UninstallString", "\"" + Path.Combine(installDir, SetupName) + "\" /uninstall");
            key.SetValue("NoModify", 1, RegistryValueKind.DWord);
            key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
        }
    }

    private static int Uninstall(string installDir)
    {
        var desktopShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), ProductName + ".lnk");
        var startMenuShortcut = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),
            "Programs", ProductName, ProductName + ".lnk");
        TryDelete(desktopShortcut);
        TryDelete(startMenuShortcut);
        TryDeleteDirectory(Path.GetDirectoryName(startMenuShortcut));
        Registry.LocalMachine.DeleteSubKeyTree(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\NexaPOS", false);
        Registry.LocalMachine.DeleteSubKeyTree(@"Software\Classes\nexapos", false);
        var script = Path.Combine(Path.GetTempPath(), "nexapos-uninstall.cmd");
        File.WriteAllText(script, "@echo off\r\nping -n 3 127.0.0.1 > nul\r\nrmdir /s /q \"" + installDir + "\"\r\ndel /q \"%~f0\"\r\n");
        Process.Start(new ProcessStartInfo("cmd.exe", "/c \"" + script + "\"") { UseShellExecute = false, CreateNoWindow = true });
        return 0;
    }

    private static void TryDelete(string path) { try { if (File.Exists(path)) File.Delete(path); } catch { } }
    private static void TryDeleteDirectory(string path) { try { if (Directory.Exists(path)) Directory.Delete(path, true); } catch { } }
    private static string GetVersion()
    {
        var version = typeof(Program).Assembly.GetName().Version;
        return version == null ? "1.0.14" : version.ToString();
    }
}
}
