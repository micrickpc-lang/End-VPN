using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media.Animation;
using System.Windows.Navigation;

namespace EndVPN.Installer;

public partial class MainWindow : Window
{
    private const string AppName = "END VPN";
    private const string OfferUrl = "https://telegra.ph/PUBLICHNAYA-OFERTA-End-VPN-04-17";
    private readonly string _installDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), AppName);
    private bool _installed;
    private bool _busy;

    public MainWindow()
    {
        InitializeComponent();
    }

    private void Window_SourceInitialized(object? sender, EventArgs e)
    {
        ApplySystemBackdrop();
    }

    private void ApplySystemBackdrop()
    {
        var handle = new WindowInteropHelper(this).Handle;
        try
        {
            var enabled = 1;
            var rounded = 2;
            DwmSetWindowAttribute(handle, 20, ref enabled, sizeof(int));
            DwmSetWindowAttribute(handle, 33, ref rounded, sizeof(int));

            if (OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22621))
            {
                var acrylic = 3;
                DwmSetWindowAttribute(handle, 38, ref acrylic, sizeof(int));
            }
            else
            {
                EnableWindows10Acrylic(handle);
            }
        }
        catch
        {
            // The layered in-window glass remains available when DWM effects are disabled.
        }
    }

    private static void EnableWindows10Acrylic(IntPtr handle)
    {
        var accent = new AccentPolicy
        {
            AccentState = 4,
            AccentFlags = 2,
            GradientColor = unchecked((int)0xCC100D0B)
        };
        var accentSize = Marshal.SizeOf<AccentPolicy>();
        var accentPointer = Marshal.AllocHGlobal(accentSize);
        try
        {
            Marshal.StructureToPtr(accent, accentPointer, false);
            var data = new WindowCompositionAttributeData
            {
                Attribute = 19,
                Data = accentPointer,
                SizeOfData = accentSize
            };
            SetWindowCompositionAttribute(handle, ref data);
        }
        finally
        {
            Marshal.FreeHGlobal(accentPointer);
        }
    }

    private void MinimizeButton_Click(object sender, RoutedEventArgs e)
    {
        if (!_busy)
            WindowState = WindowState.Minimized;
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        if (!_busy)
            Close();
    }

    private void AgreementCheckBox_Changed(object sender, RoutedEventArgs e)
    {
        if (!_busy && !_installed)
            PrimaryButton.IsEnabled = AgreementCheckBox.IsChecked == true;
    }

    private void OfferLink_RequestNavigate(object sender, RequestNavigateEventArgs e)
    {
        Process.Start(new ProcessStartInfo(e.Uri?.AbsoluteUri ?? OfferUrl)
        {
            UseShellExecute = true
        });
        e.Handled = true;
    }

    private async void PrimaryButton_Click(object sender, RoutedEventArgs e)
    {
        if (_installed)
        {
            LaunchApp();
            Close();
            return;
        }

        if (_busy || AgreementCheckBox.IsChecked != true)
            return;

        _busy = true;
        PrimaryButton.IsEnabled = false;
        CloseButton.IsEnabled = false;
        AgreementCheckBox.Visibility = Visibility.Collapsed;
        AgreementPanel.Visibility = Visibility.Collapsed;
        DonePanel.Visibility = Visibility.Collapsed;
        ProgressPanel.Visibility = Visibility.Visible;
        EyebrowText.Text = "ШАГ 2 ИЗ 2  •  УСТАНОВКА";
        TitleText.Text = "Устанавливаем END VPN";
        SubtitleText.Text = "Файлы проверяются и безопасно устанавливаются. Это займёт меньше минуты.";
        PrimaryButton.Content = "УСТАНОВКА…";
        StartSpinner();

        try
        {
            await InstallApplicationAsync();
            SetProgress(100, "END VPN установлен");
            _installed = true;
            EyebrowText.Text = "ВСЁ ГОТОВО";
            TitleText.Text = "Добро пожаловать";
            SubtitleText.Text = "END VPN установлен и готов защищать ваше соединение.";
            ProgressPanel.Visibility = Visibility.Collapsed;
            DonePanel.Visibility = Visibility.Visible;
            PrimaryButton.Content = "ЗАПУСТИТЬ END VPN";
            PrimaryButton.IsEnabled = true;
            CloseButton.IsEnabled = true;
        }
        catch (Exception ex)
        {
            EyebrowText.Text = "НЕ УДАЛОСЬ УСТАНОВИТЬ";
            TitleText.Text = "Попробуем ещё раз";
            SubtitleText.Text = ex.Message;
            StatusText.Text = "Проверьте свободное место и повторите установку";
            PrimaryButton.Content = "ПОВТОРИТЬ УСТАНОВКУ";
            PrimaryButton.IsEnabled = true;
            CloseButton.IsEnabled = true;
        }
        finally
        {
            _busy = false;
        }
    }

    private async Task InstallApplicationAsync()
    {
        var tempDirectory = Path.Combine(Path.GetTempPath(), "EndVPNSetup", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempDirectory);
        var coreSetup = Path.Combine(tempDirectory, "EndVPNCoreSetup.exe");

        try
        {
            SetProgress(4, "Подготовка защищённого пакета");
            await using (var resource = Assembly.GetExecutingAssembly()
                .GetManifestResourceStream("EndVPN.CoreSetup.exe")
                ?? throw new InvalidOperationException("Установочный пакет повреждён."))
            await using (var output = new FileStream(coreSetup, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                await resource.CopyToAsync(output);
            }

            SetProgress(9, "Запрос разрешения Windows");
            Process process;
            try
            {
                process = Process.Start(new ProcessStartInfo
                {
                    FileName = coreSetup,
                    Arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /CLOSEAPPLICATIONS /TASKS=\"desktopicon\" /LANG=russian",
                    WorkingDirectory = tempDirectory,
                    UseShellExecute = true,
                    Verb = "runas",
                    WindowStyle = ProcessWindowStyle.Hidden
                }) ?? throw new InvalidOperationException("Не удалось запустить установку.");
            }
            catch (Win32Exception ex) when (ex.NativeErrorCode == 1223)
            {
                throw new InvalidOperationException("Установка отменена в окне контроля учётных записей Windows.");
            }

            using (process)
            using (var progressCancellation = new CancellationTokenSource())
            {
                var progressTask = AnimateInstallProgressAsync(process, progressCancellation.Token);
                await process.WaitForExitAsync();
                progressCancellation.Cancel();
                try { await progressTask; } catch (OperationCanceledException) { }

                if (process.ExitCode != 0)
                    throw new InvalidOperationException($"Системный установщик завершился с кодом {process.ExitCode}.");
            }

            SetProgress(96, "Проверка установленного приложения");
            var executable = Path.Combine(_installDir, "endvpn.exe");
            if (!File.Exists(executable))
                throw new InvalidOperationException("Windows не подтвердила установку END VPN.");

            await Task.Delay(280);
        }
        finally
        {
            try { Directory.Delete(tempDirectory, true); } catch { }
        }
    }

    private async Task AnimateInstallProgressAsync(Process process, CancellationToken cancellationToken)
    {
        var progress = 12;
        while (!process.HasExited && progress < 91)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var step = Math.Max(1, (92 - progress) / 9);
            progress = Math.Min(91, progress + step);
            var status = progress switch
            {
                < 35 => "Распаковка компонентов",
                < 70 => "Установка END VPN",
                < 88 => "Создание ярлыков и регистрация",
                _ => "Финальная настройка"
            };
            SetProgress(progress, status);
            await Task.Delay(360, cancellationToken);
        }
    }

    private void StartSpinner()
    {
        var animation = new DoubleAnimation(0, 360, TimeSpan.FromSeconds(1.15))
        {
            RepeatBehavior = RepeatBehavior.Forever
        };
        SpinnerRotate.BeginAnimation(System.Windows.Media.RotateTransform.AngleProperty, animation);
    }

    private void SetProgress(int percent, string status)
    {
        Dispatcher.Invoke(() =>
        {
            StatusText.Text = status;
            PercentText.Text = $"{percent}%";
            var trackWidth = ProgressTrack.ActualWidth > 0 ? ProgressTrack.ActualWidth : 460;
            var target = Math.Max(0, trackWidth * percent / 100d);
            var animation = new DoubleAnimation(target, TimeSpan.FromMilliseconds(320))
            {
                EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
            };
            ProgressFill.BeginAnimation(WidthProperty, animation);
        });
    }

    private void LaunchApp()
    {
        var executable = Path.Combine(_installDir, "endvpn.exe");
        if (!File.Exists(executable))
        {
            MessageBox.Show("END VPN не найден. Повторите установку.", AppName, MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        Process.Start(new ProcessStartInfo(executable)
        {
            WorkingDirectory = _installDir,
            UseShellExecute = true
        });
    }

    [DllImport("dwmapi.dll")]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    [DllImport("user32.dll")]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    private static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

    [StructLayout(LayoutKind.Sequential)]
    private struct AccentPolicy
    {
        public int AccentState;
        public int AccentFlags;
        public int GradientColor;
        public int AnimationId;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct WindowCompositionAttributeData
    {
        public int Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }
}
