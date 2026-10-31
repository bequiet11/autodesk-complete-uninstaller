using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.RegularExpressions;
using AutodeskCleaner.Localization;
using AutodeskCleaner.Services;

namespace AutodeskCleaner.ViewModels;

/// <summary>
/// Drives the live activity panel. Engine output arrives on the UI thread
/// (through Progress&lt;T&gt;), while the timer flushes the text buffer at a
/// human-friendly rate so a chatty CMD script cannot freeze the window.
/// </summary>
public sealed class ActivityViewModel : INotifyPropertyChanged
{
    private static readonly Regex PhaseRegex = new(@"(?i)Phase\s+[A-Z]\s*-\s*(\d+)\s+of\s+(\d+)", RegexOptions.Compiled);
    private static readonly Regex StepRegex = new(@"(?i)\[\s*(\d+)\s*/\s*(\d+)\s*\]", RegexOptions.Compiled);

    private readonly StringBuilder _log = new();
    private readonly StringBuilder _pending = new();
    private bool _dirty;

    private bool _isBusy;
    private bool _isIndeterminate;
    private string _statusText = Loc.Instance["Activity_Idle"];
    private string _phaseText = string.Empty;
    private double _phaseValue;
    private string _logText = string.Empty;
    private string _elapsedText = string.Empty;
    private int _phaseCurrent;
    private int _phaseTotal;

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool IsBusy
    {
        get => _isBusy;
        private set => SetField(ref _isBusy, value);
    }

    public bool IsIndeterminate
    {
        get => _isIndeterminate;
        private set => SetField(ref _isIndeterminate, value);
    }

    public string StatusText
    {
        get => _statusText;
        private set => SetField(ref _statusText, value);
    }

    public string PhaseText
    {
        get => _phaseText;
        private set => SetField(ref _phaseText, value);
    }

    public double PhaseValue
    {
        get => _phaseValue;
        private set => SetField(ref _phaseValue, value);
    }

    public string LogText
    {
        get => _logText;
        private set => SetField(ref _logText, value);
    }

    public string ElapsedText
    {
        get => _elapsedText;
        private set => SetField(ref _elapsedText, value);
    }

    public bool HasLog => _log.Length > 0 || _pending.Length > 0;

    public void Begin(string status)
    {
        _log.Clear();
        _pending.Clear();
        _dirty = true;
        _phaseCurrent = 0;
        _phaseTotal = 0;
        PhaseText = string.Empty;
        PhaseValue = 0;
        IsIndeterminate = true;
        StatusText = status;
        ElapsedText = string.Empty;
        IsBusy = true;
        LogText = string.Empty;
        _dirty = true;
        OnPropertyChanged(nameof(HasLog));
    }

    public void Push(EngineEvent evt)
    {
        if (evt.Kind == EngineEventKind.Status)
        {
            SetStatus(evt.Text);
            return;
        }

        var line = evt.Text.TrimEnd();
        if (line.Length == 0)
        {
            return;
        }

        _log.AppendLine(line);
        _pending.AppendLine(line);
        _dirty = true;
        SetStatus(line);
        UpdatePhase(line);
        OnPropertyChanged(nameof(HasLog));
    }

    public void AppendSystemLine(string line)
    {
        _log.AppendLine(line);
        _pending.AppendLine(line);
        _dirty = true;
        OnPropertyChanged(nameof(HasLog));
    }

    public void SetStatus(string status)
    {
        var clean = status.Trim();
        if (clean.Length == 0)
        {
            return;
        }

        if (clean.Length > 190)
        {
            clean = clean[..190] + "…";
        }

        StatusText = clean;
    }

    public void Flush()
    {
        if (!_dirty)
        {
            return;
        }

        if (_pending.Length > 0)
        {
            _pending.Clear();
        }

        LogText = _log.ToString();
        _dirty = false;
    }

    public void End(string status)
    {
        Flush();
        IsBusy = false;
        IsIndeterminate = false;
        StatusText = status;
        if (_phaseTotal > 0)
        {
            PhaseValue = 100;
        }
    }

    public void Tick(TimeSpan elapsed)
    {
        ElapsedText = Loc.Instance.Format("Activity_Elapsed", elapsed);
        if (_phaseTotal > 0)
        {
            PhaseText = Loc.Instance.Format("Activity_Phase", _phaseCurrent, _phaseTotal);
        }
    }

    public void RefreshLocalization()
    {
        if (!IsBusy && _log.Length == 0)
        {
            StatusText = Loc.Instance["Activity_Idle"];
        }

        if (_phaseTotal > 0)
        {
            PhaseText = Loc.Instance.Format("Activity_Phase", _phaseCurrent, _phaseTotal);
        }
    }

    private void UpdatePhase(string line)
    {
        var match = StepRegex.Match(line);
        if (!match.Success)
        {
            match = PhaseRegex.Match(line);
        }

        if (!match.Success)
        {
            return;
        }

        if (!int.TryParse(match.Groups[1].Value, out var current) ||
            !int.TryParse(match.Groups[2].Value, out var total) ||
            total <= 0)
        {
            return;
        }

        _phaseCurrent = Math.Min(current, total);
        _phaseTotal = total;
        IsIndeterminate = false;
        PhaseText = Loc.Instance.Format("Activity_Phase", _phaseCurrent, _phaseTotal);
        PhaseValue = Math.Round(_phaseCurrent * 100d / total, 1);
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        OnPropertyChanged(propertyName);
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
